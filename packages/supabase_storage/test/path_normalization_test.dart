import 'dart:typed_data';

import 'package:supabase_storage/supabase_storage.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

const storageUrl = 'http://localhost/storage/v1';
const headers = {'Authorization': 'Bearer token'};

void main() {
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

  Uri requestUrl() => mockClient.requests.single.url;

  dynamic requestBody() => mockClient.requests.single.jsonBody;

  const unnormalizedPaths = [
    '/folder/file.txt',
    'folder/file.txt/',
    'folder//file.txt',
    '//folder//file.txt//',
  ];

  for (final path in unnormalizedPaths) {
    group('path "$path" is normalized', () {
      test('by download', () async {
        mockClient.stub(Uint8List.fromList([1, 2, 3]));

        await client.from('bucket').download(path);

        expect(
          requestUrl().path,
          '/storage/v1/object/bucket/folder/file.txt',
        );
      });

      test('by downloadStream', () async {
        mockClient.stub(Uint8List.fromList([1, 2, 3]));

        await client.from('bucket').downloadStream(path).drain<void>();

        expect(
          requestUrl().path,
          '/storage/v1/object/bucket/folder/file.txt',
        );
      });

      test('by createSignedUrl', () async {
        mockClient.stub({
          'signedURL': '/object/sign/bucket/folder/file.txt?token=abc',
        });

        final signedUrl = await client.from('bucket').createSignedUrl(path, 60);

        expect(
          requestUrl().path,
          '/storage/v1/object/sign/bucket/folder/file.txt',
        );
        expect(signedUrl, contains('bucket/folder/file.txt'));
      });

      test('by createSignedUploadUrl, including the returned path', () async {
        mockClient.stub({
          'url': '/object/upload/sign/bucket/folder/file.txt?token=abc',
        });

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
        mockClient.stub({
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
        });

        await client.from('bucket').getMetadata(path);

        expect(
          requestUrl().path,
          '/storage/v1/object/info/bucket/folder/file.txt',
        );
      });

      test('by exists', () async {
        mockClient.stub(Uint8List.fromList([]));

        final exists = await client.from('bucket').exists(path);

        expect(exists, isTrue);
        expect(
          requestUrl().path,
          '/storage/v1/object/bucket/folder/file.txt',
        );
      });

      test('by purgeCache', () async {
        mockClient.stub({'message': 'ok'});

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
        mockClient.stub({
          'Id': 'id',
          'Key': 'bucket/folder/file.txt',
        });

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
        mockClient.stub({
          'Id': 'id',
          'Key': 'bucket/folder/file.txt',
        });

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
        mockClient.stub({'message': 'ok'});

        await client.from('bucket').move(path, path);

        final body = requestBody() as Map<String, dynamic>;
        expect(body['sourceKey'], 'folder/file.txt');
        expect(body['destinationKey'], 'folder/file.txt');
      });

      test('by copy, in the request body', () async {
        mockClient.stub({'Key': 'bucket/folder/file.txt'});

        await client.from('bucket').copy(path, path);

        final body = requestBody() as Map<String, dynamic>;
        expect(body['sourceKey'], 'folder/file.txt');
        expect(body['destinationKey'], 'folder/file.txt');
      });

      test('by remove, in the request body', () async {
        mockClient.stub(<dynamic>[]);

        await client.from('bucket').remove([path]);

        final body = requestBody() as Map<String, dynamic>;
        expect(body['prefixes'], ['folder/file.txt']);
      });

      test('by createSignedUrls, in the request body', () async {
        mockClient.stub([
          {
            'signedURL': '/object/sign/bucket/folder/file.txt?token=abc',
            'path': 'folder/file.txt',
          },
        ]);

        await client.from('bucket').createSignedUrls([path], 60);

        final body = requestBody() as Map<String, dynamic>;
        expect(body['paths'], ['folder/file.txt']);
      });

      test('by list, in the request body', () async {
        mockClient.stub(<dynamic>[]);

        await client.from('bucket').list(path: path);

        final body = requestBody() as Map<String, dynamic>;
        expect(body['prefix'], 'folder/file.txt');
      });

      test('by listPaginated, in the request body', () async {
        mockClient.stub({
          'hasNext': false,
          'objects': <dynamic>[],
        });

        await client
            .from('bucket')
            .listPaginated(
              options: PaginatedSearchOptions(prefix: path),
            );

        final body = requestBody() as Map<String, dynamic>;
        expect(body['prefix'], 'folder/file.txt');
      });

      test('by uploadBinaryToSignedUrl, including the returned path', () async {
        mockClient.stub({
          'Key': 'bucket/folder/file.txt',
        });

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
