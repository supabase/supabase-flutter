import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';
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
  'buckets': testBucketJson,
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
      expect(customHttpClient.receivedRequests.last.url.query, isEmpty);
    });

    test('should list buckets without query params when no options', () async {
      customHttpClient.response = [testBucketJson];

      await client.listBuckets(const ListBucketsOptions());
      expect(customHttpClient.receivedRequests.last.url.query, isEmpty);
    });

    test(
      'should list buckets with filter, sort and pagination options',
      () async {
        customHttpClient.response = [testBucketJson];

        await client.listBuckets(
          const ListBucketsOptions(
            limit: 10,
            offset: 5,
            search: 'prod',
            sortColumn: BucketSortColumn.createdAt,
            sortOrder: BucketSortOrder.descending,
          ),
        );

        final queryParameters =
            customHttpClient.receivedRequests.last.url.queryParameters;
        expect(queryParameters['limit'], '10');
        expect(queryParameters['offset'], '5');
        expect(queryParameters['search'], 'prod');
        expect(queryParameters['sortColumn'], 'created_at');
        expect(queryParameters['sortOrder'], 'desc');
      },
    );

    test('should include limit and offset of zero', () async {
      customHttpClient.response = [testBucketJson];

      await client.listBuckets(
        const ListBucketsOptions(limit: 0, offset: 0),
      );

      final queryParameters =
          customHttpClient.receivedRequests.last.url.queryParameters;
      expect(queryParameters['limit'], '0');
      expect(queryParameters['offset'], '0');
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
      customHttpClient.response = {'signedURL': '/signed/url'};

      final response = await client.from('public').createSignedUrl('b.txt', 60);
      expect(response, isA<String>());
      expect(response, endsWith('/signed/url'));
    });

    test(
      'createSignedUrl throws StorageException when signedURL is null',
      () async {
        customHttpClient.response = {'signedURL': null};

        expect(
          () => client.from('public').createSignedUrl('missing.txt', 60),
          throwsA(isA<StorageException>()),
        );
      },
    );

    test(
      'createSignedUrlsResult returns success and failure for mixed paths',
      () async {
        customHttpClient.response = [
          {
            'path': 'exists.txt',
            'signedURL': '/storage/v1/object/sign/public/exists.txt?token=abc',
          },
          {
            'path': 'missing.txt',
            'signedURL': null,
            'error': 'not_found',
          },
        ];

        final results = await client.from('public').createSignedUrlsResult([
          'exists.txt',
          'missing.txt',
        ], 60);

        expect(results.length, 2);
        expect(results[0], isA<SignedUrlSuccess>());
        expect(results[1], isA<SignedUrlFailure>());

        final success = results[0] as SignedUrlSuccess;
        expect(success.path, 'exists.txt');
        expect(
          success.signedUrl,
          endsWith('/storage/v1/object/sign/public/exists.txt?token=abc'),
        );

        final failure = results[1] as SignedUrlFailure;
        expect(failure.path, 'missing.txt');
        expect(failure.error, 'not_found');
      },
    );

    // ignore: deprecated_member_use_from_same_package
    test('createSignedUrls (deprecated) omits missing paths', () async {
      customHttpClient.response = [
        {
          'path': 'exists.txt',
          'signedURL': '/storage/v1/object/sign/public/exists.txt?token=abc',
        },
        {
          'path': 'missing.txt',
          'signedURL': null,
          'error': 'not_found',
        },
      ];

      // ignore: deprecated_member_use_from_same_package
      final urls = await client.from('public').createSignedUrls([
        'exists.txt',
        'missing.txt',
      ], 60);

      expect(urls.length, 1);
      expect(urls[0].path, 'exists.txt');
      expect(
        urls[0].signedUrl,
        endsWith('/storage/v1/object/sign/public/exists.txt?token=abc'),
      );
    });

    test('createSignedUploadUrl omits x-upsert by default', () async {
      customHttpClient.response = {
        'url': '/object/upload/sign/public/a.txt?token=xyz',
      };

      await client.from('public').createSignedUploadUrl('a.txt');

      final request = customHttpClient.receivedRequests.single;
      expect(request.headers.containsKey('x-upsert'), isFalse);
    });

    test('createSignedUploadUrl sends x-upsert when upserting', () async {
      customHttpClient.response = {
        'url': '/object/upload/sign/public/a.txt?token=xyz',
      };

      final response = await client
          .from('public')
          .createSignedUploadUrl('a.txt', upsert: true);

      expect(response.token, 'xyz');

      final request = customHttpClient.receivedRequests.single;
      expect(request.headers['x-upsert'], 'true');
    });

    test('should list files', () async {
      customHttpClient.response = [testFileObjectJson, testFileObjectJson];

      final response = await client.from('public').list();
      expect(response, isA<List<FileObject>>());
      expect(response.length, 2);
    });

    test('listPaginated posts options and parses the result', () async {
      customHttpClient.response = {
        'hasNext': true,
        'nextCursor': 'cursor-2',
        'folders': [
          {'name': 'folder', 'key': 'prefix/folder/'},
        ],
        'objects': [
          {
            'name': 'image.png',
            'key': 'prefix/image.png',
            'id': 'object-id',
            'updated_at': '2026-01-01T00:00:00Z',
            'created_at': '2026-01-01T00:00:00Z',
            'metadata': {'size': 10},
          },
        ],
      };

      final result = await client
          .from('public')
          .listPaginated(
            options: const PaginatedSearchOptions(
              prefix: 'prefix/',
              limit: 100,
              withDelimiter: true,
              sortBy: FileSort(
                column: FileSortColumn.createdAt,
                order: FileSortOrder.descending,
              ),
            ),
          );

      final request = customHttpClient.receivedRequests.single;
      expect(request.url.toString(), '$objectUrl/list-v2/public');
      expect(jsonDecode((request as Request).body), {
        'prefix': 'prefix/',
        'limit': 100,
        'with_delimiter': true,
        'sortBy': {'column': 'created_at', 'order': 'desc'},
      });

      expect(result.hasNext, isTrue);
      expect(result.nextCursor, 'cursor-2');
      expect(result.folders.single.name, 'folder');
      expect(result.folders.single.key, 'prefix/folder/');
      expect(result.objects.single.name, 'image.png');
      expect(result.objects.single.id, 'object-id');
      expect(result.objects.single.metadata, {'size': 10});
    });

    test('listPaginated defaults to an empty body and empty result', () async {
      customHttpClient.response = {
        'hasNext': false,
        'objects': <dynamic>[],
      };

      final result = await client.from('public').listPaginated();

      final request = customHttpClient.receivedRequests.single as Request;
      expect(jsonDecode(request.body), <String, dynamic>{});
      expect(result.hasNext, isFalse);
      expect(result.folders, isEmpty);
      expect(result.objects, isEmpty);
      expect(result.nextCursor, isNull);
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

    test('downloadStream yields the response body as a byte stream', () async {
      final file = File('a.txt');
      file.writeAsStringSync('Streamed content');
      customHttpClient.response = file.readAsBytesSync();

      final stream = client.from('public_bucket').downloadStream('b.txt');
      expect(stream, isA<Stream<Uint8List>>());
      final bytes = await stream.expand((chunk) => chunk).toList();

      expect(String.fromCharCodes(bytes), 'Streamed content');

      final request = customHttpClient.receivedRequests.single;
      expect(request.url.toString(), contains('/object/public_bucket/b.txt'));
    });

    test('downloadStream appends transform and cacheNonce', () async {
      customHttpClient.response = Uint8List.fromList([1, 2, 3]);

      await client
          .from('public_bucket')
          .downloadStream(
            'b.txt',
            transform: const TransformOptions(width: 200),
            cacheNonce: 'v2',
          )
          .drain<void>();

      final request = customHttpClient.receivedRequests.single;
      expect(
        request.url.toString(),
        contains('/render/image/authenticated/public_bucket/b.txt'),
      );
      expect(request.url.queryParameters, {'width': '200', 'cacheNonce': 'v2'});
    });

    test('downloadStream surfaces an error status on the stream', () async {
      addTearDown(() => customHttpClient.statusCode = 201);
      customHttpClient.statusCode = 404;
      customHttpClient.response = {'message': 'Object not found'};

      await expectLater(
        client
            .from('public_bucket')
            .downloadStream('missing.txt')
            .drain<void>(),
        throwsA(
          isA<StorageException>().having(
            (e) => e.statusCode,
            'statusCode',
            '404',
          ),
        ),
      );
    });

    test('should get public URL of a path', () {
      final response = client.from('files').getPublicUrl('b.txt');
      expect(response, '$objectUrl/public/files/b.txt');
    });

    test('getPublicUrl appends download with the original file name', () {
      final response = client
          .from('files')
          .getPublicUrl(
            'b.txt',
            download: DownloadBehavior.withOriginalName,
          );
      expect(response, '$objectUrl/public/files/b.txt?download=');
    });

    test('getPublicUrl appends download with a custom file name', () {
      final response = client
          .from('files')
          .getPublicUrl(
            'b.txt',
            download: DownloadBehavior.named('my file.txt'),
          );
      expect(
        response,
        '$objectUrl/public/files/b.txt?download=my+file.txt',
      );
    });

    test('getPublicUrl leaves the URL unchanged when download is null', () {
      final response = client.from('files').getPublicUrl('b.txt');
      expect(response, '$objectUrl/public/files/b.txt');
    });

    test('getPublicUrl with empty transform does not use render endpoint', () {
      final response = client
          .from('files')
          .getPublicUrl('b.txt', transform: const TransformOptions());
      expect(response, '$objectUrl/public/files/b.txt');
      expect(response, isNot(contains('/render/image/')));
    });

    test('getPublicUrl with actual transform uses render endpoint', () {
      final response = client
          .from('files')
          .getPublicUrl('b.txt', transform: const TransformOptions(width: 200));
      expect(
        response,
        '$supabaseUrl/storage/v1/render/image/public/files/b.txt?width=200',
      );
    });

    test(
      'download with empty transform does not use render endpoint',
      () async {
        final file = File('a.txt');
        file.writeAsStringSync('Updated content');
        customHttpClient.response = file.readAsBytesSync();

        await client
            .from('public_bucket')
            .download('b.txt', transform: const TransformOptions());

        final request = customHttpClient.receivedRequests.first;
        expect(request.url.toString(), contains('/object/public_bucket/b.txt'));
        expect(request.url.toString(), isNot(contains('/render/image/')));
      },
    );

    test('download with actual transform uses render endpoint', () async {
      final file = File('a.txt');
      file.writeAsStringSync('Updated content');
      customHttpClient.response = file.readAsBytesSync();

      await client
          .from('public_bucket')
          .download('b.txt', transform: const TransformOptions(width: 200));

      final request = customHttpClient.receivedRequests.first;
      expect(
        request.url.toString(),
        contains('/render/image/authenticated/public_bucket/b.txt'),
      );
      expect(request.url.queryParameters, {'width': '200'});
    });

    test('createSignedUrl appends download to the token query', () async {
      customHttpClient.response = {
        'signedURL': '/object/sign/public/b.txt?token=abc',
      };

      final response = await client
          .from('public')
          .createSignedUrl(
            'b.txt',
            60,
            download: DownloadBehavior.named('report.pdf'),
          );
      expect(response, endsWith('?token=abc&download=report.pdf'));
    });

    test('createSignedUrlsResult appends download to each URL', () async {
      customHttpClient.response = [
        {
          'path': 'exists.txt',
          'signedURL': '/object/sign/public/exists.txt?token=abc',
        },
      ];

      final results = await client
          .from('public')
          .createSignedUrlsResult(
            ['exists.txt'],
            60,
            download: DownloadBehavior.withOriginalName,
          );

      final success = results.single as SignedUrlSuccess;
      expect(success.signedUrl, endsWith('?token=abc&download='));
    });

    test('getPublicUrl appends cacheNonce', () {
      final response = client
          .from('files')
          .getPublicUrl('b.txt', cacheNonce: 'v2');
      expect(response, '$objectUrl/public/files/b.txt?cacheNonce=v2');
    });

    test('getPublicUrl appends download before cacheNonce', () {
      final response = client
          .from('files')
          .getPublicUrl(
            'b.txt',
            download: DownloadBehavior.withOriginalName,
            cacheNonce: 'v2',
          );
      expect(response, '$objectUrl/public/files/b.txt?download=&cacheNonce=v2');
    });

    test('download appends cacheNonce query parameter', () async {
      final file = File('a.txt');
      file.writeAsStringSync('Updated content');
      customHttpClient.response = file.readAsBytesSync();

      await client.from('public_bucket').download('b.txt', cacheNonce: 'v2');

      final request = customHttpClient.receivedRequests.first;
      expect(request.url.queryParameters, {'cacheNonce': 'v2'});
    });

    test('createSignedUrl appends cacheNonce to the token query', () async {
      customHttpClient.response = {
        'signedURL': '/object/sign/public/b.txt?token=abc',
      };

      final response = await client
          .from('public')
          .createSignedUrl('b.txt', 60, cacheNonce: 'v2');
      expect(response, endsWith('?token=abc&cacheNonce=v2'));
    });

    test('createSignedUrlsResult appends cacheNonce to each URL', () async {
      customHttpClient.response = [
        {
          'path': 'exists.txt',
          'signedURL': '/object/sign/public/exists.txt?token=abc',
        },
      ];

      final results = await client
          .from('public')
          .createSignedUrlsResult(['exists.txt'], 60, cacheNonce: 'v2');

      final success = results.single as SignedUrlSuccess;
      expect(success.signedUrl, endsWith('?token=abc&cacheNonce=v2'));
    });

    test('should remove file', () async {
      customHttpClient.response = [testFileObjectJson, testFileObjectJson];

      final response = await client.from('public').remove(['a.txt', 'b.txt']);
      expect(response, isA<List<dynamic>>());
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

      final uploadTask = client
          .from('public')
          .upload('a.txt', file, retryAttempts: 1);
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

      final future = client
          .from('public')
          .upload(
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
      await expectLater(
        () => client.listBuckets(),
        throwsA(
          isA<StorageException>().having(
            (e) => e.statusCode,
            'statusCode',
            '420',
          ),
        ),
      );
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
        'X-Client-Info': 'supabase-dart/0.0.0',
      });

      expect(client.headers['X-Client-Info'], 'supabase-dart/0.0.0');
    });
  });

  group('URL Construction', () {
    group('default behavior (useNewHostname: false)', () {
      test('should NOT transform legacy prod host by default', () {
        const inputUrl = 'https://blah.supabase.co/storage/v1';
        client = SupabaseStorageClient(inputUrl, {
          'Authorization': 'Bearer $supabaseKey',
        });
        expect(client.url, inputUrl);
      });

      test('should NOT transform legacy staging host by default', () {
        const inputUrl = 'https://blah.supabase.red/storage/v1';
        client = SupabaseStorageClient(inputUrl, {
          'Authorization': 'Bearer $supabaseKey',
        });
        expect(client.url, inputUrl);
      });

      test('should NOT transform legacy supabase.in host by default', () {
        const inputUrl = 'https://blah.supabase.in/storage/v1';
        client = SupabaseStorageClient(inputUrl, {
          'Authorization': 'Bearer $supabaseKey',
        });
        expect(client.url, inputUrl);
      });

      test('should accept new host without modification', () {
        const inputUrl = 'https://blah.storage.supabase.co/v1';
        client = SupabaseStorageClient(inputUrl, {
          'Authorization': 'Bearer $supabaseKey',
        });
        expect(client.url, inputUrl);
      });

      test('should not modify non-platform hosts', () {
        const inputUrl = 'https://blah.supabase.co.example.com/storage/v1';
        client = SupabaseStorageClient(inputUrl, {
          'Authorization': 'Bearer $supabaseKey',
        });
        expect(client.url, inputUrl);
      });

      test('should support local host with port without modification', () {
        const inputUrl = 'http://localhost:1234/storage/v1';
        client = SupabaseStorageClient(inputUrl, {
          'Authorization': 'Bearer $supabaseKey',
        });
        expect(client.url, inputUrl);
      });
    });

    group('opt-in behavior (useNewHostname: true)', () {
      test('should update legacy prod host to new host', () {
        const inputUrl = 'https://blah.supabase.co/storage/v1';
        const expectedUrl = 'https://blah.storage.supabase.co/v1';
        client = SupabaseStorageClient(inputUrl, {
          'Authorization': 'Bearer $supabaseKey',
        }, useNewHostname: true);
        expect(client.url, expectedUrl);
      });

      test('should update legacy staging host to new host', () {
        const inputUrl = 'https://blah.supabase.red/storage/v1';
        const expectedUrl = 'https://blah.storage.supabase.red/v1';
        client = SupabaseStorageClient(inputUrl, {
          'Authorization': 'Bearer $supabaseKey',
        }, useNewHostname: true);
        expect(client.url, expectedUrl);
      });

      test('should accept new host without modification', () {
        const inputUrl = 'https://blah.storage.supabase.co/v1';
        const expectedUrl = 'https://blah.storage.supabase.co/v1';
        client = SupabaseStorageClient(inputUrl, {
          'Authorization': 'Bearer $supabaseKey',
        }, useNewHostname: true);
        expect(client.url, expectedUrl);
      });

      test('should not modify non-platform hosts', () {
        const inputUrl = 'https://blah.supabase.co.example.com/storage/v1';
        const expectedUrl = 'https://blah.supabase.co.example.com/storage/v1';
        client = SupabaseStorageClient(inputUrl, {
          'Authorization': 'Bearer $supabaseKey',
        }, useNewHostname: true);
        expect(client.url, expectedUrl);
      });

      test('should support local host with port without modification', () {
        const inputUrl = 'http://localhost:1234/storage/v1';
        const expectedUrl = 'http://localhost:1234/storage/v1';
        client = SupabaseStorageClient(inputUrl, {
          'Authorization': 'Bearer $supabaseKey',
        }, useNewHostname: true);
        expect(client.url, expectedUrl);
      });

      test('should update legacy supabase.in host to new host', () {
        const inputUrl = 'https://blah.supabase.in/storage/v1';
        const expectedUrl = 'https://blah.storage.supabase.in/v1';
        client = SupabaseStorageClient(inputUrl, {
          'Authorization': 'Bearer $supabaseKey',
        }, useNewHostname: true);
        expect(client.url, expectedUrl);
      });
    });
  });
}
