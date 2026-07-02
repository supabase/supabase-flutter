import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import "package:path/path.dart" show join;
import 'package:storage_client/storage_client.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';

const storageUrl = 'http://127.0.0.1:54421/storage/v1';
// service_role key of the local Supabase CLI stack (RS256, signed by the committed
// supabase/signing_keys.json). It bypasses RLS so the tests have unrestricted
// access, matching the previous Docker setup.
const storageKey =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6IjNkZjU5YWIxLWI4ZWMtNDlkMy05YzkyLThiOWQ0MmNhYzFmZSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MjA5Njg5NTE5Mn0.jO5vwkRNFZTiVHNjFzaypvWV4aJkKm6TvFsdl0W5x9g7LttQMWMopC7HanUpeFLmg4E9gMb-v1e6f6oZ9e0PHYpsRwEdSOxKfYwKhzFI9DsDGLrX4ueArZuKgaV_bulWpwGKI3xwLugeuCp6N0hYFkXvMmUjaKx9nClWckJ33cchSpgjVQ5YxL8PGrUj2Sjhw-5IyGiwrdPfWjTQmpWnCjePoVrRf2jEMF_VGoxDAEqt72w_HGOrdXRFU5BW9-LkvpfzkrTENrj555JtYP4mkZgvUlrkXFRSh010o3n2UehN5WonfDRzwOeTC56QEbPVS6ubvWGR9luykdMNlXawZA';

final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
final newBucketName = 'my-new-bucket-$timestamp';

final uploadPath = 'testpath/file-${DateTime.now().toIso8601String()}.jpg';

