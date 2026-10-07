import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_common/supabase_common.dart' show HttpMethod;
import 'package:supabase_storage/supabase_storage.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

const storageUrl = 'http://localhost/storage/v1';
const headers = {'Authorization': 'Bearer token'};

/// Client that finalizes (reads) the request body before failing, mimicking a
/// real HTTP client. This exercises body finalization on every retry attempt,
/// which needs a fresh body stream since the previous attempt consumed it.
class FinalizingRetryHttpClient extends BaseClient {
  FinalizingRetryHttpClient({this.failuresBeforeSuccess = 1});

  final int failuresBeforeSuccess;
  int attempts = 0;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    attempts++;
    await request.finalize().drain<void>();
    if (attempts <= failuresBeforeSuccess) {
      throw ClientException('Offline');
    }
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'Key': 'public/a.txt'}))),
      201,
      request: request,
    );
  }
}

/// Client that answers with a JSON body that is not an object, which a proxy or
/// gateway in front of storage can do.
class NonObjectErrorHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    await request.finalize().drain<void>();
    return StreamedResponse(
      Stream.value(utf8.encode('["upstream connect error"]')),
      502,
      request: request,
    );
  }
}

void main() {
  group('uploads', () {
    late Directory temporaryDirectory;

    setUp(() {
      temporaryDirectory = Directory.systemTemp.createTempSync('storage_test');
    });

    tearDown(() {
      temporaryDirectory.deleteSync(recursive: true);
    });

    test(
      'sends the bytes as the raw body with the file options as headers',
      () async {
        final mockClient = MockSupabaseHttpClient();
        mockClient.stub({'Key': 'bucket/a.txt'});
        final client = SupabaseStorageClient(
          storageUrl,
          headers,
          httpClient: mockClient,
        );
        const metadata = {
          'owner': 'me',
          'tags': ['a', 'b'],
        };

        await client
            .from('bucket')
            .uploadBinary(
              'a.txt',
              Uint8List.fromList([1, 2, 3]),
              fileOptions: const FileOptions(
                cacheControl: '60',
                upsert: true,
                contentType: 'text/plain',
                metadata: metadata,
                headers: {'x-custom': 'value'},
              ),
            );

        final request = mockClient.requests.single;
        expect(request.method, HttpMethod.post.value);
        expect(request.bodyBytes, [1, 2, 3]);
        expect(request.request.contentLength, 3);
        expect(request.headers['content-type'], 'text/plain');
        expect(request.headers['cache-control'], 'max-age=60');
        expect(request.headers['x-upsert'], 'true');
        expect(request.headers['x-custom'], 'value');
        expect(request.headers['authorization'], 'Bearer token');
        expect(
          json.decode(
            utf8.decode(base64.decode(request.headers['x-metadata']!)),
          ),
          metadata,
        );
      },
    );

    test('sends no x-metadata header without metadata', () async {
      final mockClient = MockSupabaseHttpClient();
      mockClient.stub({'Key': 'bucket/a.txt'});
      final client = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: mockClient,
      );

      await client
          .from('bucket')
          .uploadBinary('a.txt', Uint8List.fromList([1, 2, 3]));

      final request = mockClient.requests.single;
      expect(request.headers.containsKey('x-metadata'), isFalse);
      expect(request.headers['cache-control'], 'max-age=3600');
      expect(request.headers['x-upsert'], 'false');
    });

    test('streams a file from disk as the raw body', () async {
      final mockClient = MockSupabaseHttpClient();
      mockClient.stub({'Key': 'bucket/folder/notes.txt'});
      final client = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: mockClient,
      );
      final file = File('${temporaryDirectory.path}/notes.txt')
        ..writeAsStringSync('hello');

      final response = await client
          .from('bucket')
          .upload('folder/notes.txt', file);

      expect(response.fullPath, 'bucket/folder/notes.txt');
      final request = mockClient.requests.single;
      expect(request.body, 'hello');
      expect(request.request.contentLength, 5);
      expect(request.headers['content-type'], 'text/plain');
    });

    test('detects the content type of a file from its own path', () async {
      final mockClient = MockSupabaseHttpClient();
      mockClient.stub({'Key': 'bucket/a'});
      final client = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: mockClient,
      );
      final file = File('${temporaryDirectory.path}/picture.png')
        ..writeAsBytesSync([1, 2, 3]);

      await client.from('bucket').upload('a', file);

      expect(mockClient.requests.single.headers['content-type'], 'image/png');
    });

    test('re-reads the file on every retry attempt', () async {
      final retryClient = FinalizingRetryHttpClient(failuresBeforeSuccess: 2);
      final client = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: retryClient,
        retryOptions: const SupabaseRetryOptions(
          count: 3,
          initialDelay: Duration(milliseconds: 1),
        ),
      );
      final file = File('${temporaryDirectory.path}/notes.txt')
        ..writeAsStringSync('hello');

      final result = await client.from('bucket').upload('notes.txt', file);

      expect(result.fullPath, 'public/a.txt');
      expect(retryClient.attempts, 3);
    });

    test('an update sends the body with PUT', () async {
      final mockClient = MockSupabaseHttpClient();
      mockClient.stub({'Key': 'bucket/a.txt'});
      final client = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: mockClient,
      );

      await client
          .from('bucket')
          .updateBinary('a.txt', Uint8List.fromList([4, 5]));

      final request = mockClient.requests.single;
      expect(request.method, HttpMethod.put.value);
      expect(request.bodyBytes, [4, 5]);
    });

    test(
      'retries a binary upload after a failure that finalized the request',
      () async {
        final retryClient = FinalizingRetryHttpClient(failuresBeforeSuccess: 1);
        final client = SupabaseStorageClient(
          storageUrl,
          headers,
          httpClient: retryClient,
          retryOptions: const SupabaseRetryOptions(count: 3),
        );

        final result = await client
            .from('bucket')
            .uploadBinary('folder/file.png', Uint8List.fromList([1, 2, 3]));

        expect(result.fullPath, 'public/a.txt');
        expect(retryClient.attempts, 2);
      },
    );

    test('does not retry an upload by default', () async {
      final retryClient = FinalizingRetryHttpClient(failuresBeforeSuccess: 1);
      final client = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: retryClient,
      );

      await expectLater(
        client
            .from('bucket')
            .uploadBinary(
              'folder/file.png',
              Uint8List.fromList([1, 2, 3]),
            ),
        throwsA(
          isA<StorageTransportException>().having(
            (error) => error.cause,
            'cause',
            isA<ClientException>(),
          ),
        ),
      );
      expect(retryClient.attempts, 1);
    });

    test('does not retry an upload with retries disabled', () async {
      final retryClient = FinalizingRetryHttpClient(failuresBeforeSuccess: 1);
      final client = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: retryClient,
        retryOptions: const SupabaseRetryOptions(count: 3, enabled: false),
      );

      await expectLater(
        client
            .from('bucket')
            .uploadBinary(
              'folder/file.png',
              Uint8List.fromList([1, 2, 3]),
            ),
        throwsA(
          isA<StorageTransportException>().having(
            (error) => error.cause,
            'cause',
            isA<ClientException>(),
          ),
        ),
      );
      expect(retryClient.attempts, 1);
    });

    test('a per-upload override replaces the client retry options', () async {
      final retryClient = FinalizingRetryHttpClient(failuresBeforeSuccess: 2);
      final client = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: retryClient,
        retryOptions: const SupabaseRetryOptions(count: 0),
      );

      final result = await client
          .from('bucket')
          .uploadBinary(
            'folder/file.png',
            Uint8List.fromList([1, 2, 3]),
            retryOptions: const SupabaseRetryOptions(
              count: 2,
              initialDelay: Duration(milliseconds: 1),
            ),
          );

      expect(result.fullPath, 'public/a.txt');
      expect(retryClient.attempts, 3);
    });

    test(
      'detects content type from the path of a binary signed url upload',
      () async {
        final mockClient = MockSupabaseHttpClient();
        mockClient.stub({'Key': 'bucket/folder/image.png'});
        final client = SupabaseStorageClient(
          storageUrl,
          headers,
          httpClient: mockClient,
        );

        await client
            .from('bucket')
            .uploadBinaryToSignedUrl(
              'folder/image.png',
              'signed-token',
              Uint8List.fromList([1, 2, 3]),
            );

        final request = mockClient.requests.single;
        expect(request.headers['content-type'], 'image/png');
        expect(request.queryParameters['token'], 'signed-token');
      },
    );
  });

  group('stream uploads', () {
    late MockSupabaseHttpClient mockClient;
    late SupabaseStorageClient client;

    setUp(() {
      mockClient = MockSupabaseHttpClient();
      client = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: mockClient,
      );
    });

    test('sends the stream as the raw body with its content length', () async {
      mockClient.stub({'Key': 'bucket/a.txt'});

      final response = await client
          .from('bucket')
          .uploadStream(
            'a.txt',
            Stream.fromIterable([
              [1, 2],
              [3],
            ]),
            contentLength: 3,
            fileOptions: const FileOptions(metadata: {'kind': 'notes'}),
          );

      expect(response.fullPath, 'bucket/a.txt');
      final request = mockClient.requests.single;
      expect(request.method, HttpMethod.post.value);
      expect(request.bodyBytes, [1, 2, 3]);
      expect(request.request.contentLength, 3);
      expect(request.headers['content-type'], 'text/plain');
      expect(request.headers['cache-control'], 'max-age=3600');
      expect(
        json.decode(utf8.decode(base64.decode(request.headers['x-metadata']!))),
        {'kind': 'notes'},
      );
    });

    test('sends an unknown length as a chunked body', () async {
      mockClient.stub({'Key': 'bucket/a.txt'});

      await client
          .from('bucket')
          .uploadStream(
            'a.txt',
            Stream.value([1, 2, 3]),
          );

      final request = mockClient.requests.single;
      expect(request.bodyBytes, [1, 2, 3]);
      expect(request.request.contentLength, isNull);
    });

    test('an update streams the body with PUT', () async {
      mockClient.stub({'Key': 'bucket/a.txt'});

      await client
          .from('bucket')
          .updateStream(
            'a.txt',
            Stream.value([1, 2, 3]),
            contentLength: 3,
          );

      final request = mockClient.requests.single;
      expect(request.method, HttpMethod.put.value);
      expect(request.bodyBytes, [1, 2, 3]);
    });

    test(
      'a signed url upload streams the body with PUT and the token',
      () async {
        mockClient.stub({'Key': 'bucket/a.txt'});

        final response = await client
            .from('bucket')
            .uploadStreamToSignedUrl(
              'a.txt',
              'signed-token',
              Stream.value([1, 2, 3]),
              contentLength: 3,
            );

        expect(response.id, isNull);
        expect(response.fullPath, 'bucket/a.txt');
        final request = mockClient.requests.single;
        expect(request.method, HttpMethod.put.value);
        expect(request.url.path, endsWith('/object/upload/sign/bucket/a.txt'));
        expect(request.queryParameters['token'], 'signed-token');
        expect(request.bodyBytes, [1, 2, 3]);
      },
    );

    test('is never retried, since the stream can be read only once', () async {
      final retryClient = FinalizingRetryHttpClient(failuresBeforeSuccess: 1);
      final retryingClient = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: retryClient,
        retryOptions: const SupabaseRetryOptions(count: 3),
      );

      await expectLater(
        retryingClient
            .from('bucket')
            .uploadStream(
              'a.txt',
              Stream.value([1, 2, 3]),
              contentLength: 3,
            ),
        throwsA(
          isA<StorageTransportException>().having(
            (error) => error.cause,
            'cause',
            isA<ClientException>(),
          ),
        ),
      );
      expect(retryClient.attempts, 1);
    });

    test('hands the abort signal to the request', () async {
      mockClient.stub({'Key': 'bucket/a.txt'});
      final abortSignal = Completer<void>();

      await client
          .from('bucket')
          .uploadStream(
            'a.txt',
            Stream.value([1, 2, 3]),
            abortSignal: abortSignal.future,
          );

      final request = mockClient.requests.single.request as Abortable;
      expect(request.abortTrigger, same(abortSignal.future));
    });

    test('aborts an in-flight stream upload', () async {
      mockClient.stubStall();
      final abortSignal = Future<void>.delayed(
        const Duration(milliseconds: 50),
      );

      await expectLater(
        client
            .from('bucket')
            .uploadStream(
              'a.txt',
              Stream.value([1, 2, 3]),
              abortSignal: abortSignal,
            ),
        throwsA(isA<RequestAbortedException>()),
      );
    });
  });

  group('request cancellation', () {
    late MockSupabaseHttpClient mockClient;
    late SupabaseStorageClient client;

    setUp(() {
      mockClient = MockSupabaseHttpClient();
      client = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: mockClient,
      );
    });

    test('hands the abort signal to the upload request', () async {
      mockClient.stub({'Key': 'bucket/a.txt'});
      final abortSignal = Completer<void>();

      await client
          .from('bucket')
          .uploadBinary(
            'a.txt',
            Uint8List.fromList([1, 2, 3]),
            abortSignal: abortSignal.future,
          );

      final request = mockClient.requests.single.request as Abortable;
      expect(request.abortTrigger, same(abortSignal.future));
    });

    test('aborts an in-flight upload', () async {
      mockClient.stubStall();
      final abortSignal = Future<void>.delayed(
        const Duration(milliseconds: 50),
      );

      await expectLater(
        client
            .from('bucket')
            .uploadBinary(
              'a.txt',
              Uint8List.fromList([1, 2, 3]),
              abortSignal: abortSignal,
            ),
        throwsA(isA<RequestAbortedException>()),
      );
    });

    test('aborts an in-flight signed url upload', () async {
      mockClient.stubStall();
      final abortSignal = Future<void>.delayed(
        const Duration(milliseconds: 50),
      );

      await expectLater(
        client
            .from('bucket')
            .uploadBinaryToSignedUrl(
              'a.txt',
              'signed-token',
              Uint8List.fromList([1, 2, 3]),
              const FileOptions(),
              null,
              abortSignal,
            ),
        throwsA(isA<RequestAbortedException>()),
      );
    });

    test('aborting an upload does not retry it', () async {
      mockClient.stubStall();
      final retryingClient = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: mockClient,
        retryOptions: const SupabaseRetryOptions(count: 3),
      );
      final abortSignal = Future<void>.delayed(
        const Duration(milliseconds: 50),
      );

      await expectLater(
        retryingClient
            .from('bucket')
            .updateBinary(
              'a.txt',
              Uint8List.fromList([1, 2, 3]),
              abortSignal: abortSignal,
            ),
        throwsA(isA<RequestAbortedException>()),
      );
      expect(mockClient.requests, hasLength(1));
    });

    test('aborts an in-flight download', () async {
      mockClient.stubStall();
      final abortSignal = Future<void>.delayed(
        const Duration(milliseconds: 50),
      );

      await expectLater(
        client.from('bucket').download('a.txt', abortSignal: abortSignal),
        throwsA(isA<RequestAbortedException>()),
      );
    });

    test('aborts an in-flight streamed download', () async {
      mockClient.stubStall();
      final abortSignal = Future<void>.delayed(
        const Duration(milliseconds: 50),
      );

      await expectLater(
        client
            .from('bucket')
            .downloadStream('a.txt', abortSignal: abortSignal)
            .toList(),
        throwsA(isA<RequestAbortedException>()),
      );
    });
  });

  group('path normalization', () {
    test(
      'removes leading, trailing and duplicate slashes from the path',
      () async {
        final mockClient = MockSupabaseHttpClient();
        mockClient.stub({'Key': 'bucket/folder/image.png'});
        final client = SupabaseStorageClient(
          storageUrl,
          headers,
          httpClient: mockClient,
        );

        final response = await client
            .from('bucket')
            .uploadBinaryToSignedUrl(
              '/folder//image.png/',
              'signed-token',
              Uint8List.fromList([1]),
            );

        expect(response.path, 'folder/image.png');
        expect(response.fullPath, 'bucket/folder/image.png');

        final requestPath = mockClient.requests.single.url.path;
        expect(requestPath, endsWith('/bucket/folder/image.png'));
        expect(requestPath, isNot(contains('//')));
      },
    );
  });

  group('error responses', () {
    test('passes an exception the HTTP client classified through', () async {
      final client = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: MockSupabaseHttpClient()
          ..stubError(const StorageException('session expired')),
      );

      await expectLater(
        client.from('bucket').list(),
        throwsA(
          allOf(
            isA<StorageException>().having(
              (error) => error.message,
              'message',
              'session expired',
            ),
            isNot(isA<StorageTransportException>()),
          ),
        ),
      );
    });

    test('a body that fails to arrive throws a StorageTransportException', () {
      final client = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: MockClient.streaming(
          (request, bodyStream) async => StreamedResponse(
            Stream.error(ClientException('Connection reset', request.url)),
            200,
            request: request,
          ),
        ),
      );

      return expectLater(
        client.from('bucket').list(),
        throwsA(
          isA<StorageTransportException>().having(
            (error) => error.cause,
            'cause',
            isA<ClientException>(),
          ),
        ),
      );
    });

    test('a body that fails to arrive on an error status keeps it', () {
      final client = SupabaseStorageClient(
        storageUrl,
        headers,
        httpClient: MockClient.streaming(
          (request, bodyStream) async => StreamedResponse(
            Stream.error(ClientException('Connection reset', request.url)),
            403,
            request: request,
            headers: {'sb-request-id': 'request-1'},
          ),
        ),
      );

      return expectLater(
        client.from('bucket').list(),
        throwsA(
          isA<StorageApiException>()
              .having((error) => error.statusCode, 'statusCode', 403)
              .having((error) => error.requestId, 'requestId', 'request-1')
              .having((error) => error.body, 'body', isNull)
              .having(
                (error) => error.message,
                'message',
                contains('Connection reset'),
              ),
        ),
      );
    });

    test(
      'a JSON body that is not an object surfaces as a StorageException',
      () {
        final client = SupabaseStorageClient(
          storageUrl,
          headers,
          httpClient: NonObjectErrorHttpClient(),
        );

        expect(
          client.from('bucket').list(),
          throwsA(
            isA<StorageApiException>()
                .having((e) => e.statusCode, 'statusCode', 502)
                .having(
                  (e) => e.message,
                  'message',
                  '["upstream connect error"]',
                )
                .having((e) => e.errorCode, 'errorCode', isNull),
          ),
        );
      },
    );

    group('request id', () {
      const requestIdHeaders = {'sb-request-id': 'request-1'};

      test('is read from the response of a JSON error body', () async {
        final httpClient = MockSupabaseHttpClient()
          ..stub(
            {'statusCode': '404', 'code': 'NoSuchKey', 'message': 'not found'},
            statusCode: 404,
            headers: requestIdHeaders,
          );
        final client = SupabaseStorageClient(
          storageUrl,
          headers,
          httpClient: httpClient,
        );

        await expectLater(
          client.from('bucket').list(),
          throwsA(
            isA<StorageApiException>()
                .having((e) => e.errorCode, 'errorCode', 'NoSuchKey')
                .having((e) => e.requestId, 'requestId', 'request-1'),
          ),
        );
      });

      test('is read from the response of a non-JSON error body', () async {
        final httpClient = MockSupabaseHttpClient()
          ..stubText(
            '<html>502 Bad Gateway</html>',
            statusCode: 502,
            headers: requestIdHeaders,
          );
        final client = SupabaseStorageClient(
          storageUrl,
          headers,
          httpClient: httpClient,
        );

        await expectLater(
          client.from('bucket').list(),
          throwsA(
            isA<StorageApiException>()
                .having((e) => e.statusCode, 'statusCode', 502)
                .having((e) => e.requestId, 'requestId', 'request-1'),
          ),
        );
      });

      test('is read from a success response of the wrong shape', () async {
        final httpClient = MockSupabaseHttpClient()
          ..stub({'not': 'a list'}, headers: requestIdHeaders);
        final client = SupabaseStorageClient(
          storageUrl,
          headers,
          httpClient: httpClient,
        );

        await expectLater(
          client.from('bucket').list(),
          throwsA(
            isA<StorageException>()
                .having((e) => e.message, 'message', startsWith('Expected a'))
                .having((e) => e.requestId, 'requestId', 'request-1'),
          ),
        );
      });

      test('is null when the response carries none', () async {
        final httpClient = MockSupabaseHttpClient()
          ..stub(
            {'statusCode': '404', 'code': 'NoSuchKey', 'message': 'not found'},
            statusCode: 404,
          );
        final client = SupabaseStorageClient(
          storageUrl,
          headers,
          httpClient: httpClient,
        );

        await expectLater(
          client.from('bucket').list(),
          throwsA(
            isA<StorageApiException>().having(
              (e) => e.requestId,
              'requestId',
              isNull,
            ),
          ),
        );
      });
    });
  });
}
