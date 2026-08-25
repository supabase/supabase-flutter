import 'dart:typed_data';

import 'package:supabase_storage/src/fetch.dart';
import 'package:supabase_storage/src/types.dart';
import 'package:supabase_common/supabase_common.dart';

import 'file_stub.dart' if (dart.library.io) './file_io.dart';

class StorageFileApi {
  final String url;
  Map<String, String> _headers;
  final String? bucketId;
  final SupabaseRetryOptions _retryOptions;
  final Fetch _storageFetch;

  StorageFileApi(
    this.url,
    Map<String, String> headers,
    this.bucketId,
    this._retryOptions,
    this._storageFetch,
  ) : _headers = {...headers};

  /// The headers used for requests.
  Map<String, String> get headers => _headers;

  /// Sets an HTTP header for subsequent requests.
  ///
  /// Creates a shallow copy of headers to avoid mutating shared state.
  /// Returns this for method chaining.
  ///
  /// ```dart
  /// storage.from('bucket').setHeader('x-custom-header', 'value').upload(...);
  /// ```
  StorageFileApi setHeader(String key, String value) {
    _headers = {..._headers, key: value};
    return this;
  }

  String _getFinalPath(String path) {
    // Percent-encode each segment (RFC 3986) so object keys containing
    // characters like `?`, `#`, `%` or spaces don't corrupt the request URL
    // (for example a `?` being parsed as the start of the query string). `/`
    // separators, the bucket id, and characters that are already valid in a
    // path segment (such as `:` in ISO-8601 timestamps) are preserved, so URLs
    // for existing valid keys are unchanged.
    final cleanPath = _removeEmptyFolders(path);
    final encodedPath = Uri(pathSegments: cleanPath.split('/')).path;
    return '$bucketId/$encodedPath';
  }

  String _removeEmptyFolders(String path) {
    return path.replaceAll(RegExp(r'/+'), '/').replaceAll(RegExp(r'^/|/$'), '');
  }

  FetchOptions get _fetchOptions => FetchOptions(headers);

  UploadResponse _uploadResponse(String cleanPath, Map<String, dynamic> data) {
    return UploadResponse(
      id: data['Id'] as String?,
      path: cleanPath,
      fullPath: data['Key'] as String,
    );
  }

  /// Uploads a file to an existing bucket.
  ///
  /// [path] is the relative file path without the bucket ID. Should be of the
  /// format `folder/subfolder/filename.png`. The bucket must already
  /// exist before attempting to upload.
  ///
  /// [file] is the File object to be stored in the bucket.
  ///
  /// [fileOptions] HTTP headers. For example `cacheControl`
  ///
  /// [retryOptions] overrides the retry configuration of the storage client
  /// for this upload.
  ///
  /// You can pass a [retryController] and call `cancel()` to cancel the retry
  /// attempts.
  ///
  /// Returns an [UploadResponse] with the id, path and full path of the
  /// stored object.
  Future<UploadResponse> upload(
    String path,
    File file, {
    FileOptions fileOptions = const FileOptions(),
    SupabaseRetryOptions? retryOptions,
    StorageRetryController? retryController,
  }) async {
    final cleanPath = _removeEmptyFolders(path);
    final finalPath = _getFinalPath(cleanPath);
    final response = await _storageFetch.postFile(
      '$url/object/$finalPath',
      file,
      fileOptions,
      options: _fetchOptions,
      retryOptions: retryOptions ?? _retryOptions,
      retryController: retryController,
    );

    return _uploadResponse(cleanPath, response);
  }

  /// Uploads a binary file to an existing bucket. Can be used on the web.
  ///
  /// [path] is the relative file path without the bucket ID. Should be of the
  /// format `folder/subfolder/filename.png`. The bucket must already
  /// exist before attempting to upload.
  ///
  /// [data] is the binary file data to be stored in the bucket.
  ///
  /// [fileOptions] HTTP headers. For example `cacheControl`
  ///
  /// [retryOptions] overrides the retry configuration of the storage client
  /// for this upload.
  ///
  /// You can pass a [retryController] and call `cancel()` to cancel the retry
  /// attempts.
  ///
  /// Returns an [UploadResponse] with the id, path and full path of the
  /// stored object.
  Future<UploadResponse> uploadBinary(
    String path,
    Uint8List data, {
    FileOptions fileOptions = const FileOptions(),
    SupabaseRetryOptions? retryOptions,
    StorageRetryController? retryController,
  }) async {
    final cleanPath = _removeEmptyFolders(path);
    final finalPath = _getFinalPath(cleanPath);
    final response = await _storageFetch.postBinaryFile(
      '$url/object/$finalPath',
      data,
      fileOptions,
      options: _fetchOptions,
      retryOptions: retryOptions ?? _retryOptions,
      retryController: retryController,
    );

    return _uploadResponse(cleanPath, response);
  }

