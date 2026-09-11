import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:supabase_storage/supabase_storage.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

const storageUrl = 'http://localhost/storage/v1';
const headers = {'Authorization': 'Bearer token'};

/// Client that finalizes (reads) the request body before failing, mimicking a
/// real HTTP client. This exercises [MultipartFile] finalization on every retry
/// attempt, which previously crashed because the same file instance was reused.
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
  group('multipart uploads', () {
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
        throwsA(isA<ClientException>()),
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
        throwsA(isA<ClientException>()),
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

        final request = mockClient.requests.single.request as MultipartRequest;
        expect(request.files.single.contentType.mimeType, 'image/png');
      },
    );
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
      final abortSignal = Completer<void>();
      Timer(const Duration(milliseconds: 50), abortSignal.complete);

      await expectLater(
        client
            .from('bucket')
            .uploadBinary(
              'a.txt',
              Uint8List.fromList([1, 2, 3]),
              abortSignal: abortSignal.future,
            ),
        throwsA(isA<RequestAbortedException>()),
      );
    });

    test('aborts an in-flight signed url upload', () async {
      mockClient.stubStall();
      final abortSignal = Completer<void>();
      Timer(const Duration(milliseconds: 50), abortSignal.complete);

      await expectLater(
        client
            .from('bucket')
            .uploadBinaryToSignedUrl(
              'a.txt',
              'signed-token',
              Uint8List.fromList([1, 2, 3]),
              const FileOptions(),
              null,
              abortSignal.future,
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
      final abortSignal = Completer<void>();
      Timer(const Duration(milliseconds: 50), abortSignal.complete);

      await expectLater(
        retryingClient
            .from('bucket')
            .updateBinary(
              'a.txt',
              Uint8List.fromList([1, 2, 3]),
              abortSignal: abortSignal.future,
            ),
        throwsA(isA<RequestAbortedException>()),
      );
      expect(mockClient.requests, hasLength(1));
    });

    test('aborts an in-flight download', () async {
      mockClient.stubStall();
      final abortSignal = Completer<void>();
      Timer(const Duration(milliseconds: 50), abortSignal.complete);

      await expectLater(
        client
            .from('bucket')
            .download('a.txt', abortSignal: abortSignal.future),
        throwsA(isA<RequestAbortedException>()),
      );
    });

    test('aborts an in-flight streamed download', () async {
      mockClient.stubStall();
      final abortSignal = Completer<void>();
      Timer(const Duration(milliseconds: 50), abortSignal.complete);

      await expectLater(
        client
            .from('bucket')
            .downloadStream('a.txt', abortSignal: abortSignal.future)
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
  });
}
