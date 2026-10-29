@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/io_client.dart';
import 'package:supabase_storage/supabase_storage.dart';
import 'package:test/test.dart';

Stream<Uint8List> chunks(List<List<int>> parts) =>
    Stream.fromIterable(parts.map(Uint8List.fromList));

void main() {
  group('collectBytes', () {
    test('collects the whole body without a cap', () async {
      final bytes = await chunks([
        [1, 2],
        [3],
      ]).collectBytes();

      expect(bytes, [1, 2, 3]);
    });

    test('returns a body exactly at the cap', () async {
      final bytes = await chunks([
        [1, 2],
        [3],
      ]).collectBytes(maxBytes: 3);

      expect(bytes, [1, 2, 3]);
    });

    test('throws once the cap is exceeded and cancels the stream', () async {
      var cancelled = false;
      final controller = StreamController<Uint8List>(
        onCancel: () => cancelled = true,
      );
      final expectation = expectLater(
        controller.stream.collectBytes(maxBytes: 3),
        throwsA(
          isA<StorageDownloadTooLargeException>()
              .having((error) => error.maxBytes, 'maxBytes', 3)
              .having((error) => error.message, 'message', contains('3')),
        ),
      );

      controller.add(Uint8List(2));
      controller.add(Uint8List(2));
      await expectation;

      expect(cancelled, isTrue);
    });

    test('rejects a negative cap', () async {
      await expectLater(
        chunks([]).collectBytes(maxBytes: -1),
        throwsArgumentError,
      );
    });

    test(
      'counts bytes after the HTTP stack decoded a compressed body',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) {
          request.response
            ..headers.set(HttpHeaders.contentEncodingHeader, 'gzip')
            ..add(gzip.encode(Uint8List(10000)));
          unawaited(request.response.close());
        });
        final httpClient = HttpClient()..autoUncompress = true;
        final storage = SupabaseStorageClient(
          'http://127.0.0.1:${server.port}',
          const {},
          httpClient: IOClient(httpClient),
        );
        addTearDown(httpClient.close);

        await expectLater(
          (await storage.from('bucket').downloadStream('a.bin')).collectBytes(
            maxBytes: 1000,
          ),
          throwsA(isA<StorageDownloadTooLargeException>()),
        );
        final download = await storage.from('bucket').downloadStream('a.bin');
        final whole = await download.collectBytes(maxBytes: 10000);
        expect(whole.length, 10000);
      },
    );
  });

  group('writeToFile', () {
    late Directory directory;
    late String destination;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('storage_write_test');
      destination = '${directory.path}/file.bin';
      addTearDown(() => directory.deleteSync(recursive: true));
    });

    test('writes the stream to the destination', () async {
      await chunks([
        [1, 2],
        [3],
      ]).writeToFile(destination);

      expect(File(destination).readAsBytesSync(), [1, 2, 3]);
      expect(directory.listSync().length, 1);
    });

    test('replaces an existing destination', () async {
      File(destination).writeAsBytesSync([9, 9, 9, 9]);

      await chunks([
        [1],
      ]).writeToFile(destination);

      expect(File(destination).readAsBytesSync(), [1]);
    });

    test('keeps the destination and removes the temporary file when the '
        'stream fails halfway', () async {
      File(destination).writeAsBytesSync([9, 9]);
      final stream = () async* {
        yield Uint8List.fromList([1, 2, 3]);
        throw const StorageException('boom');
      }();

      await expectLater(
        stream.writeToFile(destination),
        throwsA(isA<StorageException>()),
      );

      expect(File(destination).readAsBytesSync(), [9, 9]);
      expect(directory.listSync().length, 1);
    });

    test('does not create the destination when the stream fails', () async {
      final stream = Stream<Uint8List>.error(const StorageException('boom'));

      await expectLater(
        stream.writeToFile(destination),
        throwsA(isA<StorageException>()),
      );

      expect(directory.listSync(), isEmpty);
    });

    test('cleans up when the download is aborted', () async {
      File(destination).writeAsBytesSync([9]);
      final stream = () async* {
        yield Uint8List.fromList([1]);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        throw RequestAbortedException();
      }();

      await expectLater(
        stream.writeToFile(destination),
        throwsA(isA<RequestAbortedException>()),
      );

      expect(File(destination).readAsBytesSync(), [9]);
      expect(directory.listSync().length, 1);
    });

    test('does not create a missing directory', () async {
      await expectLater(
        chunks([
          [1],
        ]).writeToFile('${directory.path}/missing/file.bin'),
        throwsA(isA<FileSystemException>()),
      );

      expect(directory.listSync(), isEmpty);
    });
  });
}