  /// Upload a file with a token generated from `createUploadSignedUrl`.
  ///
  /// [path] The file path, including the file name. Should be of the format
  /// `folder/subfolder/filename.png`. The bucket must already exist before
  /// attempting to upload.
  ///
  /// [token] The token generated from `createUploadSignedUrl`
  ///
  /// [file] The body of the file to be stored in the bucket.
  ///
  /// Returns an [UploadResponse] with the path and full path of the stored
  /// object. [UploadResponse.id] is `null`, because the server does not
  /// report it for uploads through a signed URL.
  Future<UploadResponse> uploadToSignedUrl(
    String path,
    String token,
    File file, [
    FileOptions fileOptions = const FileOptions(),
    SupabaseRetryOptions? retryOptions,
    StorageRetryController? retryController,
  ]) async {
    final cleanPath = _removeEmptyFolders(path);
    final finalPath = _getFinalPath(cleanPath);
    var requestUrl = Uri.parse('$url/object/upload/sign/$finalPath');
    requestUrl = requestUrl.replace(queryParameters: {'token': token});

    final response = await _storageFetch.putFile(
      requestUrl.toString(),
      file,
      fileOptions,
      retryOptions: retryOptions ?? _retryOptions,
      retryController: retryController,
    );

    return _uploadResponse(cleanPath, response);
  }

  /// Upload a binary file with a token generated from `createUploadSignedUrl`.
  ///
  /// [path] The file path, including the file name. Should be of the format
  /// `folder/subfolder/filename.png`. The bucket must already exist before
  /// attempting to upload.
  ///
  /// [token] The token generated from `createUploadSignedUrl`
  ///
  /// [data] The body of the binary file to be stored in the bucket.
  ///
  /// Returns an [UploadResponse] with the path and full path of the stored
  /// object. [UploadResponse.id] is `null`, because the server does not
  /// report it for uploads through a signed URL.
  Future<UploadResponse> uploadBinaryToSignedUrl(
    String path,
    String token,
    Uint8List data, [
    FileOptions fileOptions = const FileOptions(),
    SupabaseRetryOptions? retryOptions,
    StorageRetryController? retryController,
  ]) async {
    final cleanPath = _removeEmptyFolders(path);
    final finalPath = _getFinalPath(cleanPath);
    var requestUrl = Uri.parse('$url/object/upload/sign/$finalPath');
    requestUrl = requestUrl.replace(queryParameters: {'token': token});

    final response = await _storageFetch.putBinaryFile(
      requestUrl.toString(),
      data,
      fileOptions,
      retryOptions: retryOptions ?? _retryOptions,
      retryController: retryController,
    );

    return _uploadResponse(cleanPath, response);
  }

  /// Creates a signed upload URL.
  ///
  /// Signed upload URLs can be used to upload files to the bucket without
  /// further authentication. They are valid for one minute.
  ///
  /// [path] The file path, including the current file name. For example
  /// `folder/image.png`.
  ///
  /// When [upsert] is `true` the signed URL allows overwriting an existing
  /// file at [path]. It defaults to `false`.
  Future<SignedUploadURLResponse> createSignedUploadUrl(
    String path, {
    bool upsert = false,
  }) async {
    final cleanPath = _removeEmptyFolders(path);
    final finalPath = _getFinalPath(cleanPath);

    final data = await _storageFetch.post<Map<String, dynamic>>(
      '$url/object/upload/sign/$finalPath',
      {},
      options: FetchOptions({
        ...headers,
        if (upsert) 'x-upsert': 'true',
      }),
    );

    final signedUrl = Uri.parse('$url${data['url']}');

    final token = signedUrl.queryParameters['token'];

    if (token == null || token.isEmpty) {
      throw StorageException('No token returned by API');
    }

    return SignedUploadURLResponse(
      signedUrl: signedUrl.toString(),
      path: cleanPath,
      token: token,
    );
  }

