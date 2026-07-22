import 'package:storage_client/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('Bucket.fromJson', () {
    test('parses all fields', () {
      final bucket = Bucket.fromJson({
        'id': 'avatars',
        'name': 'avatars',
        'owner': 'owner-id',
        'created_at': '2021-01-01T00:00:00Z',
        'updated_at': '2021-01-02T00:00:00Z',
        'public': true,
        'file_size_limit': 1024,
        'allowed_mime_types': ['image/png', 'image/jpeg'],
      });

      expect(bucket.id, 'avatars');
      expect(bucket.owner, 'owner-id');
      expect(bucket.public, isTrue);
      expect(bucket.fileSizeLimit, 1024);
      expect(bucket.allowedMimeTypes, ['image/png', 'image/jpeg']);
    });

    test('defaults owner to empty string and null-ables when absent', () {
      final bucket = Bucket.fromJson({
        'id': 'avatars',
        'name': 'avatars',
        'created_at': '2021-01-01T00:00:00Z',
        'updated_at': '2021-01-02T00:00:00Z',
        'public': false,
      });

      expect(bucket.owner, '');
      expect(bucket.fileSizeLimit, isNull);
      expect(bucket.allowedMimeTypes, isNull);
    });

    test('treats a non-list allowed_mime_types as null', () {
      final bucket = Bucket.fromJson({
        'id': 'avatars',
        'name': 'avatars',
        'created_at': '2021-01-01T00:00:00Z',
        'updated_at': '2021-01-02T00:00:00Z',
        'public': false,
        'allowed_mime_types': 'image/png',
      });

      expect(bucket.allowedMimeTypes, isNull);
    });
  });

  group('FileObject.fromJson', () {
    test('parses a nested bucket', () {
      final file = FileObject.fromJson({
        'name': 'photo.png',
        'id': 'file-id',
        'bucket_id': 'avatars',
        'owner': 'owner-id',
        'metadata': {'size': 10},
        'buckets': {
          'id': 'avatars',
          'name': 'avatars',
          'created_at': '2021-01-01T00:00:00Z',
          'updated_at': '2021-01-02T00:00:00Z',
          'public': true,
        },
      });

      expect(file.name, 'photo.png');
      expect(file.bucketId, 'avatars');
      expect(file.buckets, isA<Bucket>());
      expect(file.buckets!.id, 'avatars');
    });

    test('leaves buckets null when the field is missing', () {
      final file = FileObject.fromJson({'name': 'photo.png'});
      expect(file.buckets, isNull);
    });

    test('throws a FormatException when the JSON is not an object', () {
      expect(
        () => FileObject.fromJson(['not', 'a', 'map']),
        throwsFormatException,
      );
    });
  });

  group('FileObjectV2.fromJson', () {
    test('parses all fields', () {
      final file = FileObjectV2.fromJson({
        'id': 'file-id',
        'version': 'v1',
        'name': 'photo.png',
        'bucket_id': 'avatars',
        'created_at': '2021-01-01T00:00:00Z',
        'size': 42,
        'content_type': 'image/png',
        'etag': 'abc',
        'metadata': {'foo': 'bar'},
      });

      expect(file.id, 'file-id');
      expect(file.version, 'v1');
      expect(file.size, 42);
      expect(file.contentType, 'image/png');
      expect(file.updatedAt, isNull);
    });
  });

  group('ListBucketsOptions.toQueryParameters', () {
    test('omits null values and empty search', () {
      const options = ListBucketsOptions(search: '');
      expect(options.toQueryParameters(), isEmpty);
    });

    test('serializes sort column to snake_case and order to its value', () {
      const options = ListBucketsOptions(
        limit: 10,
        offset: 5,
        search: 'photo',
        sortColumn: BucketSortColumn.createdAt,
        sortOrder: BucketSortOrder.descending,
      );

      expect(options.toQueryParameters(), {
        'limit': '10',
        'offset': '5',
        'search': 'photo',
        'sortColumn': 'created_at',
        'sortOrder': 'desc',
      });
    });
  });

  group('SearchOptions.toMap', () {
    test('uses default limit, offset and sortBy', () {
      const options = SearchOptions();
      expect(options.toMap(), {
        'limit': 100,
        'offset': 0,
        'sortBy': {'column': 'name', 'order': 'asc'},
        'search': null,
      });
    });
  });

  group('SortBy.toMap', () {
    test('falls back to defaults when column and order are null', () {
      const sortBy = SortBy(column: null, order: null);
      expect(sortBy.toMap(), {'column': 'name', 'order': 'asc'});
    });
  });

  group('FileSort.toMap', () {
    test('serializes column to snake_case and order to its value', () {
      const sort = FileSort(
        column: FileSortColumn.updatedAt,
        order: FileSortOrder.descending,
      );
      expect(sort.toMap(), {'column': 'updated_at', 'order': 'desc'});
    });
  });

  group('PaginatedSearchOptions.toMap', () {
    test('omits null values', () {
      const options = PaginatedSearchOptions(limit: 50, prefix: 'folder/');
      expect(options.toMap(), {'limit': 50, 'prefix': 'folder/'});
    });
  });

  group('PaginatedListResult.fromJson', () {
    test('parses folders and objects', () {
      final result = PaginatedListResult.fromJson({
        'hasNext': true,
        'nextCursor': 'cursor-1',
        'folders': [
          {'name': 'images', 'key': 'images/'},
        ],
        'objects': [
          {'name': 'photo.png', 'key': 'images/photo.png'},
        ],
      });

      expect(result.hasNext, isTrue);
      expect(result.nextCursor, 'cursor-1');
      expect(result.folders.single.name, 'images');
      expect(result.objects.single.name, 'photo.png');
    });

    test('defaults to an empty page when fields are missing', () {
      final result = PaginatedListResult.fromJson({});
      expect(result.hasNext, isFalse);
      expect(result.folders, isEmpty);
      expect(result.objects, isEmpty);
      expect(result.nextCursor, isNull);
    });
  });

  group('SignedUrl', () {
    const url = SignedUrl(path: 'a.png', signedUrl: 'https://x/a.png');

    test('toString includes path and url', () {
      expect(
        url.toString(),
        'SignedUrl(path: a.png, signedUrl: https://x/a.png)',
      );
    });

    test('value equality and hashCode', () {
      const same = SignedUrl(path: 'a.png', signedUrl: 'https://x/a.png');
      const differentPath = SignedUrl(
        path: 'b.png',
        signedUrl: 'https://x/a.png',
      );
      const differentUrl = SignedUrl(
        path: 'a.png',
        signedUrl: 'https://x/b.png',
      );

      expect(url, same);
      expect(url.hashCode, same.hashCode);
      expect(url, isNot(differentPath));
      expect(url, isNot(differentUrl));
      expect(identical(url, url), isTrue);
    });

    test('copyWith replaces only the given fields', () {
      expect(url.copyWith(path: 'c.png').path, 'c.png');
      expect(url.copyWith(path: 'c.png').signedUrl, url.signedUrl);
      expect(
        url.copyWith(signedUrl: 'https://x/c.png').signedUrl,
        'https://x/c.png',
      );
      expect(url.copyWith(signedUrl: 'https://x/c.png').path, url.path);
    });
  });

  group('SignedUrlResult', () {
    test('success exposes the url and a descriptive toString', () {
      const result = SignedUrlSuccess(path: 'a.png', signedUrl: 'https://x/a');
      expect(result, isA<SignedUrlResult>());
      expect(
        result.toString(),
        'SignedUrlSuccess(path: a.png, signedUrl: https://x/a)',
      );
    });

    test('failure exposes the error and a descriptive toString', () {
      const result = SignedUrlFailure(path: 'a.png', error: 'not found');
      expect(
        result.toString(),
        'SignedUrlFailure(path: a.png, error: not found)',
      );
    });

    test('can be matched exhaustively with a switch', () {
      const results = <SignedUrlResult>[
        SignedUrlSuccess(path: 'a.png', signedUrl: 'https://x/a'),
        SignedUrlFailure(path: 'b.png', error: 'missing'),
      ];

      final outcomes = results.map((result) {
        return switch (result) {
          SignedUrlSuccess(:final signedUrl) => 'ok:$signedUrl',
          SignedUrlFailure(:final error) => 'fail:$error',
        };
      }).toList();

      expect(outcomes, ['ok:https://x/a', 'fail:missing']);
    });
  });

  group('StorageException', () {
    test('toString includes message, status code and error', () {
      const exception = StorageException(
        'boom',
        statusCode: '500',
        error: 'server_error',
      );
      expect(
        exception.toString(),
        'StorageException(message: boom, statusCode: 500, error: server_error)',
      );
    });

    test('fromJson reads message, error and statusCode', () {
      final exception = StorageException.fromJson({
        'message': 'not found',
        'error': 'NotFound',
        'statusCode': 404,
      });
      expect(exception.message, 'not found');
      expect(exception.error, 'NotFound');
      expect(exception.statusCode, '404');
    });

    test(
      'fromJson falls back to the fallback status code and stringified body',
      () {
        final exception = StorageException.fromJson({'foo': 'bar'}, '400');
        expect(exception.message, "{foo: bar}");
        expect(exception.statusCode, '400');
      },
    );
  });

  group('TransformOptions.toQueryParams', () {
    test('omits null values and snake-cases the resize mode', () {
      const options = TransformOptions(
        width: 100,
        height: 200,
        resize: ResizeMode.cover,
        quality: 80,
        format: RequestImageFormat.origin,
      );

      expect(options.toQueryParams, {
        'width': '100',
        'height': '200',
        'resize': 'cover',
        'quality': '80',
        'format': 'origin',
      });
    });

    test('is empty when nothing is set', () {
      const options = TransformOptions();
      expect(options.toQueryParams, isEmpty);
    });
  });

  group('DownloadBehavior', () {
    test('withOriginalName has an empty query value', () {
      expect(DownloadBehavior.withOriginalName.queryValue, '');
    });

    test('named carries the provided file name', () {
      expect(
        const DownloadBehavior.named('report.pdf').queryValue,
        'report.pdf',
      );
    });
  });

  group('StorageRetryController', () {
    test('starts uncancelled and flips after cancel', () {
      final controller = StorageRetryController();
      expect(controller.cancelled, isFalse);
      controller.cancel();
      expect(controller.cancelled, isTrue);
    });
  });
}
