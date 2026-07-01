import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_codegen_spike/supabase_codegen_spike.dart';
import 'package:test/test.dart';

/// A test double that records the outgoing request and returns a canned
/// response. It never touches the network.
class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      _handler;

  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    lastRequest = request;
    return _handler(request);
  }
}

http.StreamedResponse _json(Object body, {int status = 200}) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.StreamedResponse(
    Stream.value(bytes),
    status,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  group('JSON operations', () {
    test('listBuckets decodes into models', () async {
      final http = _RecordingClient(
        (_) async => _json({
          'items': [
            {'id': 'avatars', 'name': 'avatars', 'public': true},
          ],
        }),
      );
      final api = StorageApi(ApiClient(baseUrl: 'https://x', httpClient: http));

      final result = await api.listBuckets();

      expect(result.items, hasLength(1));
      expect(result.items.first.id, 'avatars');
      expect(result.items.first.public, isTrue);
      expect(http.lastRequest!.method, 'GET');
      expect(http.lastRequest!.url.path, '/bucket');
    });

    test('createBucket serializes the request model', () async {
      Map<String, dynamic>? sentBody;
      final client = _RecordingClient((request) async {
        sentBody = jsonDecode(
          await (request as http.Request).finalize().bytesToString(),
        ) as Map<String, dynamic>;
        return _json({'name': 'photos'});
      });
      final api =
          StorageApi(ApiClient(baseUrl: 'https://x', httpClient: client));

      await api.createBucket(
        body: CreateBucketRequestContent(
          id: 'photos',
          name: 'photos',
          public: false,
        ),
      );

      expect(sentBody, {'id': 'photos', 'name': 'photos', 'public': false});
    });

    test('non-2xx maps to ApiException with decoded body', () async {
      final api = StorageApi(
        ApiClient(
          baseUrl: 'https://x',
          httpClient: _RecordingClient(
            (_) async => _json({'message': 'not found'}, status: 404),
          ),
        ),
      );

      await expectLater(
        api.getBucket(id: 'missing'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => (e.body as Map)['message'], 'body', 'not found'),
        ),
      );
    });
  });

  group('Streaming', () {
    test('upload streams the request body without buffering (question 1)',
        () async {
      final received = <int>[];
      final client = _RecordingClient((request) async {
        // Pull the finalized body chunk by chunk; nothing was collected into a
        // Uint8List by the generated client before this point.
        await for (final chunk in request.finalize()) {
          received.addAll(chunk);
        }
        return http.StreamedResponse(
          const Stream.empty(),
          204,
          headers: {'upload-offset': '9'},
        );
      });
      final api =
          StorageApi(ApiClient(baseUrl: 'https://x', httpClient: client));

      final source = Stream<List<int>>.fromIterable([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
      ]);

      final result = await api.uploadChunk(
        uploadId: 'abc',
        tusResumable: '1.0.0',
        uploadOffset: 0,
        body: source,
        contentLength: 9,
      );

      expect(client.lastRequest, isA<http.StreamedRequest>());
      expect(received, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(result['uploadOffset'], 9);
      expect(client.lastRequest!.headers['Upload-Offset'], '0');
      expect(client.lastRequest!.headers['Tus-Resumable'], '1.0.0');
    });

    test('response is handed back as a live stream (question 2)', () async {
      final controller = StreamController<List<int>>();
      final api = FunctionsApi(
        ApiClient(
          baseUrl: 'https://x',
          httpClient: _RecordingClient(
            (_) async => http.StreamedResponse(controller.stream, 200),
          ),
        ),
      );

      final response = await api.invokeFunctionGet(functionName: 'sse');
      expect(response, isA<StreamedApiResponse>());

      final received = <String>[];
      final done = response.stream
          .transform(utf8.decoder)
          .listen(received.add)
          .asFuture<void>();

      // Emit events over time; the caller receives them incrementally.
      controller.add(utf8.encode('event-1'));
      await Future<void>.delayed(Duration.zero);
      expect(received, ['event-1']);
      controller.add(utf8.encode('event-2'));
      await controller.close();
      await done;

      expect(received, ['event-1', 'event-2']);
    });

    test('multipart upload streams the file part (question 3)', () async {
      http.BaseRequest? captured;
      final client = _RecordingClient((request) async {
        captured = request;
        await request.finalize().drain<void>();
        return _json({'Key': 'avatars/a.png', 'Id': 'uuid'});
      });
      final api =
          StorageApi(ApiClient(baseUrl: 'https://x', httpClient: client));

      final result = await api.uploadObject(
        bucketId: 'avatars',
        wildcardPath: 'a.png',
        file: Stream.value(Uint8List.fromList([1, 2, 3])),
        fileLength: 3,
        fileName: 'a.png',
        cacheControl: '3600',
      );

      expect(captured, isA<http.MultipartRequest>());
      expect(result.key, 'avatars/a.png');
    });
  });

  group('Middleware / header injection (question 4)', () {
    test('headerProvider is invoked per request for fresh auth tokens',
        () async {
      var token = 'first';
      final client = _RecordingClient((_) async => _json({'items': []}));
      final api = StorageApi(
        ApiClient(
          baseUrl: 'https://x',
          httpClient: client,
          defaultHeaders: {'apikey': 'anon'},
          headerProvider: () => {'Authorization': 'Bearer $token'},
        ),
      );

      await api.listBuckets();
      expect(client.lastRequest!.headers['Authorization'], 'Bearer first');
      expect(client.lastRequest!.headers['apikey'], 'anon');

      token = 'refreshed';
      await api.listBuckets();
      expect(client.lastRequest!.headers['Authorization'], 'Bearer refreshed');
    });
  });
}
