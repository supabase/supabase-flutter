import 'dart:io';

import 'package:mime/mime.dart';
import 'package:mocktail/mocktail.dart';
import "package:path/path.dart" show join;
import 'package:storage_client/src/types.dart';
import 'package:storage_client/storage_client.dart';
import 'package:test/test.dart';

const storageUrl = 'http://localhost:8000/storage/v1';
const storageKey =
    'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTYwMzk2ODgzNCwiZXhwIjoyNTUwNjUzNjM0LCJhdWQiOiIiLCJzdWIiOiIzMTdlYWRjZS02MzFhLTQ0MjktYTBiYi1mMTlhN2E1MTdiNGEiLCJSb2xlIjoicG9zdGdyZXMifQ.pZobPtp6gDcX0UbzMmG3FHSlg4m4Q-22tKtGWalOrNo';

final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
final newBucketName = 'my-new-bucket-$timestamp';

final uploadPath = 'testpath/file-${DateTime.now().toIso8601String()}.jpg';

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

    // Register default mock values (used by mocktail)
    registerFallbackValue(const FileOptions());
    registerFallbackValue(const FetchOptions());
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
    try {
      await storage.getBucket('not-exist-id');
      fail('Bucket that does not exist was found');
    } catch (error) {
      expect(error, isNotNull);
    }
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
    expect(response.public, true);
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
    expect(response, 'Successfully emptied');
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
      expect(response.token, isNotNull);
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
      try {
        await storage
            .from(newBucketName)
            .uploadToSignedUrl(response.path, response.token, file);
      } on StorageException catch (error) {
        expect(error.error, 'Duplicate');
        expect(error.message, 'The resource already exists');
        expect(error.statusCode, '409');
      }
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
      await downloadedFile.writeAsBytes(bytesArray);
      final size = await downloadedFile.length();
      final type = lookupMimeType(downloadedFile.path);
      expect(size, isPositive);
      expect(type, 'image/jpeg');
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
      await downloadedFile.writeAsBytes(bytesArray);
      final size = await downloadedFile.length();
      final type = lookupMimeType(
        downloadedFile.path,
        headerBytes: downloadedFile.readAsBytesSync(),
      );

      expect(size, isPositive);
      expect(type, 'image/jpeg');
    });

    test('will return the image as webp when the browser support it', () async {
      final storage = SupabaseStorageClient(storageUrl,
          {'Authorization': 'Bearer $storageKey', 'Accept': 'image/webp'});

      final bytesArray = await storage.from(newBucketName).download(
            uploadPath,
            transform: TransformOptions(
              width: 200,
              height: 200,
            ),
          );
      final downloadedFile =
          await File('${Directory.current.path}/webpimage').create();
      await downloadedFile.writeAsBytes(bytesArray);
      final size = await downloadedFile.length();
      final type = lookupMimeType(
        downloadedFile.path,
        headerBytes: downloadedFile.readAsBytesSync(),
      );

      expect(size, isPositive);
      expect(type, 'image/webp');
    });

    test('will return the original image format when format is origin',
        () async {
      final storage = SupabaseStorageClient(storageUrl,
          {'Authorization': 'Bearer $storageKey', 'Accept': 'image/webp'});

      final bytesArray = await storage.from(newBucketName).download(
            uploadPath,
            transform: TransformOptions(
              width: 200,
              height: 200,
              format: RequestImageFormat.origin,
            ),
          );
      final downloadedFile =
          await File('${Directory.current.path}/jpegimage').create();
      await downloadedFile.writeAsBytes(bytesArray);
      final size = await downloadedFile.length();
      final type = lookupMimeType(
        downloadedFile.path,
        headerBytes: downloadedFile.readAsBytesSync(),
      );

      expect(size, isPositive);
      expect(type, 'image/jpeg');
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
      expectLater(uploadFuture, throwsException);
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
      expectLater(uploadFuture, throwsException);
    });
  });

  group('file operations', () {
    test('copy', () async {
      final storage = SupabaseStorageClient(
          storageUrl, {'Authorization': 'Bearer $storageKey'});

      await storage.from(newBucketName).copy(uploadPath, "$uploadPath 2");
    });
  });
}
