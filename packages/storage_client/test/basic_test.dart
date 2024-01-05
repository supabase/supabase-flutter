import 'dart:io';
import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:storage_client/src/fetch.dart';
import 'package:storage_client/src/types.dart';
import 'package:storage_client/storage_client.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';

const String supabaseUrl = 'SUPABASE_TEST_URL';
const String supabaseKey = 'SUPABASE_TEST_KEY';

class MockFetch extends Mock implements Fetch {}

FileOptions get mockFileOptions => any<FileOptions>();

FetchOptions get mockFetchOptions => any<FetchOptions>(named: 'options');

Map<String, dynamic> get testBucketJson => {
      'id': 'test_bucket',
      'name': 'test_bucket',
      'owner': 'owner_id',
      'created_at': '',
      'updated_at': '',
      'public': false,
    };

Map<String, dynamic> get testFileObjectJson => {
      'name': 'test_bucket',
      'id': 'test_bucket',
      'bucket_id': 'public',
      'owner': 'owner_id',
      'updated_at': null,
      'created_at': null,
      'last_accessed_at': null,
      'buckets': testBucketJson
    };

String get bucketUrl => '$supabaseUrl/storage/v1/bucket';

String get objectUrl => '$supabaseUrl/storage/v1/object';

void main() {
  late SupabaseStorageClient client;

  group('Client with default http client', () {
    setUp(() {
      // init SupabaseClient with test url & test key
      client = SupabaseStorageClient('$supabaseUrl/storage/v1', {
        'Authorization': 'Bearer $supabaseKey',
      });

      // Use mocked version for `storageFetch`, to prevent actual http calls.
      storageFetch = MockFetch();

      // Register default mock values (used by mocktail)
      registerFallbackValue(const FileOptions());
      registerFallbackValue(const FetchOptions());
    });

    tearDown(() {
      final file = File('a.txt');
      if (file.existsSync()) file.deleteSync();
    });

    test('should list buckets', () async {
      when(() => storageFetch.get(bucketUrl, options: mockFetchOptions))
          .thenAnswer(
        (_) => Future.value([testBucketJson, testBucketJson]),
      );

      final response = await client.listBuckets();
      expect(response, isA<List<Bucket>>());
    });

    test('should create bucket', () async {
      const testBucketId = 'test_bucket';
      const requestBody = {
        'id': testBucketId,
        'name': testBucketId,
        'public': false
      };
      when(
        () => storageFetch.post(
          bucketUrl,
          requestBody,
          options: mockFetchOptions,
        ),
      ).thenAnswer(
        (_) => Future.value(
          {
            'name': 'test_bucket',
          },
        ),
      );

      final response = await client.createBucket(testBucketId);
      expect(response, isA<String>());
      expect(response, 'test_bucket');
    });

    test('should get bucket', () async {
      const testBucketId = 'test_bucket';
      when(
        () => storageFetch.get(
          '$bucketUrl/$testBucketId',
          options: mockFetchOptions,
        ),
      ).thenAnswer(
        (_) => Future.value(
          testBucketJson,
        ),
      );

      final response = await client.getBucket(testBucketId);
      expect(response, isA<Bucket>());
      expect(response.id, testBucketId);
      expect(response.name, testBucketId);
    });

    test('should empty bucket', () async {
      const testBucketId = 'test_bucket';
      when(
        () => storageFetch.post(
          '$bucketUrl/$testBucketId/empty',
          {},
          options: mockFetchOptions,
        ),
      ).thenAnswer(
        (_) => Future.value(
          {
            'message': 'Emptied',
          },
        ),
      );

      final response = await client.emptyBucket(testBucketId);
      expect(response, 'Emptied');
    });

    test('should delete bucket', () async {
      const testBucketId = 'test_bucket';
      when(
        () => storageFetch.delete(
          '$bucketUrl/$testBucketId',
          {},
          options: mockFetchOptions,
        ),
      ).thenAnswer(
        (_) => Future.value({'message': 'Deleted'}),
      );

      final response = await client.deleteBucket(testBucketId);
      expect(response, 'Deleted');
    });

    test('should upload file', () async {
      final file = File('a.txt');
      file.writeAsStringSync('File content');

      when(
        () => storageFetch.postFile(
          '$objectUrl/public/a.txt',
          file,
          mockFileOptions,
          options: mockFetchOptions,
          retryAttempts: 0,
          retryController: null,
        ),
      ).thenAnswer(
        (_) => Future.value({'Key': 'public/a.txt'}),
      );

      final response = await client.from('public').upload('a.txt', file);
      expect(response, isA<String>());
      expect(response.key.endsWith('/a.txt'), isTrue);
    });

    test('should update file', () async {
      final file = File('a.txt');
      file.writeAsStringSync('Updated content');

      when(
        () => storageFetch.putFile(
          '$objectUrl/public/a.txt',
          file,
          mockFileOptions,
          options: mockFetchOptions,
          retryAttempts: 0,
          retryController: null,
        ),
      ).thenAnswer(
        (_) => Future.value({'Key': 'public/a.txt'}),
      );

      final response = await client.from('public').update('a.txt', file);
      expect(response, isA<String>());
      expect(response.key.endsWith('/a.txt'), isTrue);
    });

    test('should move file', () async {
      const requestBody = {
        'bucketId': 'public',
        'sourceKey': 'a.txt',
        'destinationKey': 'b.txt',
      };
      when(
        () => storageFetch.post(
          '$objectUrl/move',
          requestBody,
          options: mockFetchOptions,
        ),
      ).thenAnswer(
        (_) => Future.value({'message': 'Move'}),
      );

      final response = await client.from('public').move('a.txt', 'b.txt');
      expect(response, 'Move');
    });

    test('should createSignedUrl file', () async {
      when(
        () => storageFetch.post(
          '$objectUrl/sign/public/b.txt',
          {'expiresIn': 60},
          options: mockFetchOptions,
        ),
      ).thenAnswer(
        (_) => Future.value({'signedURL': 'url'}),
      );

      final response = await client.from('public').createSignedUrl('b.txt', 60);
      expect(response, isA<String>());
    });

    test('should list files', () async {
      when(
        () => storageFetch.post(
          '$objectUrl/list/public',
          any(),
          options: mockFetchOptions,
        ),
      ).thenAnswer(
        (_) => Future.value(
          [testFileObjectJson, testFileObjectJson],
        ),
      );

      final response = await client.from('public').list();
      expect(response, isA<List<FileObject>>());
      expect(response.length, 2);
    });

    test('should download public file', () async {
      final file = File('a.txt');
      file.writeAsStringSync('Updated content');

      when(
        () => storageFetch.get(
          '$objectUrl/public_bucket/b.txt',
          options: mockFetchOptions,
        ),
      ).thenAnswer(
        (_) => Future.value(
          file.readAsBytesSync(),
        ),
      );

      final response = await client.from('public_bucket').download('b.txt');
      expect(response, isA<Uint8List>());
      expect(String.fromCharCodes(response), 'Updated content');
    });

    test('should get public URL of a path', () {
      final response = client.from('files').getPublicUrl('b.txt');
      expect(response, '$objectUrl/public/files/b.txt');
    });

    test('should remove file', () async {
      final requestBody = {
        'prefixes': ['a.txt', 'b.txt']
      };
      when(
        () => storageFetch.delete(
          '$objectUrl/public',
          requestBody,
          options: mockFetchOptions,
        ),
      ).thenAnswer(
        (_) => Future.value(
          [testFileObjectJson, testFileObjectJson],
        ),
      );

      final response = await client.from('public').remove(['a.txt', 'b.txt']);
      expect(response, isA<List>());
      expect(response.length, 2);
    });
  });

  group('Retry', () {
    setUp(() {
      // init SupabaseClient with test url & test key
      client = SupabaseStorageClient(
        '$supabaseUrl/storage/v1',
        {'Authorization': 'Bearer $supabaseKey'},
        retryAttempts: 5,
      );

      // `RetryHttpClient` will throw `SocketException` for the first two tries
      storageFetch = Fetch(RetryHttpClient());
    });

    test('Upload fails without retry', () async {
      final file = File('a.txt');
      file.writeAsStringSync('File content');

      final uploadTask =
          client.from('public').upload('a.txt', file, retryAttempts: 1);
      expect(uploadTask, throwsException);
    });

    test('should upload file with few network failures', () async {
      final file = File('a.txt');
      file.writeAsStringSync('File content');

      final response = await client.from('public').upload('a.txt', file);
      expect(response, isA<String>());
      expect(response.key.endsWith('/a.txt'), isTrue);
    });

    test('aborting upload should throw', () async {
      final file = File('a.txt');
      file.writeAsStringSync('File content');

      final retryController = StorageRetryController();

      final future = client.from('public').upload(
            'a.txt',
            file,
            retryController: retryController,
          );

      await Future.delayed(Duration(milliseconds: 500));
      retryController.cancel();

      expect(future, throwsException);
    });

    test('should upload binary with few network failures', () async {
      final file = File('a.txt');
      file.writeAsStringSync('File content');

      final response = await client
          .from('public')
          .uploadBinary('a.txt', file.readAsBytesSync());
      expect(response, isA<String>());
      expect(response.key.endsWith('/a.txt'), isTrue);
    });

    test('should update file with few network failures', () async {
      final file = File('a.txt');
      file.writeAsStringSync('File content');

      final response = await client.from('public').update('a.txt', file);
      expect(response, isA<String>());
      expect(response.key.endsWith('/a.txt'), isTrue);
    });
    test('should update binary with few network failures', () async {
      final file = File('a.txt');
      file.writeAsStringSync('File content');

      final response = await client
          .from('public')
          .updateBinary('a.txt', file.readAsBytesSync());
      expect(response, isA<String>());
      expect(response.key.endsWith('/a.txt'), isTrue);
    });
  });

  group('Client with custom http client', () {
    setUp(() {
      // init SupabaseClient with test url & test key
      client = SupabaseStorageClient('$supabaseUrl/storage/v1', {
        'Authorization': 'Bearer $supabaseKey',
      });
      storageFetch = Fetch(CustomHttpClient());
    });
    test('should list buckets', () async {
      try {
        await client.listBuckets();
      } catch (e) {
        expect((e as dynamic).statusCode, "420");
      }
    });
  });

  group('header', () {
    test('X-Client-Info header is set', () {
      client = SupabaseStorageClient(
        '$supabaseUrl/storage/v1',
        {
          'Authorization': 'Bearer $supabaseKey',
        },
      );

      expect(client.headers['X-Client-Info']!.split('/').first, 'storage-dart');
    });

    test('X-Client-Info header can be overridden', () {
      client = SupabaseStorageClient('$supabaseUrl/storage/v1', {
        'Authorization': 'Bearer $supabaseKey',
        'X-Client-Info': 'supabase-dart/0.0.0'
      });

      expect(client.headers['X-Client-Info'], 'supabase-dart/0.0.0');
    });
  });
}
