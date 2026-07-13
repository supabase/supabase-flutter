// ignore_for_file: deprecated_member_use_from_same_package

import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

class Bucket {
  final String id;
  final String name;
  final String owner;
  final String createdAt;
  final String updatedAt;
  final bool public;
  final int? fileSizeLimit;
  final List<String>? allowedMimeTypes;

  const Bucket({
    required this.id,
    required this.name,
    required this.owner,
    required this.createdAt,
    required this.updatedAt,
    required this.public,
    this.fileSizeLimit,
    this.allowedMimeTypes,
  });

  factory Bucket.fromJson(Map<String, dynamic> json) {
    final allowedMimeTypes = json['allowed_mime_types'];
    return Bucket(
      id: json['id'] as String,
      name: json['name'] as String,
      owner: json['owner'] as String? ?? '',
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      public: json['public'] as bool,
      fileSizeLimit: json['file_size_limit'] as int?,
      allowedMimeTypes: allowedMimeTypes is List
          ? allowedMimeTypes.cast()
          : null,
    );
  }
}

class FileObject {
  final String name;
  final String? bucketId;
  final String? owner;
  final String? id;
  final String? updatedAt;
  final String? createdAt;
  @Deprecated("")
  final String? lastAccessedAt;
  final Map<String, dynamic>? metadata;
  final Bucket? buckets;

  const FileObject({
    required this.name,
    required this.bucketId,
    required this.owner,
    required this.id,
    required this.updatedAt,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.metadata,
    required this.buckets,
  });

  factory FileObject.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw FormatException(
        'Expected JSON object for FileObject, got ${json.runtimeType}',
      );
    }
    final bucketsJson = json['buckets'];
    return FileObject(
      id: json['id'] as String?,
      name: json['name'] as String,
      bucketId: json['bucket_id'] as String?,
      owner: json['owner'] as String?,
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
      lastAccessedAt: json['last_accessed_at'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      buckets: bucketsJson is Map<String, dynamic>
          ? Bucket.fromJson(bucketsJson)
          : null,
    );
  }
}

class FileObjectV2 {
  final String id;
  final String version;
  final String name;
  final String bucketId;
  final String? updatedAt;
  final String createdAt;
  @Deprecated("")
  final String? lastAccessedAt;
  final int? size;
  final String? cacheControl;
  final String? contentType;
  final String? etag;
  final String? lastModified;
  final Map<String, dynamic>? metadata;

  const FileObjectV2({
    required this.id,
    required this.version,
    required this.name,
    required this.bucketId,
    required this.updatedAt,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.size,
    required this.cacheControl,
    required this.contentType,
    required this.etag,
    required this.lastModified,
    required this.metadata,
  });