  /// Replaces an existing file at the specified path with a new one.
  ///
  /// [path] is the relative file path without the bucket ID. Should be of the
  /// format `folder/subfolder/filename.png`. The bucket must already
  /// exist before attempting to upload.
  /// [file] is the file object to be stored in the bucket.
  ///
  /// [fileOptions] HTTP headers. For example `cacheControl`
  ///
  /// [retryOptions] overrides the retry configuration of the storage client
  /// for this upload.
  ///
  /// You can pass a [retryController] and call `cancel()` to cancel the retry
  /// attempts.
  ///
  /// Returns an [UploadResponse] with the id, path and full path of the
  /// stored object.
  Future<UploadResponse> update(
    String path,
    File file, {
    FileOptions fileOptions = const FileOptions(),
    SupabaseRetryOptions? retryOptions,
    StorageRetryController? retryController,
  }) async {
    final cleanPath = _removeEmptyFolders(path);
    final finalPath = _getFinalPath(cleanPath);
    final response = await _storageFetch.putFile(
      '$url/object/$finalPath',
      file,
      fileOptions,
      options: _fetchOptions,
      retryOptions: retryOptions ?? _retryOptions,
      retryController: retryController,
    );

    return _uploadResponse(cleanPath, response);
  }

  /// Replaces an existing file at the specified path with a new one. Can be
  /// used on the web.
  ///
  /// [path] is the relative file path without the bucket ID. Should be of the
  /// format `folder/subfolder/filename.png`. The bucket must already
  /// exist before attempting to upload.
  ///
  /// [data] is the binary file data to be stored in the bucket.
  ///
  /// [fileOptions] HTTP headers. For example `cacheControl`
  ///
  /// [retryOptions] overrides the retry configuration of the storage client
  /// for this upload.
  ///
  /// You can pass a [retryController] and call `cancel()` to cancel the retry
  /// attempts.
  ///
  /// Returns an [UploadResponse] with the id, path and full path of the
  /// stored object.
  Future<UploadResponse> updateBinary(
    String path,
    Uint8List data, {
    FileOptions fileOptions = const FileOptions(),
    SupabaseRetryOptions? retryOptions,
    StorageRetryController? retryController,
  }) async {
    final cleanPath = _removeEmptyFolders(path);
    final finalPath = _getFinalPath(cleanPath);
    final response = await _storageFetch.putBinaryFile(
      '$url/object/$finalPath',
      data,
      fileOptions,
      options: _fetchOptions,
      retryOptions: retryOptions ?? _retryOptions,
      retryController: retryController,
    );

    return _uploadResponse(cleanPath, response);
  }

  /// Moves an existing file.
  ///
  /// [fromPath] is the original file path, including the current file name. For
  /// example `folder/image.png`.
  /// [toPath] is the new file path, including the new file name. For example
  /// `folder/image-new.png`.
  ///
  /// When copying to a different bucket, you have to specify the
  /// [destinationBucket].
  Future<String> move(
    String fromPath,
    String toPath, {
    String? destinationBucket,
  }) async {
    final options = _fetchOptions;
    final response = await _storageFetch.post<Map<String, dynamic>>(
      '$url/object/move',
      {
        'bucketId': bucketId,
        'sourceKey': _removeEmptyFolders(fromPath),
        'destinationKey': _removeEmptyFolders(toPath),
        'destinationBucket': ?destinationBucket,
      },
      options: options,
    );
    return response['message'] as String;
  }

  /// Copies an existing file.
  ///
  /// [fromPath] is the original file path, including the current file name. For
  /// example `folder/image.png`.
  ///
  /// [toPath] is the new file path, including the new file name. For example
  /// `folder/image-copy.png`.
  ///
  /// When copying to a different bucket, you have to specify the
  /// [destinationBucket].
  Future<String> copy(
    String fromPath,
    String toPath, {
    String? destinationBucket,
  }) async {
    final options = _fetchOptions;
    final response = await _storageFetch.post<Map<String, dynamic>>(
      '$url/object/copy',
      {
        'bucketId': bucketId,
        'sourceKey': _removeEmptyFolders(fromPath),
        'destinationKey': _removeEmptyFolders(toPath),
        'destinationBucket': ?destinationBucket,
      },
      options: options,
    );
    return response['Key'] as String;
  }

