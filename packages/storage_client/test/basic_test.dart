import 'dart:io';
import 'dart:typed_data';

import 'package:storage_client/storage_client.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';

const String supabaseUrl = 'SUPABASE_TEST_URL';
const String supabaseKey = 'SUPABASE_TEST_KEY';

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
  late CustomHttpClient customHttpClient = CustomHttpClient();
  tearDown(() {
    final file = File('a.txt');
    if (file.existsSync()) file.deleteSync();
    customHttpClient.receivedRequests.clear();
  });

  group('Client with custom http client', () {
    setUp(() {
      // init SupabaseClient with test url & test key
      client = SupabaseStorageClient(
        '$supabaseUrl/storage/v1',
        {
          'Authorization': 'Bearer $supabaseKey',
        },
        httpClient: customHttpClient,
      );
    });

    test('should list buckets', () async {
      customHttpClient.response = [testBucketJson, testBucketJson];

      final response = await client.listBuckets();
      expect(response, isA<List<Bucket>>());
    });

    test('should create bucket', () async {
      const testBucketId = 'test_bucket';

      customHttpClient.response = {'name': 'test_bucket'};

      final response = await client.createBucket(testBucketId);
      expect(response, isA<String>());
      expect(response, 'test_bucket');
    });

    test('should get bucket', () async {
      const testBucketId = 'test_bucket';

      customHttpClient.response = testBucketJson;

      final response = await client.getBucket(testBucketId);
      expect(response, isA<Bucket>());
      expect(response.id, testBucketId);
      expect(response.name, testBucketId);
    });

    test('should empty bucket', () async {
      const testBucketId = 'test_bucket';

      customHttpClient.response = {'message': 'Emptied'};

      final response = await client.emptyBucket(testBucketId);
      expect(response, 'Emptied');
    });

    test('should delete bucket', () async {
      const testBucketId = 'test_bucket';

      customHttpClient.response = {'message': 'Deleted'};

      final response = await client.deleteBucket(testBucketId);
      expect(response, 'Deleted');
    });

    test('should upload file', () async {
      final file = File('a.txt');
      file.writeAsStringSync('File content');

      customHttpClient.response = {'Key': 'public/a.txt'};

      final response = await client.from('public').upload('a.txt', file);
      expect(response, isA<String>());
      expect(response.endsWith('/a.txt'), isTrue);
    });

    test('should update file', () async {
      final file = File('a.txt');
      file.writeAsStringSync('Updated content');

      customHttpClient.response = {'Key': 'public/a.txt'};

      final response = await client.from('public').update('a.txt', file);
      expect(response, isA<String>());
      expect(response.endsWith('/a.txt'), isTrue);
    });

    test('should move file', () async {
      customHttpClient.response = {'message': 'Move'};

      final response = await client.from('public').move('a.txt', 'b.txt');
      expect(response, 'Move');
    });

    test('should createSignedUrl file', () async {
      customHttpClient.response = {'signedURL': 'url'};

      final response = await client.from('public').createSignedUrl('b.txt', 60);
      expect(response, isA<String>());
    });

    test('should list files', () async {
      customHttpClient.response = [testFileObjectJson, testFileObjectJson];

      final response = await client.from('public').list();
      expect(response, isA<List<FileObject>>());
      expect(response.length, 2);
    });

    test('should download public file', () async {
      final file = File('a.txt');
      file.writeAsStringSync('Updated content');

      customHttpClient.response = file.readAsBytesSync();

      final response = await client.from('public_bucket').download('b.txt');
      expect(response, isA<Uint8List>());
      expect(String.fromCharCodes(response), 'Updated content');
    });

    test('should download public file with query params', () async {
      final file = File('a.txt');
      file.writeAsStringSync('Updated content');

      customHttpClient.response = file.readAsBytesSync();

      final response = await client
          .from('public_bucket')
          .download('b.txt', queryParams: {'version': '1'});
      expect(response, isA<Uint8List>());
      expect(String.fromCharCodes(response), 'Updated content');

      expect(customHttpClient.receivedRequests.length, 1);

      final request = customHttpClient.receivedRequests.first;
      expect(request.url.queryParameters, {'version': '1'});
    });

    test('should get public URL of a path', () {
      final response = client.from('files').getPublicUrl('b.txt');
      expect(response, '$objectUrl/public/files/b.txt');
    });

    test('should remove file', () async {
      customHttpClient.response = [testFileObjectJson, testFileObjectJson];

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
        // `RetryHttpClient` will throw `SocketException` for the first two tries
        httpClient: RetryHttpClient(),
      );
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
      expect(response.endsWith('/a.txt'), isTrue);
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
      expect(response.endsWith('/a.txt'), isTrue);
    });

    test('should update file with few network failures', () async {
      final file = File('a.txt');
      file.writeAsStringSync('File content');

      final response = await client.from('public').update('a.txt', file);
      expect(response, isA<String>());
      expect(response.endsWith('/a.txt'), isTrue);
    });
    test('should update binary with few network failures', () async {
      final file = File('a.txt');
      file.writeAsStringSync('File content');

      final response = await client
          .from('public')
          .updateBinary('a.txt', file.readAsBytesSync());
      expect(response, isA<String>());
      expect(response.endsWith('/a.txt'), isTrue);
    });
  });

  group('Client with custom http client', () {
    setUp(() {
      // init SupabaseClient with test url & test key
      client = SupabaseStorageClient(
        '$supabaseUrl/storage/v1',
        {
          'Authorization': 'Bearer $supabaseKey',
        },
        httpClient: FailingHttpClient(),
      );
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

  group('URL Construction', () {
    test('should update legacy prod host to new host', () {
      const inputUrl = 'https://blah.supabase.co/storage/v1';
      const expectedUrl = 'https://blah.storage.supabase.co/v1';
      client = SupabaseStorageClient(inputUrl, {
        'Authorization': 'Bearer $supabaseKey',
      });
      expect(client.url, expectedUrl);
    });

    test('should update legacy staging host to new host', () {
      const inputUrl = 'https://blah.supabase.red/storage/v1';
      const expectedUrl = 'https://blah.storage.supabase.red/v1';
      client = SupabaseStorageClient(inputUrl, {
        'Authorization': 'Bearer $supabaseKey',
      });
      expect(client.url, expectedUrl);
    });

    test('should accept new host without modification', () {
      const inputUrl = 'https://blah.storage.supabase.co/v1';
      const expectedUrl = 'https://blah.storage.supabase.co/v1';
      client = SupabaseStorageClient(inputUrl, {
        'Authorization': 'Bearer $supabaseKey',
      });
      expect(client.url, expectedUrl);
    });

    test('should not modify non-platform hosts', () {
      const inputUrl = 'https://blah.supabase.co.example.com/storage/v1';
      const expectedUrl = 'https://blah.supabase.co.example.com/storage/v1';
      client = SupabaseStorageClient(inputUrl, {
        'Authorization': 'Bearer $supabaseKey',
      });
      expect(client.url, expectedUrl);
    });

    test('should support local host with port without modification', () {
      const inputUrl = 'http://localhost:1234/storage/v1';
      const expectedUrl = 'http://localhost:1234/storage/v1';
      client = SupabaseStorageClient(inputUrl, {
        'Authorization': 'Bearer $supabaseKey',
      });
      expect(client.url, expectedUrl);
    });

    test('should update legacy supabase.in host to new host', () {
      const inputUrl = 'https://blah.supabase.in/storage/v1';
      const expectedUrl = 'https://blah.storage.supabase.in/v1';
      client = SupabaseStorageClient(inputUrl, {
        'Authorization': 'Bearer $supabaseKey',
      });
      expect(client.url, expectedUrl);
    });
  });
}