// These tests run against the buckets seeded by supabase/seed.sql and create
// additional buckets as they go, so they are order-dependent and not idempotent
// (for example "List buckets" expects exactly the four seeded buckets). They
// assume a freshly started stack; in CI each job starts Supabase from scratch.
void main() {
  late SupabaseStorageClient storage;

  late File file;

  Future<String> findOrCreateBucket(String name, [bool isPublic = true]) async {
    try {
      await storage.getBucket(name);
    } catch (error) {
      await storage.createBucket(name, BucketOptions(public: isPublic));
    }
    return name;
  }

  setUp(() async {
    // init SupabaseClient with test url & test key
    storage = SupabaseStorageClient(storageUrl, {
      'Authorization': 'Bearer $storageKey',
    });

    file = File(join(
        Directory.current.path, 'test', 'fixtures', 'upload', 'sadcat.jpg'));
  });

  test('List files', () async {
    final response = await storage.from('bucket2').list(path: 'public');
    expect(response.length, 2);
  });

  test('List buckets', () async {
    final response = await storage.listBuckets();
    expect(response.length, 4);
  });

  test('Get bucket by id', () async {
    final response = await storage.getBucket('bucket2');
    expect(response.name, 'bucket2');
  });

  test('Get bucket with wrong id', () async {
    await expectLater(
      () => storage.getBucket('not-exist-id'),
      throwsA(isNotNull),
    );
  });

  test('Create new bucket', () async {
    final response = await storage.createBucket(newBucketName);
    expect(response, newBucketName);
  });
  test('createSignedUrls does not throw', () async {
    await storage.from(newBucketName).upload(uploadPath, file);
    await storage.from(newBucketName).createSignedUrls([uploadPath], 2000);
  });

  test('Create new public bucket', () async {
    const newPublicBucketName = 'my-new-public-bucket';
    await storage.createBucket(
      newPublicBucketName,
      const BucketOptions(public: true),
    );
    final response = await storage.getBucket(newPublicBucketName);
    expect(response.public, isTrue);
    expect(response.name, newPublicBucketName);
  });

  test('update bucket', () async {
    final newBucketName = 'my-new-bucket-${DateTime.now()}';
    await storage.createBucket(newBucketName);

    final updateRes = await storage.updateBucket(
      newBucketName,
      const BucketOptions(
        public: true,
        fileSizeLimit: '20mb', // 20 mb
        allowedMimeTypes: ['image/jpeg'],
      ),
    );
    expect(updateRes, 'Successfully updated');

    final getRes = await storage.getBucket(newBucketName);
    expect(getRes.public, isTrue);
    expect(getRes.fileSizeLimit, 20000000);
    expect(getRes.allowedMimeTypes!.length, 1);
    expect(getRes.allowedMimeTypes!.first, 'image/jpeg');
  });

  test('partially update bucket', () async {
    final newBucketName = 'my-new-bucket-${DateTime.now()}';
    await storage.createBucket(
      newBucketName,
      const BucketOptions(
        public: true,
        fileSizeLimit: '20mb', // 20 mb
        allowedMimeTypes: ['image/jpeg'],
      ),
    );
    final updateRes = await storage.updateBucket(
        newBucketName, const BucketOptions(public: false));
    expect(updateRes, 'Successfully updated');
    final getRes = await storage.getBucket(newBucketName);
    expect(getRes.public, isFalse);
    expect(getRes.fileSizeLimit, 20000000);
    expect(getRes.allowedMimeTypes!.length, 1);
    expect(getRes.allowedMimeTypes!.first, 'image/jpeg');
  });

  test('Empty bucket', () async {
    final response = await storage.emptyBucket(newBucketName);
    expect(response,
        'Empty bucket has been queued. Completion may take up to an hour.');
  });

  test('Delete bucket', () async {
    final response = await storage.deleteBucket(newBucketName);
    expect(response, 'Successfully deleted');
  });

  group('Signed upload URL', () {
    setUpAll(() async {
      await findOrCreateBucket(newBucketName);
    });

    tearDown(() async {
      await storage.emptyBucket(newBucketName);
    });

    tearDownAll(() async {
      await storage.deleteBucket(newBucketName);
    });

    test('sign url for upload', () async {
      final response =
          await storage.from(newBucketName).createSignedUploadUrl(uploadPath);

      expect(response.path, uploadPath);
      expect(response.token, isNotEmpty);
      expect(
          response.signedUrl,
          contains(
            '$storageUrl/object/upload/sign/$newBucketName/$uploadPath',
          ));
    });

    test('can upload with a signed url', () async {
      final response =
          await storage.from(newBucketName).createSignedUploadUrl(uploadPath);

      final uploadedPath = await storage
          .from(newBucketName)
          .uploadToSignedUrl(response.path, response.token, file);

      expect(uploadedPath, uploadPath);
    });

    test('can upload a binary file with a signed url', () async {
      final response =
          await storage.from(newBucketName).createSignedUploadUrl(uploadPath);

      final uploadedPath = await storage
          .from(newBucketName)
          .uploadBinaryToSignedUrl(
              response.path, response.token, file.readAsBytesSync());

      expect(uploadedPath, uploadPath);
    });

    test('cannot upload to a signed url twice', () async {
      final response =
          await storage.from(newBucketName).createSignedUploadUrl(uploadPath);

      final uploadedPath = await storage
          .from(newBucketName)
          .uploadToSignedUrl(response.path, response.token, file);

      expect(uploadedPath, uploadPath);
      await expectLater(
        () => storage
            .from(newBucketName)
            .uploadToSignedUrl(response.path, response.token, file),
        throwsA(isA<StorageException>()
            .having((e) => e.error, 'error', 'Duplicate')
            .having((e) => e.message, 'message', 'The resource already exists')
            .having((e) => e.statusCode, 'statusCode', '409')),
      );
    });
  });

  group('Transformations', () {
    setUpAll(() async {
      await findOrCreateBucket(newBucketName);
      await storage.from(newBucketName).upload(uploadPath, file);
    });

    test('sign url with transform options', () async {
      final url =
          await storage.from(newBucketName).createSignedUrl(uploadPath, 2000,
              transform: TransformOptions(
                width: 100,
                height: 100,
              ));

      expect(
          url.contains(
              '$storageUrl/render/image/sign/$newBucketName/$uploadPath'),
          isTrue);
    });

    test('gets public url with transformation options', () async {
      final url = storage.from(newBucketName).getPublicUrl(uploadPath,
          transform: TransformOptions(width: 200, height: 300, quality: 60));

      expect(url,
          '$storageUrl/render/image/public/$newBucketName/$uploadPath?width=200&height=300&quality=60');
    });

    test('will download a public transformed file', () async {
      final bytesArray = await storage.from(newBucketName).download(uploadPath,
          transform: TransformOptions(
            width: 200,
            height: 200,
          ));

      final downloadedFile =
          await File('${Directory.current.path}/public-image.jpg').create();
      try {
        await downloadedFile.writeAsBytes(bytesArray);
        final size = await downloadedFile.length();
        final type = lookupMimeType(downloadedFile.path);
        expect(size, isPositive);
        expect(type, 'image/jpeg');
      } finally {
        await downloadedFile.delete();
      }
    });

    test('will download an authenticated transformed file', () async {
      const privateBucketName = 'my-private-bucket';
      await findOrCreateBucket(privateBucketName);

      await storage.from(privateBucketName).upload(uploadPath, file);

      final bytesArray = await storage.from(privateBucketName).download(
          uploadPath,
          transform: TransformOptions(width: 200, height: 200));

      final downloadedFile =
          await File('${Directory.current.path}/private-image.jpg').create();
      try {
        await downloadedFile.writeAsBytes(bytesArray);
        final size = await downloadedFile.length();
        final type = lookupMimeType(
          downloadedFile.path,
          headerBytes: downloadedFile.readAsBytesSync(),
        );

        expect(size, isPositive);
        expect(type, 'image/jpeg');
      } finally {
        await downloadedFile.delete();
      }
    });

    test('will return the image as webp when the browser support it', () async {
      final client = SupabaseStorageClient(storageUrl,
          {'Authorization': 'Bearer $storageKey', 'Accept': 'image/webp'});

      final bytesArray = await client.from(newBucketName).download(
            uploadPath,
            transform: TransformOptions(
              width: 200,
              height: 200,
            ),
          );
      final downloadedFile =
          await File('${Directory.current.path}/webpimage').create();
      try {
        await downloadedFile.writeAsBytes(bytesArray);
        final size = await downloadedFile.length();
        final type = lookupMimeType(
          downloadedFile.path,
          headerBytes: downloadedFile.readAsBytesSync(),
        );

        expect(size, isPositive);
        expect(type, 'image/webp');
      } finally {
        await downloadedFile.delete();
      }
    });

    test('will return the original image format when format is origin',
        () async {
      final client = SupabaseStorageClient(storageUrl,
          {'Authorization': 'Bearer $storageKey', 'Accept': 'image/webp'});

      final bytesArray = await client.from(newBucketName).download(
            uploadPath,
            transform: TransformOptions(
              width: 200,
              height: 200,
              format: RequestImageFormat.origin,
            ),
          );
      final downloadedFile =
          await File('${Directory.current.path}/jpegimage').create();
      try {
        await downloadedFile.writeAsBytes(bytesArray);
        final size = await downloadedFile.length();
        final type = lookupMimeType(
          downloadedFile.path,
          headerBytes: downloadedFile.readAsBytesSync(),
        );

        expect(size, isPositive);
        expect(type, 'image/jpeg');
      } finally {
        await downloadedFile.delete();
      }
    });
  });

  group('download option', () {
    const downloadBucket = 'my-download-bucket';

    setUp(() async {
      await findOrCreateBucket(downloadBucket, true);
      await storage.from(downloadBucket).upload(
            uploadPath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
    });

    test('public url download serves a Content-Disposition attachment',
        () async {
      final url = storage
          .from(downloadBucket)
          .getPublicUrl(uploadPath, download: 'renamed.jpg');

      final response = await http.get(Uri.parse(url));
      expect(response.statusCode, 200);
      final disposition = response.headers['content-disposition'];
      expect(disposition, contains('attachment'));
      expect(disposition, contains('renamed.jpg'));
    });

    test('signed url download serves a Content-Disposition attachment',
        () async {
      final url = await storage
          .from(downloadBucket)
          .createSignedUrl(uploadPath, 2000, download: true);

      final response = await http.get(Uri.parse(url));
      expect(response.statusCode, 200);
      expect(response.headers['content-disposition'], contains('attachment'));
    });
  });

  group('bucket limits', () {
    test('can upload a file within the file size limit', () async {
      final bucketName = 'with-limit-${DateTime.now()}';
      await storage.createBucket(
          bucketName,
          const BucketOptions(
            public: true,
            fileSizeLimit: '1mb', // 1mb
          ));

      final res = await storage.from(bucketName).upload(uploadPath, file);
      expect(res, isA<String>());
    });

    test('cannot upload a file that exceed the file size limit', () async {
      final bucketName = 'with-limit-${DateTime.now()}';
      await storage.createBucket(
          bucketName,
          const BucketOptions(
            public: true,
            fileSizeLimit: '1kb',
          ));

      final uploadFuture = storage.from(bucketName).upload(uploadPath, file);
      await expectLater(uploadFuture, throwsException);
    });

    test('can upload a file with a valid mime type', () async {
      final bucketName = 'with-limit-${DateTime.now()}';
      await storage.createBucket(
          bucketName,
          BucketOptions(
            public: true,
            allowedMimeTypes: ['image/png'],
          ));

      final res = await storage.from(bucketName).upload(uploadPath, file,
          fileOptions: FileOptions(
            contentType: 'image/png',
          ));
      expect(res, isA<String>());
    });

    test('cannot upload a file an invalid mime type', () async {
      final bucketName = 'with-limit-${DateTime.now()}';
      await storage.createBucket(
          bucketName,
          const BucketOptions(
            public: true,
            allowedMimeTypes: ['image/png'],
          ));

      final uploadFuture = storage.from(bucketName).upload(uploadPath, file,
          fileOptions: FileOptions(
            contentType: 'image/jpeg',
          ));
      await expectLater(uploadFuture, throwsException);
    });
  });

  group('file operations', () {
    test('copy', () async {
      final client = SupabaseStorageClient(
          storageUrl, {'Authorization': 'Bearer $storageKey'});

      await client.from(newBucketName).copy(uploadPath, "$uploadPath 2");
    });

    test('copy to different bucket', () async {
      final client = SupabaseStorageClient(
          storageUrl, {'Authorization': 'Bearer $storageKey'});

      await expectLater(
        () => client.from('bucket2').download(uploadPath),
        throwsA(isA<StorageException>()
            .having((e) => e.statusCode, 'statusCode', '400')),
      );
      await client
          .from(newBucketName)
          .copy(uploadPath, uploadPath, destinationBucket: 'bucket2');
      try {
        await client.from('bucket2').download(uploadPath);
      } catch (error) {
        fail('File that was copied was not found');
      }
    });

    test('move to different bucket', () async {
      final client = SupabaseStorageClient(
          storageUrl, {'Authorization': 'Bearer $storageKey'});

      await expectLater(
        () => client.from('bucket2').download('$uploadPath 3'),
        throwsA(isA<StorageException>()
            .having((e) => e.statusCode, 'statusCode', '400')),
      );
      await client
          .from(newBucketName)
          .move(uploadPath, '$uploadPath 3', destinationBucket: 'bucket2');
      try {
        await client.from('bucket2').download('$uploadPath 3');
      } catch (error) {
        fail('File that was moved was not found');
      }
      await expectLater(
        () => client.from(newBucketName).download(uploadPath),
        throwsA(isA<StorageException>()
            .having((e) => e.statusCode, 'statusCode', '400')),
      );
    });
  });

  test('upload with custom metadata', () async {
    final metadata = {
      'custom': 'metadata',
      'second': 'second',
      'third': 'third',
    };
    final path = "$uploadPath-metadata";
    await storage.from(newBucketName).upload(
          path,
          file,
          fileOptions: FileOptions(
            metadata: metadata,
          ),
        );

    final updateRes = await storage.from(newBucketName).info(path);
    expect(updateRes.metadata, metadata);
  });

  test('check if object exists', () async {
    await storage.from(newBucketName).upload('$uploadPath-exists', file);
    final res = await storage.from(newBucketName).exists('$uploadPath-exists');
    expect(res, isTrue);

    final res2 = await storage.from(newBucketName).exists('not-exist');
    expect(res2, isFalse);
  });

  group('setHeader', () {
    late CustomHttpClient customHttpClient;
    late SupabaseStorageClient client;

    setUp(() {
      customHttpClient = CustomHttpClient();
      client = SupabaseStorageClient(
        storageUrl,
        {'Authorization': 'Bearer $storageKey'},
        httpClient: customHttpClient,
      );
    });

    test('sets custom header on storage client', () async {
      customHttpClient.response = [];
      customHttpClient.statusCode = 200;

      client.setHeader('x-custom-header', 'custom-value');
      await client.listBuckets();

      expect(customHttpClient.receivedRequests.length, 1);
      expect(
        customHttpClient.receivedRequests.first.headers['x-custom-header'],
        'custom-value',
      );
    });

    test('returns this for method chaining', () {
      final result = client.setHeader('x-header-a', 'value-a');
      expect(identical(result, client), isTrue);
    });

    test('supports chaining multiple setHeader calls', () async {
      customHttpClient.response = [];
      customHttpClient.statusCode = 200;

      client
          .setHeader('x-header-a', 'value-a')
          .setHeader('x-header-b', 'value-b');
      await client.listBuckets();

      expect(customHttpClient.receivedRequests.length, 1);
      final headers = customHttpClient.receivedRequests.first.headers;
      expect(headers['x-header-a'], 'value-a');
      expect(headers['x-header-b'], 'value-b');
    });

    test('headers set on client are included in file operations', () async {
      customHttpClient.response = [];
      customHttpClient.statusCode = 200;

      client.setHeader('x-custom-header', 'custom-value');
      await client.from('test-bucket').list();

      expect(customHttpClient.receivedRequests.length, 1);
      expect(
        customHttpClient.receivedRequests.first.headers['x-custom-header'],
        'custom-value',
      );
    });

    test('setHeader on StorageFileApi sets header for that instance', () async {
      customHttpClient.response = [];
      customHttpClient.statusCode = 200;

      final fileApi = client.from('test-bucket');
      fileApi.setHeader('x-file-header', 'file-value');
      await fileApi.list();

      expect(customHttpClient.receivedRequests.length, 1);
      expect(
        customHttpClient.receivedRequests.first.headers['x-file-header'],
        'file-value',
      );
    });

    test(
        'setHeader on StorageFileApi does not affect other StorageFileApi instances',
        () async {
      customHttpClient.response = [];
      customHttpClient.statusCode = 200;

      final fileApi1 = client.from('bucket1');
      final fileApi2 = client.from('bucket2');

      fileApi1.setHeader('x-header', 'value1');

      await fileApi1.list();
      await fileApi2.list();

      expect(customHttpClient.receivedRequests.length, 2);
      expect(
        customHttpClient.receivedRequests[0].headers['x-header'],
        'value1',
      );
      // fileApi2 should not have the header set on fileApi1
      expect(
        customHttpClient.receivedRequests[1].headers['x-header'],
        isNull,
      );
    });

    test('setHeader on StorageFileApi returns this for chaining', () async {
      customHttpClient.response = [];
      customHttpClient.statusCode = 200;

      final fileApi = client.from('test-bucket');
      final result = fileApi.setHeader('x-header', 'value');

      expect(identical(result, fileApi), isTrue);
    });

    test('setHeader can override existing headers', () async {
      customHttpClient.response = [];
      customHttpClient.statusCode = 200;

      client.setHeader('Authorization', 'Bearer new-token');
      await client.listBuckets();

      expect(customHttpClient.receivedRequests.length, 1);
      expect(
        customHttpClient.receivedRequests.first.headers['Authorization'],
        'Bearer new-token',
      );
    });
  });

  group('Content-Type header handling', () {
    late CustomHttpClient customHttpClient;
    late SupabaseStorageClient client;

    setUp(() {
      customHttpClient = CustomHttpClient();
      client = SupabaseStorageClient(
        storageUrl,
        {'Authorization': 'Bearer $storageKey'},
        httpClient: customHttpClient,
      );
    });

    test('defaults to application/json for non-GET requests', () async {
      customHttpClient.response = {'message': 'Emptied'};
      customHttpClient.statusCode = 200;

      await client.emptyBucket('bucket1');

      expect(customHttpClient.receivedRequests.length, 1);
      expect(
        customHttpClient.receivedRequests.first.headers['content-type'],
        contains('application/json'),
      );
    });

    test('preserves custom Content-Type set via setHeader', () async {
      customHttpClient.response = {'message': 'Emptied'};
      customHttpClient.statusCode = 200;

      client.setHeader('Content-Type', 'application/octet-stream');
      await client.emptyBucket('bucket1');

      expect(customHttpClient.receivedRequests.length, 1);
      expect(
        customHttpClient.receivedRequests.first.headers['content-type'],
        startsWith('application/octet-stream'),
      );
    });

    test('does not mutate the stored headers map after a non-GET request',
        () async {
      customHttpClient.response = [];
      customHttpClient.statusCode = 200;

      final fileApi = client.from('test-bucket');
      final headersBefore = Map<String, String>.of(fileApi.headers);

      await fileApi.list();

      expect(fileApi.headers, equals(headersBefore));
    });
  });

  group('object keys with reserved URL characters', () {
    // The SDK percent-encodes each object key segment (see _getFinalPath). These
    // tests confirm the round-trip against a real server: the storage server
    // percent-decodes the path back to the literal key, so upload and download
    // address the same object. Without encoding a `?` or `#` in the key would be
    // parsed as the start of the query string or fragment and the SDK would
    // silently address the wrong object.
    late String bucket;

    setUp(() async {
      bucket = await findOrCreateBucket(
          'reserved-${DateTime.now().millisecondsSinceEpoch}');
    });

    // Valid storage keys that contain characters which are reserved in a URL
    // and therefore must be percent-encoded to address the correct object.
    final keys = [
      'folder/report?v=2 final.pdf',
      'folder/a+b,c@d=e.txt',
      'folder/amp&and;semi.txt',
      'folder/2026-06-30T11:23:31.jpg',
    ];

    for (final key in keys) {
      test('uploads and downloads "$key" as the same object', () async {
        await storage.from(bucket).upload(
              key,
              file,
              fileOptions: const FileOptions(upsert: true),
            );

        final downloaded = await storage.from(bucket).download(key);
        expect(downloaded, isNotEmpty);

        final folder = key.substring(0, key.indexOf('/'));
        final name = key.substring(key.indexOf('/') + 1);
        final listed = await storage.from(bucket).list(path: folder);
        expect(
          listed.map((object) => object.name),
          contains(name),
          reason: 'server must store the decoded key, not the encoded form',
        );
      });
    }

    // `#` and `%` are rejected by the storage server's key validation
    // regardless of encoding, so the SDK surfaces a StorageException rather
    // than silently addressing the wrong object.
    for (final invalidKey in ['folder/a#b.txt', 'folder/100%done.txt']) {
      test('rejects "$invalidKey" with an InvalidKey error', () async {
        await expectLater(
          () => storage.from(bucket).upload(
                invalidKey,
                file,
                fileOptions: const FileOptions(upsert: true),
              ),
          throwsA(isA<StorageException>()),
        );
      });
    }
  });

  group('list sortBy defaults', () {
    late CustomHttpClient customHttpClient;
    late SupabaseStorageClient client;

    setUp(() {
      customHttpClient = CustomHttpClient();
      client = SupabaseStorageClient(
        storageUrl,
        {'Authorization': 'Bearer $storageKey'},
        httpClient: customHttpClient,
      );
    });

    Map<String, dynamic> sentSortBy() {
      final request = customHttpClient.receivedRequests.first as http.Request;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return body['sortBy'] as Map<String, dynamic>;
    }

    test('fills in order when only column is provided', () async {
      customHttpClient.response = [];
      customHttpClient.statusCode = 200;

      await client.from('test-bucket').list(
            searchOptions: const SearchOptions(
              sortBy: SortBy(column: 'updated_at'),
            ),
          );

      expect(sentSortBy(), {'column': 'updated_at', 'order': 'asc'});
    });

    test('fills in column when only order is provided', () async {
      customHttpClient.response = [];
      customHttpClient.statusCode = 200;

      await client.from('test-bucket').list(
            searchOptions: const SearchOptions(
              sortBy: SortBy(order: 'desc'),
            ),
          );

      expect(sentSortBy(), {'column': 'name', 'order': 'desc'});
    });

    test('uses defaults when no options are provided', () async {
      customHttpClient.response = [];
      customHttpClient.statusCode = 200;

      await client.from('test-bucket').list();

      expect(sentSortBy(), {'column': 'name', 'order': 'asc'});
    });

    test('fills in fields passed explicitly as null', () async {
      customHttpClient.response = [];
      customHttpClient.statusCode = 200;

      await client.from('test-bucket').list(
            searchOptions: const SearchOptions(
              sortBy: SortBy(column: null, order: null),
            ),
          );

      expect(sentSortBy(), {'column': 'name', 'order': 'asc'});
    });

    test('preserves a complete sortBy', () async {
      customHttpClient.response = [];
      customHttpClient.statusCode = 200;

      await client.from('test-bucket').list(
            searchOptions: const SearchOptions(
              sortBy: SortBy(column: 'created_at', order: 'desc'),
            ),
          );

      expect(sentSortBy(), {'column': 'created_at', 'order': 'desc'});
    });
  });
}