  /// Create signed URL to download file without requiring permissions. This URL
  /// can be valid for a set number of seconds.
  ///
  /// [path] is the file path to be downloaded, including the current file
  /// names. For example: `createdSignedUrl('folder/image.png')`.
  ///
  /// [expiresIn] is the number of seconds until the signed URL expire. For
  /// example, `60` for a URL which are valid for one minute.
  ///
  /// [transform] adds image transformations parameters to the generated url.
  ///
  /// [download] triggers the file to be downloaded rather than opened in the
  /// browser by setting the response's `Content-Disposition` header. Use
  /// [DownloadBehavior.withOriginalName] to keep the original file name or
  /// [DownloadBehavior.named] to override it.
  ///
  /// [cacheNonce] appends a `cacheNonce` query parameter to the URL to bypass
  /// CDN caching for a specific file version.
  Future<String> createSignedUrl(
    String path,
    int expiresIn, {
    TransformOptions? transform,
    DownloadBehavior? download,
    String? cacheNonce,
  }) async {
    final finalPath = _getFinalPath(path);
    final options = _fetchOptions;
    final response = await _storageFetch.post<Map<String, dynamic>>(
      '$url/object/sign/$finalPath',
      {
        'expiresIn': expiresIn,
        'transform': ?transform?.toQueryParameters,
      },
      options: options,
    );
    final signedUrlPath = response['signedURL'] as String?;
    if (signedUrlPath == null) {
      throw StorageException('No signed URL returned by API');
    }
    return _withUrlOptions(
      '$url$signedUrlPath',
      download: download,
      cacheNonce: cacheNonce,
    );
  }

  /// Create signed URLs to download files without requiring permissions. These
  /// URLs can be valid for a set number of seconds.
  ///
  /// Returns one [SignedUrlResult] per requested path. Each result is either a
  /// [SignedUrlSuccess] (with a ready-to-use signed URL) or a
  /// [SignedUrlFailure] (when the server could not sign that path, e.g. the
  /// file does not exist).
  ///
  /// [paths] is the file paths to be downloaded, including the current file
  /// names. For example: `createSignedUrls(['folder/image.png',
  /// 'folder2/image2.png'])`.
  ///
  /// [expiresIn] is the number of seconds until the signed URLs expire. For
  /// example, `60` for URLs which are valid for one minute.
  ///
  /// [download] triggers the files to be downloaded rather than opened in the
  /// browser by setting the response's `Content-Disposition` header. Use
  /// [DownloadBehavior.withOriginalName] to keep the original file name or
  /// [DownloadBehavior.named] to override it.
  ///
  /// [cacheNonce] appends a `cacheNonce` query parameter to each URL to bypass
  /// CDN caching for a specific file version.
  Future<List<SignedUrlResult>> createSignedUrls(
    List<String> paths,
    int expiresIn, {
    DownloadBehavior? download,
    String? cacheNonce,
  }) async {
    final options = _fetchOptions;
    final response = await _storageFetch.post<List<dynamic>>(
      '$url/object/sign/$bucketId',
      {
        'expiresIn': expiresIn,
        'paths': paths.map(_removeEmptyFolders).toList(),
      },
      options: options,
    );
    return response.map<SignedUrlResult>((e) {
      final signedUrlPath = e['signedURL'] as String?;
      final path = e['path'] as String? ?? '';
      if (signedUrlPath != null) {
        return SignedUrlSuccess(
          path: path,
          signedUrl: _withUrlOptions(
            '$url$signedUrlPath',
            download: download,
            cacheNonce: cacheNonce,
          ),
        );
      }
      return SignedUrlFailure(
        path: path,
        error: e['error'] as String? ?? 'Unknown error',
      );
    }).toList();
  }

  /// Downloads a file.
  ///
  /// [path] is the file path to be downloaded, including the path and file
  /// name. For example `download('folder/image.png')`.
  ///
  /// [transform] downloads a transformed variant of the image with the provided
  /// options
  ///
  /// [queryParameters] additional query parameters to be added to the URL
  ///
  /// [cacheNonce] adds a `cacheNonce` query parameter to bypass CDN caching for
  /// a specific file version.
  Future<Uint8List> download(
    String path, {
    TransformOptions? transform,
    Map<String, String>? queryParameters,
    String? cacheNonce,
  }) {
    final fetchUrl = _downloadUri(
      path,
      transform: transform,
      queryParameters: queryParameters,
      cacheNonce: cacheNonce,
    );

    return _storageFetch.get(
      fetchUrl.toString(),
      options: FetchOptions(headers, noResolveJson: true),
    );
  }

