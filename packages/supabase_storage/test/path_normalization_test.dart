import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_storage/supabase_storage.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';

const storageUrl = 'http://localhost/storage/v1';
const headers = {'Authorization': 'Bearer token'};

void main() {
  late CustomHttpClient mockClient;
  late SupabaseStorageClient client;

  setUp(() {
    mockClient = CustomHttpClient();
    client = SupabaseStorageClient(
      storageUrl,
      headers,
      httpClient: mockClient,
    );
  });

  Uri requestUrl() => mockClient.receivedRequests.single.url;

  dynamic requestBody() =>
      jsonDecode((mockClient.receivedRequests.single as http.Request).body);

  const unnormalizedPaths = [
    '/folder/file.txt',
    'folder/file.txt/',
    'folder//file.txt',
    '//folder//file.txt//',
  ];

  for (final path in unnormalizedPaths) {
    group('path "$path" is normalized', () {
      test('by download', () async {
        mockClient.response = Uint8List.fromList([1, 2, 3]);
        mockClient.statusCode = 200;

        await client.from('bucket').download(path);

        expect(
          requestUrl().path,
          '/storage/v1/object/bucket/folder/file.txt',
        );
      });

      test('by downloadStream', () async {
        mockClient.response = Uint8List.fromList([1, 2, 3]);
        mockClient.statusCode = 200;

        await client.from('bucket').downloadStream(path).drain<void>();

        expect(
          requestUrl().path,
          '/storage/v1/object/bucket/folder/file.txt',
        );
      });

      test('by createSignedUrl', () async {
        mockClient.response = {
          'signedURL': '/object/sign/bucket/folder/file.txt?token=abc',
        };
        mockClient.statusCode = 200;

        final signedUrl = await client.from('bucket').createSignedUrl(path, 60);

        expect(
          requestUrl().path,
          '/storage/v1/object/sign/bucket/folder/file.txt',
        );
        expect(signedUrl, contains('bucket/folder/file.txt'));
      });

      test('by createSignedUploadUrl, including the returned path', () async {
        mockClient.response = {
          'url': '/object/upload/sign/bucket/folder/file.txt?token=abc',
        };
        mockClient.statusCode = 200;

        final response = await client
            .from('bucket')
            .createSignedUploadUrl(path);

        expect(
          requestUrl().path,
          '/storage/v1/object/upload/sign/bucket/folder/file.txt',
        );
        expect(response.path, 'folder/file.txt');
      });

      test('by getMetadata', () async {
        mockClient.response = {
          'id': 'id',
          'version': '1',
          'name': 'folder/file.txt',
          'bucket_id': 'bucket',
          'updated_at': '2024-01-01T00:00:00Z',
          'created_at': '2024-01-01T00:00:00Z',
          'size': 3,
          'cache_control': 'no-cache',
          'content_type': 'text/plain',
          'etag': 'etag',
          'last_modified': '2024-01-01T00:00:00Z',
          'metadata': <String, dynamic>{},
        };
        mockClient.statusCode = 200;

        await client.from('bucket').getMetadata(path);

        expect(
          requestUrl().path,
          '/storage/v1/object/info/bucket/folder/file.txt',
        );
      });

      test('by exists', () async {
        mockClient.response = Uint8List.fromList([]);
        mockClient.statusCode = 200;

        final exists = await client.from('bucket').exists(path);

        expect(exists, isTrue);
        expect(
          requestUrl().path,
          '/storage/v1/object/bucket/folder/file.txt',
        );
      });

      test('by purgeCache', () async {
        mockClient.response = {'message': 'ok'};
        mockClient.statusCode = 200;

        await client.from('bucket').purgeCache(path);

        expect(
          requestUrl().path,
          '/storage/v1/cdn/bucket/folder/file.txt',
        );
      });

      test('by getPublicUrl', () {
        final publicUrl = client.from('bucket').getPublicUrl(path);

        expect(
          publicUrl,
          '$storageUrl/object/public/bucket/folder/file.txt',
        );
      });

      test('by uploadBinary, including the returned path', () async {
        mockClient.response = {
          'Id': 'id',
          'Key': 'bucket/folder/file.txt',
        };

        final response = await client
            .from('bucket')
            .uploadBinary(path, Uint8List.fromList([1, 2, 3]));

        expect(
          requestUrl().path,
          '/storage/v1/object/bucket/folder/file.txt',
        );
        expect(response.path, 'folder/file.txt');
      });

      test('by updateBinary, including the returned path', () async {
        mockClient.response = {
          'Id': 'id',
          'Key': 'bucket/folder/file.txt',
        };
        mockClient.statusCode = 200;

        final response = await client
            .from('bucket')
            .updateBinary(path, Uint8List.fromList([1, 2, 3]));

        expect(
          requestUrl().path,
          '/storage/v1/object/bucket/folder/file.txt',
        );
        expect(response.path, 'folder/file.txt');
      });

      test('by move, in the request body', () async {
        mockClient.response = {'message': 'ok'};
        mockClient.statusCode = 200;

        await client.from('bucket').move(path, path);

        final body = requestBody() as Map<String, dynamic>;
        expect(body['sourceKey'], 'folder/file.txt');
        expect(body['destinationKey'], 'folder/file.txt');
      });

      test('by copy, in the request body', () async {
        mockClient.response = {'Key': 'bucket/folder/file.txt'};
        mockClient.statusCode = 200;

        await client.from('bucket').copy(path, path);

        final body = requestBody() as Map<String, dynamic>;
        expect(body['sourceKey'], 'folder/file.txt');
        expect(body['destinationKey'], 'folder/file.txt');
      });

      test('by remove, in the request body', () async {
        mockClient.response = <dynamic>[];
        mockClient.statusCode = 200;

        await client.from('bucket').remove([path]);

        final body = requestBody() as Map<String, dynamic>;
        expect(body['prefixes'], ['folder/file.txt']);
      });

      test('by createSignedUrls, in the request body', () async {
        mockClient.response = [
          {
            'signedURL': '/object/sign/bucket/folder/file.txt?token=abc',
            'path': 'folder/file.txt',
          },
        ];
        mockClient.statusCode = 200;

        await client.from('bucket').createSignedUrls([path], 60);

        final body = requestBody() as Map<String, dynamic>;
        expect(body['paths'], ['folder/file.txt']);
      });

      test('by list, in the request body', () async {
        mockClient.response = <dynamic>[];
        mockClient.statusCode = 200;

        await client.from('bucket').list(path: path);

        final body = requestBody() as Map<String, dynamic>;
        expect(body['prefix'], 'folder/file.txt');
      });

      test('by listPaginated, in the request body', () async {
        mockClient.response = {
          'hasNext': false,
          'objects': <dynamic>[],
        };
        mockClient.statusCode = 200;

        await client
            .from('bucket')
            .listPaginated(
              options: PaginatedSearchOptions(prefix: path),
            );

        final body = requestBody() as Map<String, dynamic>;
        expect(body['prefix'], 'folder/file.txt');
      });

      test('by uploadBinaryToSignedUrl, including the returned path', () async {
        mockClient.response = {
          'Key': 'bucket/folder/file.txt',
        };
        mockClient.statusCode = 200;

        final response = await client
            .from('bucket')
            .uploadBinaryToSignedUrl(
              path,
              'token',
              Uint8List.fromList([1, 2, 3]),
            );

        expect(
          requestUrl().path,
          '/storage/v1/object/upload/sign/bucket/folder/file.txt',
        );
        expect(response.path, 'folder/file.txt');
      });
    });
  }
}