  factory FileObjectV2.fromJson(Map<String, dynamic> json) {
    return FileObjectV2(
      id: json['id'] as String,
      version: json['version'] as String,
      name: json['name'] as String,
      bucketId: json['bucket_id'] as String,
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String,
      lastAccessedAt: json['last_accessed_at'] as String?,
      size: json['size'] as int?,
      cacheControl: json['cache_control'] as String?,
      contentType: json['content_type'] as String?,
      etag: json['etag'] as String?,
      lastModified: json['last_modified'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// [public] The visibility of the bucket. Public buckets don't require an
/// authorization token to download objects, but still require a valid token for
/// all other operations. By default, buckets are private.
///
/// [fileSizeLimit] specifies the file size limit that this bucket can accept during upload.
/// It should be in a format such as `20GB`, `20MB`, `30KB`, or `3B`
///
/// [allowedMimeTypes] specifies the allowed mime types that this bucket can accept during upload
class BucketOptions {
  final bool public;
  final String? fileSizeLimit;
  final List<String>? allowedMimeTypes;

  const BucketOptions({
    required this.public,
    this.fileSizeLimit,
    this.allowedMimeTypes,
  });
}

/// The column that [StorageBucketApi.listBuckets] can sort its results by.
enum BucketSortColumn { id, name, createdAt, updatedAt }

/// The direction that [StorageBucketApi.listBuckets] sorts its results in.
enum BucketSortOrder {
  ascending('asc'),
  descending('desc');

  const BucketSortOrder(this.value);

  /// The value sent to the storage API.
  final String value;
}

/// Filter, sort and pagination options for [StorageBucketApi.listBuckets].
class ListBucketsOptions {
  /// The maximum number of buckets to return.
  final int? limit;

  /// The number of buckets to skip.
  final int? offset;

  /// The column to sort the buckets by.
  final BucketSortColumn? sortColumn;

  /// The direction to sort the buckets in.
  final BucketSortOrder? sortOrder;

  /// A search term used to filter buckets by name.
  final String? search;

  const ListBucketsOptions({
    this.limit,
    this.offset,
    this.sortColumn,
    this.sortOrder,
    this.search,
  });

  Map<String, String> toQueryParameters() {
    return {
      'limit': ?limit?.toString(),
      'offset': ?offset?.toString(),
      if (search != null && search!.isNotEmpty) 'search': search!,
      'sortColumn': ?sortColumn?.snakeCase,
      'sortOrder': ?sortOrder?.value,
    };
  }
}

class FileOptions {
  /// The number of seconds the asset is cached in the browser and
  /// in the Supabase CDN. This is set in the `Cache-Control: max-age=<seconds>`
  /// header.
  ///
  /// Defaults to `3600`.
  final String cacheControl;

  /// When upsert is set to true, the file is overwritten if it exists.
  /// When set to false, an error is thrown if the object already exists.
  ///
  /// Defaults to `false`.
  final bool upsert;

  /// Used as Content-Type
  /// Gets parsed with [MediaType.parse(mime)]
  ///
  /// Throws a FormatError if the media type is invalid.
  final String? contentType;

  /// The metadata option is an object that allows you to store additional
  /// information about the file. This information can be used to filter and
  /// search for files.
  final Map<String, dynamic>? metadata;

  /// Optionally add extra headers.
  final Map<String, String>? headers;

  const FileOptions({
    this.cacheControl = '3600',
    this.upsert = false,
    this.contentType,
    this.metadata,
    this.headers,
  });
}

class SearchOptions {
  /// The number of files you want to be returned.
  final int? limit;

  /// The starting position.
  final int? offset;

  /// The column to sort by. Can be any column inside a FileObject.
  final SortBy? sortBy;

  /// The search string to filter files by.
  final String? search;

  const SearchOptions({
    this.limit = 100,
    this.offset = 0,
    this.sortBy = const SortBy(),
    this.search,
  });

  Map<String, dynamic> toMap() {
    return {
      'limit': limit,
      'offset': offset,
      'sortBy': sortBy?.toMap(),
      'search': search,
    };
  }
}

class SortBy {
  final String? column;
  final String? order;

  const SortBy({this.column = 'name', this.order = 'asc'});

  Map<String, dynamic> toMap() {
    return {
      'column': column ?? 'name',
      'order': order ?? 'asc',
    };
  }
}

/// The column that [StorageFileApi.listPaginated] can sort its results by.
enum FileSortColumn { name, updatedAt, createdAt }

/// The direction that [StorageFileApi.listPaginated] sorts its results in.
enum FileSortOrder {
  ascending('asc'),
  descending('desc');

  const FileSortOrder(this.value);

  /// The value sent to the storage API.
  final String value;
}

/// The column and direction that [StorageFileApi.listPaginated] sorts its
/// results by.
class FileSort {
  /// The column to sort by.
  final FileSortColumn column;

  /// The sort direction.
  final FileSortOrder order;

  const FileSort({
    this.column = FileSortColumn.name,
    this.order = FileSortOrder.ascending,
  });

  Map<String, dynamic> toMap() {
    return {
      'column': column.snakeCase,
      'order': order.value,
    };
  }
}

/// Options for [StorageFileApi.listPaginated].
class PaginatedSearchOptions {
  /// The number of files to return.
  ///
  /// Defaults to `1000` on the server when omitted.
  final int? limit;

  /// The prefix to filter files by.
  final String? prefix;

  /// The cursor used for pagination. Pass the [PaginatedListResult.nextCursor]
  /// value from the previous request to fetch the next page.
  final String? cursor;

  /// Whether to emulate a hierarchical listing of objects using delimiters.
  ///
  /// When `false` (default) all objects are listed as a flat list. When `true`
  /// the response groups objects by delimiter, separating them into
  /// [PaginatedListResult.folders] and [PaginatedListResult.objects].
  final bool? withDelimiter;

  /// The column and direction to sort by.
  final FileSort? sortBy;

  const PaginatedSearchOptions({
    this.limit,
    this.prefix,
    this.cursor,
    this.withDelimiter,
    this.sortBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'limit': ?limit,
      'prefix': ?prefix,
      'cursor': ?cursor,
      'with_delimiter': ?withDelimiter,
      'sortBy': ?sortBy?.toMap(),
    };
  }
}

/// A file entry returned by [StorageFileApi.listPaginated].
class PaginatedFile {
  /// The file name.
  final String name;

  /// The full object key/path.
  final String? key;

  /// The unique identifier of the file.
  final String? id;

  /// The last update timestamp.
  final String? updatedAt;

  /// The creation timestamp.
  final String? createdAt;

  /// The file metadata, including size and mimetype. `null` when not yet set.
  final Map<String, dynamic>? metadata;

  const PaginatedFile({
    required this.name,
    required this.key,
    required this.id,
    required this.updatedAt,
    required this.createdAt,
    required this.metadata,
  });

  factory PaginatedFile.fromJson(Map<String, dynamic> json) {
    return PaginatedFile(
      name: json['name'] as String,
      key: json['key'] as String?,
      id: json['id'] as String?,
      updatedAt: json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// A folder entry returned by [StorageFileApi.listPaginated] when using a
/// delimiter.
class PaginatedFolder {
  /// The folder name/prefix.
  final String name;

  /// The full folder key/path.
  final String? key;

  const PaginatedFolder({
    required this.name,
    required this.key,
  });

  factory PaginatedFolder.fromJson(Map<String, dynamic> json) {
    return PaginatedFolder(
      name: json['name'] as String,
      key: json['key'] as String?,
    );
  }
}

/// The result of [StorageFileApi.listPaginated].
class PaginatedListResult {
  /// Whether there are more results available on a subsequent page.
  final bool hasNext;

  /// The folders in this page. Only populated when a delimiter is used.
  final List<PaginatedFolder> folders;

  /// The files in this page.
  final List<PaginatedFile> objects;

  /// The cursor to pass as [PaginatedSearchOptions.cursor] to fetch the next
  /// page.
  final String? nextCursor;

  const PaginatedListResult({
    required this.hasNext,
    required this.folders,
    required this.objects,
    required this.nextCursor,
  });

  factory PaginatedListResult.fromJson(Map<String, dynamic> json) {
    final folders = json['folders'] as List? ?? const [];
    final objects = json['objects'] as List? ?? const [];
    return PaginatedListResult(
      hasNext: json['hasNext'] as bool? ?? false,
      folders: folders
          .map((e) => PaginatedFolder.fromJson(e as Map<String, dynamic>))
          .toList(),
      objects: objects
          .map((e) => PaginatedFile.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

class SignedUrl {
  /// The file path, including the current file name. For example `folder/image.png`.
  final String path;

  /// Full signed URL of the files.
  final String signedUrl;

  const SignedUrl({
    required this.path,
    required this.signedUrl,
  });

  @override
  String toString() => 'SignedUrl(path: $path, signedUrl: $signedUrl)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SignedUrl &&
        other.path == path &&
        other.signedUrl == signedUrl;
  }

  @override
  int get hashCode => path.hashCode ^ signedUrl.hashCode;

  SignedUrl copyWith({
    String? path,
    String? signedUrl,
  }) {
    return SignedUrl(
      path: path ?? this.path,
      signedUrl: signedUrl ?? this.signedUrl,
    );
  }
}

/// Represents a per-item result from [StorageFileApi.createSignedUrlsResult].
///
/// Use exhaustive pattern matching to handle both outcomes:
/// ```dart
/// for (final result in results) {
///   switch (result) {
///     case SignedUrlSuccess(:final signedUrl):
///       print('URL: $signedUrl');
///     case SignedUrlFailure(:final error):
///       print('Missing: $error');
///   }
/// }
/// ```
sealed class SignedUrlResult {
  /// The requested file path.
  final String path;
  const SignedUrlResult({required this.path});
}

/// A successful [SignedUrlResult]: the file was found and a signed URL was generated.
final class SignedUrlSuccess extends SignedUrlResult {
  /// The signed URL ready for use.
  final String signedUrl;
  const SignedUrlSuccess({required super.path, required this.signedUrl});

  @override
  String toString() => 'SignedUrlSuccess(path: $path, signedUrl: $signedUrl)';
}

/// A failed [SignedUrlResult]: the path could not be signed (e.g. the file does not exist).
final class SignedUrlFailure extends SignedUrlResult {
  /// The reason the URL could not be created.
  final String error;
  const SignedUrlFailure({required super.path, required this.error});

  @override
  String toString() => 'SignedUrlFailure(path: $path, error: $error)';
}

class SignedUploadURLResponse extends SignedUrl {
  /// Token to be used when uploading files with the `uploadToSignedUrl` method.
  final String token;

  const SignedUploadURLResponse({
    required super.signedUrl,
    required super.path,
    required this.token,
  });
}

class StorageException implements Exception {
  final String message;
  final String? error;
  final String? statusCode;

  const StorageException(this.message, {this.error, this.statusCode});

  factory StorageException.fromJson(
    Map<String, dynamic> json, [
    String? statusCode,
  ]) => StorageException(
    json['message'] as String? ?? json.toString(),
    error: json['error'] as String?,
    statusCode: json['statusCode']?.toString() ?? statusCode,
  );

  @override
  String toString() {
    return 'StorageException(message: $message, statusCode: $statusCode, error: $error)';
  }
}

class StorageRetryController {
  /// Whether the retry operation is aborted
  bool get cancelled => _cancelled;
  bool _cancelled = false;

  /// Creates a controller to abort storage file upload retry operations.
  StorageRetryController();

  /// Aborts the next retry operation
  void cancel() {
    _cancelled = true;
  }
}

/// {@template resize_mode}
/// Specifies how image cropping should be handled when performing image transformations.
/// {@endtemplate}
enum ResizeMode {
  /// Resizes the image while keeping the aspect ratio to fill a given size and crops projecting parts.
  cover,

  /// Resizes the image while keeping the aspect ratio to fit a given size.
  contain,

  /// Resizes the image without keeping the aspect ratio to fill a given size.
  fill,
}

enum RequestImageFormat {
  origin,
}

/// {@template transform_options}
/// Specifies the dimensions and the resize mode of the requesting image.
/// {@endtemplate}
class TransformOptions {
  /// The width of the image in pixels.
  final int? width;

  /// The height of the image in pixels.
  final int? height;

  /// {@macro resize_mode}
  ///
  /// [ResizeMode.cover] will be used if no value is specified.
  final ResizeMode? resize;

  /// Set the quality of the returned image, this is percentage based, default 80
  final int? quality;

  ///  Specify the format of the image requested.
  ///
  ///  When using 'origin' we force the format to be the same as the original image,
  ///  bypassing automatic browser optimization such as webp conversion
  final RequestImageFormat? format;

  /// {@macro transform_options}
  const TransformOptions({
    this.width,
    this.height,
    this.resize,
    this.quality,
    this.format,
  });
}

extension ToQueryParams on TransformOptions {
  Map<String, String> get toQueryParams {
    return {
      if (width != null) 'width': '$width',
      if (height != null) 'height': '$height',
      'resize': ?resize?.snakeCase,
      if (quality != null) 'quality': '$quality',
      'format': ?format?.snakeCase,
    };
  }
}

/// Controls download behavior for signed and public URLs.
///
/// Passing a [DownloadBehavior] triggers the file to be downloaded rather than
/// opened in the browser by setting the response's `Content-Disposition`
/// header.
///
/// ```dart
/// storage.from('docs').getPublicUrl(
///   'report.pdf',
///   download: DownloadBehavior.withOriginalName,
/// );
/// storage.from('docs').getPublicUrl(
///   'report.pdf',
///   download: DownloadBehavior.named('annual-2024.pdf'),
/// );
/// ```
class DownloadBehavior {
  const DownloadBehavior._(String fileName) : _queryValue = fileName;

  /// Triggers a download using the file's original name.
  static const DownloadBehavior withOriginalName = DownloadBehavior._('');

  /// Triggers a download with a custom [fileName].
  const DownloadBehavior.named(String fileName) : _queryValue = fileName;

  final String _queryValue;

  /// The value appended to the `download` query parameter.
  @internal
  String get queryValue => _queryValue;
}