  /// Builds the download URL shared by [download] and [downloadStream],
  /// selecting the render endpoint when an image transformation is requested
  /// and appending transform, [queryParameters] and [cacheNonce] query
  /// parameters.
  Uri _downloadUri(
    String path, {
    TransformOptions? transform,
    Map<String, String>? queryParameters,
    String? cacheNonce,
  }) {
    final transformationQuery = transform?.toQueryParameters ?? {};
    final renderPath = transformationQuery.isNotEmpty
        ? 'render/image/authenticated'
        : 'object';

    final query = {
      ...transformationQuery,
      ...?queryParameters,
      'cacheNonce': ?cacheNonce,
    };

    return Uri.parse(
      '$url/$renderPath/${_getFinalPath(path)}',
    ).replace(queryParameters: query);
  }

  /// Downloads a file as a byte stream for memory-efficient handling of large
  /// files.
  ///
  /// Unlike [download], the response body is not buffered into a [Uint8List];
  /// the stream yields the bytes as they arrive. The request is sent when the
  /// stream is listened to, and a non-success response surfaces as a
  /// [StorageException] on the stream before any bytes are emitted.
  ///
  /// [path] is the file path to be downloaded, including the path and file
  /// name. For example `downloadStream('folder/image.png')`.
  ///
  /// [transform] downloads a transformed variant of the image with the provided
  /// options.
  ///
  /// [queryParameters] additional query parameters to be added to the URL.
  ///
  /// [cacheNonce] adds a `cacheNonce` query parameter to bypass CDN caching for
  /// a specific file version.
  Stream<Uint8List> downloadStream(
    String path, {
    TransformOptions? transform,
    Map<String, String>? queryParameters,
    String? cacheNonce,
  }) {
    final fetchUrl = _downloadUri(
      path,
      transform: transform,
      queryParameters: queryParameters,
      cacheNonce: cacheNonce,
    );

    return _storageFetch.getStream(
      fetchUrl.toString(),
      options: FetchOptions(headers, noResolveJson: true),
    );
  }

  /// Retrieves the details of an existing file
  Future<FileObjectV2> getMetadata(String path) async {
    final finalPath = _getFinalPath(path);
    final options = _fetchOptions;
    final response = await _storageFetch.get<Map<String, dynamic>>(
      '$url/object/info/$finalPath',
      options: options,
    );
    final fileObjects = FileObjectV2.fromJson(response);
    return fileObjects;
  }

  /// Checks the existence of a file
  Future<bool> exists(String path) async {
    final finalPath = _getFinalPath(path);
    final options = _fetchOptions;
    try {
      await _storageFetch.head(
        '$url/object/$finalPath',
        options: options,
      );
      return true;
    } on StorageApiException catch (error) {
      if (error.statusCode == 400 || error.statusCode == 404) {
        return false;
      }
      rethrow;
    }
  }

  /// Retrieve URLs for assets in public buckets
  ///
  /// [path] is the file path to be downloaded, including the current file name.
  /// For example `getPublicUrl('folder/image.png')`.
  ///
  /// [transform] adds image transformations parameters to the generated url.
  ///
  /// [download] triggers the file to be downloaded rather than opened in the
  /// browser by setting the response's `Content-Disposition` header. Use
  /// [DownloadBehavior.withOriginalName] to keep the original file name or
  /// [DownloadBehavior.named] to override it.
  ///
  /// [cacheNonce] appends a `cacheNonce` query parameter to the URL to bypass
  /// CDN caching for a specific file version.
  String getPublicUrl(
    String path, {
    TransformOptions? transform,
    DownloadBehavior? download,
    String? cacheNonce,
  }) {
    final finalPath = _getFinalPath(path);

    final transformationQuery = transform?.toQueryParameters;
    final wantsTransformation =
        transformationQuery != null && transformationQuery.isNotEmpty;
    final renderPath = wantsTransformation ? 'render/image' : 'object';

    var publicUrl = Uri.parse('$url/$renderPath/public/$finalPath');

    if (wantsTransformation) {
      publicUrl = publicUrl.replace(queryParameters: transformationQuery);
    }

    return _withUrlOptions(
      publicUrl.toString(),
      download: download,
      cacheNonce: cacheNonce,
    );
  }

