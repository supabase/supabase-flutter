import 'dart:typed_data';

import 'package:supabase_storage/supabase_storage.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

const storageUrl = 'http://localhost/storage/v1';

Map<String, dynamic> get bucketJson => {
  'id': 'avatars',
  'name': 'avatars',
  'owner': 'owner-id',
  'created_at': '2024-01-01T00:00:00.000Z',
  'updated_at': '2024-01-02T00:00:00.000Z',
  'public': false,
};

Matcher throwsFormatExceptionNaming(String field) => throwsA(
  isA<FormatException>().having(
    (exception) => exception.message,
    'message',
    contains('"$field"'),
  ),
);

void main() {
  late MockSupabaseHttpClient httpClient;
  late SupabaseStorageClient storage;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    storage = SupabaseStorageClient(storageUrl, {
      'Authorization': 'Bearer token',
    }, httpClient: httpClient);
  });

  group('buckets', () {
    test('getBucket names a field of the wrong type', () async {
      httpClient.stub({...bucketJson, 'public': 'yes'});

      await expectLater(
        () => storage.getBucket('avatars'),
        throwsFormatExceptionNaming('public'),
      );
    });

    test('getBucket throws a StorageException for a non-object body', () {
      httpClient.stub([bucketJson]);

      expect(
        () => storage.getBucket('avatars'),
        throwsA(isA<StorageException>()),
      );
    });

    test('listBuckets names a mime type of the wrong type', () async {
      httpClient.stub([
        {
          ...bucketJson,
          'allowed_mime_types': ['image/png', 1],
        },
      ]);

      await expectLater(
        storage.listBuckets,
        throwsFormatExceptionNaming('allowed_mime_types'),
      );
    });

    test('listBuckets rejects an entry that is not an object', () async {
      httpClient.stub(['avatars']);

      await expectLater(
        storage.listBuckets,
        throwsA(
          isA<FormatException>().having(
            (exception) => exception.message,
            'message',
            contains('bucket'),
          ),
        ),
      );
    });

    test('getBucketLifecycle names a field of the wrong type', () async {
      httpClient.stubStorageBucketLifecycle(
        'avatars',
        rules: [
          {
            ...lifecycleRuleJson(),
            'noncurrentVersionExpiration': {'noncurrentDays': '30'},
          },
        ],
      );

      await expectLater(
        () => storage.getBucketLifecycle('avatars'),
        throwsFormatExceptionNaming('noncurrentDays'),
      );
    });

    test('getBucketLifecycle names missing rules', () async {
      httpClient.stub(<String, dynamic>{});

      await expectLater(
        () => storage.getBucketLifecycle('avatars'),
        throwsFormatExceptionNaming('rules'),
      );
    });

    test('listAnalyticsBuckets names a field of the wrong type', () async {
      httpClient.stub([
        {
          'id': 'warehouse',
          'name': 1,
          'created_at': '2024-01-01T00:00:00.000Z',
          'updated_at': '2024-01-02T00:00:00.000Z',
        },
      ]);

      await expectLater(
        storage.listAnalyticsBuckets,
        throwsFormatExceptionNaming('name'),
      );
    });
  });

  group('file objects', () {
    test('list names a field of the wrong type', () async {
      httpClient.stubStorageList(
        'avatars',
        objects: [
          {...storageObjectJson('a.png'), 'is_versioned': 'yes'},
        ],
      );

      await expectLater(
        () => storage.from('avatars').list(),
        throwsFormatExceptionNaming('is_versioned'),
      );
    });

    test('getMetadata names a field of the wrong type', () async {
      httpClient.stub({
        ...storageObjectJson('a.png'),
        'version': 'version-1',
        'size': '1024',
      });

      await expectLater(
        () => storage.from('avatars').getMetadata('a.png'),
        throwsFormatExceptionNaming('size'),
      );
    });

    test('listPaginated names an entry of the wrong type', () async {
      httpClient.stub({
        'hasNext': false,
        'folders': ['photos'],
        'objects': <Object>[],
      });

      await expectLater(
        () => storage.from('avatars').listPaginated(),
        throwsFormatExceptionNaming('folders'),
      );
    });

    test('upload names a field of the wrong type', () async {
      httpClient.stub({'Key': 1, 'Id': 'object-id'}, method: HttpMethod.post);

      await expectLater(
        () => storage
            .from('avatars')
            .uploadBinary('a.png', Uint8List.fromList([1, 2, 3])),
        throwsFormatExceptionNaming('Key'),
      );
    });

    test('createSignedUrls names a field of the wrong type', () async {
      httpClient.stub([
        {'path': 'a.png', 'signedURL': 1},
      ]);

      await expectLater(
        () => storage.from('avatars').createSignedUrls(['a.png'], 60),
        throwsFormatExceptionNaming('signedURL'),
      );
    });

    test('createSignedUrls rejects an entry that is not an object', () async {
      httpClient.stub(['a.png']);

      await expectLater(
        () => storage.from('avatars').createSignedUrls(['a.png'], 60),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('vectors', () {
    late SupabaseVectorsClient vectors;

    setUp(() => vectors = storage.vectors);

    test('getBucket names a missing bucket', () async {
      httpClient.stub(<String, dynamic>{});

      await expectLater(
        () => vectors.getBucket('embeddings'),
        throwsFormatExceptionNaming('vectorBucket'),
      );
    });

    test('getBucket throws a StorageException for a non-object body', () {
      httpClient.stub(<Object>[]);

      expect(
        () => vectors.getBucket('embeddings'),
        throwsA(isA<StorageException>()),
      );
    });

    test('getIndex names a field of the wrong type', () async {
      httpClient.stub({
        'index': {'indexName': 'documents', 'dimension': '3'},
      });

      await expectLater(
        () => vectors.from('embeddings').getIndex('documents'),
        throwsFormatExceptionNaming('dimension'),
      );
    });

    test('listBuckets names a list of the wrong type', () async {
      httpClient.stub({'vectorBuckets': 'embeddings'});

      await expectLater(
        vectors.listBuckets,
        throwsFormatExceptionNaming('vectorBuckets'),
      );
    });

    test('queryVectors names a field of the wrong type', () async {
      httpClient.stub({
        'vectors': [
          {'key': 'a', 'distance': 'far'},
        ],
      });

      await expectLater(
        () => vectors
            .from('embeddings')
            .index('documents')
            .queryVectors(queryVector: [0.1, 0.2]),
        throwsFormatExceptionNaming('distance'),
      );
    });

    test('getVectors names an element of the wrong type', () async {
      httpClient.stub({
        'vectors': [
          {
            'key': 'a',
            'data': {
              'float32': [0.1, 'b'],
            },
          },
        ],
      });

      await expectLater(
        () => vectors
            .from('embeddings')
            .index('documents')
            .getVectors(keys: ['a'], returnData: true),
        throwsFormatExceptionNaming('float32'),
      );
    });
  });
}
