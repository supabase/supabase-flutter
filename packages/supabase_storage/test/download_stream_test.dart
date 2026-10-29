import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:supabase_storage/supabase_storage.dart';
import 'package:test/test.dart';

SupabaseStorageClient _client(
  Stream<List<int>> body, {
  int statusCode = 200,
  int? contentLength,
  Map<String, String> headers = const {},
  Duration? requestTimeout,
}) {
  return SupabaseStorageClient(
    'http://localhost/storage/v1',
    const {},
    requestTimeout: requestTimeout,
    httpClient: MockClient.streaming(
      (request, _) async => http.StreamedResponse(
        body,
        statusCode,
        request: request,
        contentLength: contentLength,
        headers: headers,
      ),
    ),
  );
}

void main() {
  group('downloadStream', () {
    test('returns the response head before reading the body', () async {
      final body = StreamController<List<int>>();
      addTearDown(body.close);
      final client = _client(
        body.stream,
        contentLength: 4,
        headers: {'content-type': 'video/mp4', 'x-request-id': 'request-1'},
      );

      final download = await client.from('bucket').downloadStream('a.mp4');

      expect(body.hasListener, isFalse);
      expect(download.statusCode, 200);
      expect(download.contentLength, 4);
      expect(download.contentType, 'video/mp4');
      expect(download.headers['x-request-id'], 'request-1');

      final bytes = download.expand((chunk) => chunk).toList();
      body
        ..add([1, 2])
        ..add([3, 4]);
      await body.close();
      expect(await bytes, [1, 2, 3, 4]);
    });

    test('exposes the status and Content-Range of a satisfied range', () async {
      final client = _client(
        Stream.value([5, 6]),
        statusCode: 206,
        contentLength: 2,
        headers: {'content-range': 'bytes 4-5/10'},
      );

      final download = await client
          .from('bucket')
          .downloadStream('a.bin', range: ByteRange(4, 5));

      expect(download.statusCode, 206);
      expect(download.contentRange, 'bytes 4-5/10');
      expect(download.contentLength, 2);
      expect(await download.expand((chunk) => chunk).toList(), [5, 6]);
    });

    test('reports an unknown length for an encoded body', () async {
      final client = _client(
        Stream.value([1, 2, 3]),
        contentLength: 3,
        headers: {'content-encoding': 'gzip'},
      );

      final download = await client.from('bucket').downloadStream('a.bin');

      expect(download.contentLength, isNull);
      await download.drain<void>();
    });

    test('throws the service error of a non-success status', () async {
      final client = _client(
        Stream.value(
          '{"statusCode":"404","error":"not_found","code":"NoSuchKey",'
                  '"message":"Object not found"}'
              .codeUnits,
        ),
        statusCode: 400,
      );

      await expectLater(
        client.from('bucket').downloadStream('missing.bin'),
        throwsA(
          isA<StorageApiException>()
              .having((error) => error.errorCode, 'errorCode', 'NoSuchKey')
              .having((error) => error.statusCode, 'statusCode', 404)
              .having((error) => error.message, 'message', 'Object not found'),
        ),
      );
    });

    test(
      'surfaces a failure partway through the body as a transport error',
      () async {
        final client = _client(() async* {
          yield [1, 2];
          throw http.ClientException('connection lost');
        }(), contentLength: 4);

        final download = await client.from('bucket').downloadStream('a.bin');
        final chunks = <Uint8List>[];

        await expectLater(
          download.forEach(chunks.add),
          throwsA(
            isA<StorageTransportException>().having(
              (error) => error.cause,
              'cause',
              isA<http.ClientException>(),
            ),
          ),
        );
        expect(chunks, [
          [1, 2],
        ]);
      },
    );

    test(
      'surfaces a timeout while the body streams as a transport error',
      () async {
        final body = StreamController<List<int>>();
        addTearDown(body.close);
        final client = _client(
          body.stream,
          requestTimeout: const Duration(milliseconds: 50),
        );

        final download = await client.from('bucket').downloadStream('a.bin');

        await expectLater(
          download.drain<void>(),
          throwsA(
            isA<StorageTransportException>().having(
              (error) => error.cause,
              'cause',
              isA<TimeoutException>(),
            ),
          ),
        );
      },
    );

    test('cancelling the subscription cancels the response body', () async {
      final cancelled = Completer<void>();
      final body = StreamController<List<int>>(onCancel: cancelled.complete);
      final client = _client(body.stream);

      final download = await client.from('bucket').downloadStream('a.bin');
      final firstChunk = Completer<void>();
      final subscription = download.listen((_) {
        if (!firstChunk.isCompleted) firstChunk.complete();
      });
      body.add([1]);
      await firstChunk.future;
      await subscription.cancel();

      await cancelled.future.timeout(const Duration(seconds: 1));
    });

    group('against a server', () {
      late HttpServer server;
      late IOClient httpClient;
      late SupabaseStorageClient storage;
      late Completer<void> connectionClosed;

      setUp(() async {
        connectionClosed = Completer<void>();
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) {
          final response = request.response
            ..bufferOutput = false
            ..contentLength = 1000
            ..add([1, 2, 3]);
          response.done.whenComplete(connectionClosed.complete).ignore();
          var writes = 0;
          Timer.periodic(const Duration(milliseconds: 10), (timer) {
            try {
              response.add([4]);
              if (++writes > 900) timer.cancel();
            } on Object {
              timer.cancel();
            }
          });
        });
        httpClient = IOClient();
        storage = SupabaseStorageClient(
          'http://127.0.0.1:${server.port}',
          const {},
          httpClient: httpClient,
        );
      });

      tearDown(() async {
        httpClient.close();
        await server.close(force: true);
      });

      test('aborts the body after the head arrived', () async {
        final abort = Completer<void>();
        final download = await storage
            .from('bucket')
            .downloadStream('a.bin', abortSignal: abort.future);
        final chunks = <Uint8List>[];

        final read = download.forEach((chunk) {
          chunks.add(chunk);
          if (!abort.isCompleted) abort.complete();
        });

        await expectLater(read, throwsA(isA<RequestAbortedException>()));
        expect(chunks, isNotEmpty);
      });

      test(
        'closes the connection when the subscription is cancelled',
        () async {
          final download = await storage.from('bucket').downloadStream('a.bin');

          await download.first;

          await connectionClosed.future.timeout(const Duration(seconds: 5));
        },
      );
    });
  });
}