  /// Appends the optional `download` and `cacheNonce` query parameters to
  /// [urlString], in that order, when they are set.
  String _withUrlOptions(
    String urlString, {
    DownloadBehavior? download,
    String? cacheNonce,
  }) {
    var result = urlString;
    if (download != null) {
      result = _appendQueryParameter(result, 'download', download.queryValue);
    }
    if (cacheNonce != null) {
      result = _appendQueryParameter(result, 'cacheNonce', cacheNonce);
    }
    return result;
  }

  String _appendQueryParameter(String urlString, String key, String value) {
    final separator = urlString.contains('?') ? '&' : '?';
    return '$urlString$separator$key=${Uri.encodeQueryComponent(value)}';
  }

  /// Deletes files within the same bucket
  ///
  /// [paths] is an array of files to be deleted, including the path and file
  /// name. For example: `remove(['folder/image.png'])`.
  Future<List<FileObject>> remove(List<String> paths) async {
    final options = _fetchOptions;
    final response = await _storageFetch.delete<List<dynamic>>(
      '$url/object/$bucketId',
      {'prefixes': paths.map(_removeEmptyFolders).toList()},
      options: options,
    );
    final fileObjects = List<FileObject>.from(
      response.map(
        (item) => FileObject.fromJson(item),
      ),
    );
    return fileObjects;
  }

  /// Purges the CDN cache for a single object.
  ///
  /// Invalidates the CDN cache for the object at [path] (relative to the
  /// bucket). There is no wildcard or recursion; pass the exact path of the
  /// object to invalidate. For example: `purgeCache('folder/avatar.png')`.
  ///
  /// When [transformations] is `true`, only the resized/formatted variants are
  /// purged, leaving the original cached file intact. When omitted the object
  /// cache is purged.
  ///
  /// Requires the service-role key and the tenant `purgeCache` feature to be
  /// enabled on the storage server.
  Future<String> purgeCache(
    String path, {
    bool transformations = false,
  }) async {
    final finalPath = _getFinalPath(path);
    var requestUrl = Uri.parse('$url/cdn/$finalPath');
    if (transformations) {
      requestUrl = requestUrl.replace(
        queryParameters: {'transformations': 'true'},
      );
    }
    final response = await _storageFetch.delete<Map<String, dynamic>>(
      requestUrl.toString(),
      {},
      options: _fetchOptions,
    );
    return response['message'] as String;
  }

  /// Lists all the files within a bucket.
  ///
  /// [path] The folder path.
  ///
  /// [searchOptions] includes `limit`, `offset`, and `sortBy`.
  Future<List<FileObject>> list({
    String? path,
    SearchOptions searchOptions = const SearchOptions(),
  }) async {
    final Map<String, dynamic> body = {
      'prefix': _removeEmptyFolders(path ?? ''),
      ...searchOptions.toMap(),
    };
    final options = _fetchOptions;
    final response = await _storageFetch.post<List<dynamic>>(
      '$url/object/list/$bucketId',
      body,
      options: options,
    );
    final fileObjects = List<FileObject>.from(
      response.map(
        (item) => FileObject.fromJson(item),
      ),
    );
    return fileObjects;
  }

  /// Lists files and folders within a bucket with cursor-based pagination and
  /// hierarchical (delimiter) listing.
  ///
  /// [options] includes `prefix`, `cursor`, `limit`, `withDelimiter` and
  /// `sortBy`.
  ///
  /// Folder entries in [PaginatedListResult.folders] only contain a name (and
  /// optionally a key); full metadata is only available on the file entries in
  /// [PaginatedListResult.objects].
  Future<PaginatedListResult> listPaginated({
    PaginatedSearchOptions options = const PaginatedSearchOptions(),
  }) async {
    final response = await _storageFetch.post<Map<String, dynamic>>(
      '$url/object/list-v2/$bucketId',
      options.toMap(),
      options: _fetchOptions,
    );
    return PaginatedListResult.fromJson(response);
  }
}
