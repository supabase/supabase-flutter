import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:storage_client/storage_client.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';

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
          retryAttempts: 3,
        );

        final result = await client
            .from('bucket')
            .uploadBinary('folder/file.png', Uint8List.fromList([1, 2, 3]));

        expect(result, 'public/a.txt');
        expect(retryClient.attempts, 2);
      },
    );

    test(
      'detects content type from the path of a binary signed url upload',
      () async {
        final mockClient = CustomHttpClient();
        mockClient.response = <String, dynamic>{};
        mockClient.statusCode = 200;
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

        final request = mockClient.receivedRequests.single as MultipartRequest;
        expect(request.files.single.contentType.mimeType, 'image/png');
      },
    );
  });

  group('path normalization', () {
    test(
      'removes leading, trailing and duplicate slashes from the path',
      () async {
        final mockClient = CustomHttpClient();
        mockClient.response = <String, dynamic>{};
        mockClient.statusCode = 200;
        final client = SupabaseStorageClient(
          storageUrl,
          headers,
          httpClient: mockClient,
        );

        final cleanPath = await client
            .from('bucket')
            .uploadBinaryToSignedUrl(
              '/folder//image.png/',
              'signed-token',
              Uint8List.fromList([1]),
            );

        expect(cleanPath, 'folder/image.png');

        final requestPath = mockClient.receivedRequests.single.url.path;
        expect(requestPath, endsWith('/bucket/folder/image.png'));
        expect(requestPath, isNot(contains('//')));
      },
    );
  });
}
