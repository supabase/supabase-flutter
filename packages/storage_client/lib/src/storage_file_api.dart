import 'dart:typed_data';

import 'package:storage_client/src/fetch.dart';
import 'package:storage_client/src/types.dart';

import 'file_stub.dart' if (dart.library.io) './file_io.dart';

class StorageFileApi {
  final String url;
  Map<String, String> _headers;
  final String? bucketId;
  final int _retryAttempts;
  final Fetch _storageFetch;

  StorageFileApi(
    this.url,
    Map<String, String> headers,
    this.bucketId,
    this._retryAttempts,
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
    final encodedPath = Uri(pathSegments: path.split('/')).path;
    return '$bucketId/$encodedPath';
  }

  String _removeEmptyFolders(String path) {
    return path.replaceAll(RegExp(r'^/|/$'), '').replaceAll(RegExp(r'/+'), '/');
  }

  FetchOptions get _fetchOptions => FetchOptions(headers: headers);

  void _assertValidRetryAttempts(int? retryAttempts) {
    assert(
      retryAttempts == null || retryAttempts >= 0,
      'retryAttempts has to be greater or equal to 0',
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
  /// [retryAttempts] overrides the retryAttempts parameter set across the storage client.
  ///
  /// You can pass a [retryController] and call `cancel()` to cancel the retry attempts.
  Future<String> upload(
    String path,
    File file, {
    FileOptions fileOptions = const FileOptions(),
    int? retryAttempts,
    StorageRetryController? retryController,
  }) async {
    _assertValidRetryAttempts(retryAttempts);
    final finalPath = _getFinalPath(path);
    final response = await _storageFetch.postFile(
      '$url/object/$finalPath',
      file,
      fileOptions,
      options: _fetchOptions,
      retryAttempts: retryAttempts ?? _retryAttempts,
      retryController: retryController,
    );

    return (response as Map)['Key'] as String;
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
  /// [retryAttempts] overrides the retryAttempts parameter set across the storage client.
  ///
  /// You can pass a [retryController] and call `cancel()` to cancel the retry attempts.
  Future<String> uploadBinary(
    String path,
    Uint8List data, {
    FileOptions fileOptions = const FileOptions(),
    int? retryAttempts,
    StorageRetryController? retryController,
  }) async {
    _assertValidRetryAttempts(retryAttempts);
    final finalPath = _getFinalPath(path);
    final response = await _storageFetch.postBinaryFile(
      '$url/object/$finalPath',
      data,
      fileOptions,
      options: _fetchOptions,
      retryAttempts: retryAttempts ?? _retryAttempts,
      retryController: retryController,
    );

    return (response as Map)['Key'] as String;
  }

  /// Upload a file with a token generated from `createUploadSignedUrl`.
  ///
  /// [path] The file path, including the file name. Should be of the format `folder/subfolder/filename.png`. The bucket must already exist before attempting to upload.
  ///
  /// [token] The token generated from `createUploadSignedUrl`
  ///
  /// [file] The body of the file to be stored in the bucket.
  Future<String> uploadToSignedUrl(
    String path,
    String token,
    File file, [
    FileOptions fileOptions = const FileOptions(),
    int? retryAttempts,
    StorageRetryController? retryController,
  ]) async {
    _assertValidRetryAttempts(retryAttempts);

    final cleanPath = _removeEmptyFolders(path);
    final finalPath = _getFinalPath(cleanPath);
    var requestUrl = Uri.parse('$url/object/upload/sign/$finalPath');
    requestUrl = requestUrl.replace(queryParameters: {'token': token});

    await _storageFetch.putFile(
      requestUrl.toString(),
      file,
      fileOptions,
      retryAttempts: retryAttempts ?? _retryAttempts,
      retryController: retryController,
    );

    return cleanPath;
  }

  /// Upload a binary file with a token generated from `createUploadSignedUrl`.
  ///
  /// [path] The file path, including the file name. Should be of the format `folder/subfolder/filename.png`. The bucket must already exist before attempting to upload.
  ///
  /// [token] The token generated from `createUploadSignedUrl`
  ///
  /// [data] The body of the binary file to be stored in the bucket.
  Future<String> uploadBinaryToSignedUrl(
    String path,
    String token,
    Uint8List data, [
    FileOptions fileOptions = const FileOptions(),
    int? retryAttempts,
    StorageRetryController? retryController,
  ]) async {
    _assertValidRetryAttempts(retryAttempts);

    final cleanPath = _removeEmptyFolders(path);
    final path0 = _getFinalPath(cleanPath);
    var requestUrl = Uri.parse('$url/object/upload/sign/$path0');
    requestUrl = requestUrl.replace(queryParameters: {'token': token});

    await _storageFetch.putBinaryFile(
      requestUrl.toString(),
      data,
      fileOptions,
      retryAttempts: retryAttempts ?? _retryAttempts,
      retryController: retryController,
    );

    return cleanPath;
  }

  /// Creates a signed upload URL.
  ///
  /// Signed upload URLs can be used upload files to the bucket without further authentication.
  /// They are valid for one minute.
  ///
  /// [path] The file path, including the current file name. For example `folder/image.png`.
  ///
  /// When [upsert] is `true` the signed URL allows overwriting an existing
  /// file at [path]. It defaults to `false`.
  Future<SignedUploadURLResponse> createSignedUploadUrl(
    String path, {
    bool upsert = false,
  }) async {
    final finalPath = _getFinalPath(path);

    final data = await _storageFetch.post(
      '$url/object/upload/sign/$finalPath',
      {},
      options: FetchOptions(
        headers: {
          ...headers,
          if (upsert) 'x-upsert': 'true',
        },
      ),
    );

    final signedUrl = Uri.parse('$url${data['url']}');

    final token = signedUrl.queryParameters['token'];

    if (token == null || token.isEmpty) {
      throw StorageException('No token returned by API');
    }

    return SignedUploadURLResponse(
      signedUrl: signedUrl.toString(),
      path: path,
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
  /// [retryAttempts] overrides the retryAttempts parameter set across the storage client.
  ///
  /// You can pass a [retryController] and call `cancel()` to cancel the retry attempts.
  Future<String> update(
    String path,
    File file, {
    FileOptions fileOptions = const FileOptions(),
    int? retryAttempts,
    StorageRetryController? retryController,
  }) async {
    _assertValidRetryAttempts(retryAttempts);
    final finalPath = _getFinalPath(path);
    final response = await _storageFetch.putFile(
      '$url/object/$finalPath',
      file,
      fileOptions,
      options: _fetchOptions,
      retryAttempts: retryAttempts ?? _retryAttempts,
      retryController: retryController,
    );

    return (response as Map<String, dynamic>)['Key'] as String;
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
  /// [retryAttempts] overrides the retryAttempts parameter set across the storage client.
  ///
  /// You can pass a [retryController] and call `cancel()` to cancel the retry attempts.
  Future<String> updateBinary(
    String path,
    Uint8List data, {
    FileOptions fileOptions = const FileOptions(),
    int? retryAttempts,
    StorageRetryController? retryController,
  }) async {
    _assertValidRetryAttempts(retryAttempts);
    final finalPath = _getFinalPath(path);
    final response = await _storageFetch.putBinaryFile(
      '$url/object/$finalPath',
      data,
      fileOptions,
      options: _fetchOptions,
      retryAttempts: retryAttempts ?? _retryAttempts,
      retryController: retryController,
    );

    return (response as Map)['Key'] as String;
  }

  /// Moves an existing file.
  ///
  /// [fromPath] is the original file path, including the current file name. For
  /// example `folder/image.png`.
  /// [toPath] is the new file path, including the new file name. For example
  /// `folder/image-new.png`.
  ///
  /// When copying to a different bucket, you have to specify the [destinationBucket].
  Future<String> move(
    String fromPath,
    String toPath, {
    String? destinationBucket,
  }) async {
    final options = _fetchOptions;
    final response = await _storageFetch.post(
      '$url/object/move',
      {
        'bucketId': bucketId,
        'sourceKey': fromPath,
        'destinationKey': toPath,
        'destinationBucket': ?destinationBucket,
      },
      options: options,
    );
    return (response as Map<String, dynamic>)['message'] as String;
  }

  /// Copies an existing file.
  ///
  /// [fromPath] is the original file path, including the current file name. For
  /// example `folder/image.png`.
  ///
  /// [toPath] is the new file path, including the new file name. For example
  /// `folder/image-copy.png`.
  ///
  /// When copying to a different bucket, you have to specify the [destinationBucket].
  Future<String> copy(
    String fromPath,
    String toPath, {
    String? destinationBucket,
  }) async {
    final options = _fetchOptions;
    final response = await _storageFetch.post(
      '$url/object/copy',
      {
        'bucketId': bucketId,
        'sourceKey': fromPath,
        'destinationKey': toPath,
        'destinationBucket': ?destinationBucket,
      },
      options: options,
    );
    return (response as Map<String, dynamic>)['Key'] as String;
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
  Future<String> createSignedUrl(
    String path,
    int expiresIn, {
    TransformOptions? transform,
    DownloadBehavior? download,
  }) async {
    final finalPath = _getFinalPath(path);
    final options = _fetchOptions;
    final response = await _storageFetch.post(
      '$url/object/sign/$finalPath',
      {
        'expiresIn': expiresIn,
        'transform': ?transform?.toQueryParams,
      },
      options: options,
    );
    final signedUrlPath =
        (response as Map<String, dynamic>)['signedURL'] as String?;
    if (signedUrlPath == null) {
      throw StorageException('No signed URL returned by API');
    }
    return _withDownload('$url$signedUrlPath', download);
  }

  // TODO(v3): Remove this deprecated overload and rename createSignedUrlsResult
  // to createSignedUrls. Dart lacks overloading so the preferred API had to be
  // given a temporary name. https://linear.app/supabase/issue/SDK-1002
  /// Create signed URLs to download files without requiring permissions.
  ///
  /// Items for paths that do not exist are silently omitted. Use
  /// [createSignedUrlsResult] to distinguish missing paths from successful ones.
  ///
  /// [paths] is the file paths to be downloaded, including the current file
  /// names. For example: `createSignedUrls(['folder/image.png', 'folder2/image2.png'])`.
  ///
  /// [expiresIn] is the number of seconds until the signed URLs expire. For
  /// example, `60` for URLs which are valid for one minute.
  @Deprecated('Use createSignedUrlsResult to handle missing paths correctly.')
  Future<List<SignedUrl>> createSignedUrls(
    List<String> paths,
    int expiresIn, {
    DownloadBehavior? download,
  }) async {
    final results = await createSignedUrlsResult(
      paths,
      expiresIn,
      download: download,
    );
    return results
        .whereType<SignedUrlSuccess>()
        .map((r) => SignedUrl(path: r.path, signedUrl: r.signedUrl))
        .toList();
  }

  /// Create signed URLs to download files without requiring permissions. These
  /// URLs can be valid for a set number of seconds.
  ///
  /// Returns one [SignedUrlResult] per requested path. Each result is either a
  /// [SignedUrlSuccess] (with a ready-to-use signed URL) or a [SignedUrlFailure]
  /// (when the server could not sign that path, e.g. the file does not exist).
  ///
  /// [paths] is the file paths to be downloaded, including the current file
  /// names. For example: `createSignedUrlsResult(['folder/image.png', 'folder2/image2.png'])`.
  ///
  /// [expiresIn] is the number of seconds until the signed URLs expire. For
  /// example, `60` for URLs which are valid for one minute.
  ///
  /// [download] triggers the files to be downloaded rather than opened in the
  /// browser by setting the response's `Content-Disposition` header. Use
  /// [DownloadBehavior.withOriginalName] to keep the original file name or
  /// [DownloadBehavior.named] to override it.
  Future<List<SignedUrlResult>> createSignedUrlsResult(
    List<String> paths,
    int expiresIn, {
    DownloadBehavior? download,
  }) async {
    final options = _fetchOptions;
    final response = await _storageFetch.post(
      '$url/object/sign/$bucketId',
      {
        'expiresIn': expiresIn,
        'paths': paths,
      },
      options: options,
    );
    return (response as List).map<SignedUrlResult>((e) {
      final signedUrlPath = e['signedURL'] as String?;
      final path = e['path'] as String? ?? '';
      if (signedUrlPath != null) {
        return SignedUrlSuccess(
          path: path,
          signedUrl: _withDownload('$url$signedUrlPath', download),
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
  /// [transform] download a transformed variant of the image with the provided options
  ///
  /// [queryParams] additional query parameters to be added to the URL
  Future<Uint8List> download(
    String path, {
    TransformOptions? transform,
    Map<String, String>? queryParams,
  }) async {
    final transformationQuery = transform?.toQueryParams ?? {};
    final wantsTransformations = transformationQuery.isNotEmpty;
    final finalPath = _getFinalPath(path);
    final renderPath = wantsTransformations
        ? 'render/image/authenticated'
        : 'object';

    Map<String, String> query = transformationQuery;
    query.addAll(queryParams ?? {});

    final options = FetchOptions(headers: headers, noResolveJson: true);

    var fetchUrl = Uri.parse('$url/$renderPath/$finalPath');
    fetchUrl = fetchUrl.replace(queryParameters: query);

    final response = await _storageFetch.get(
      fetchUrl.toString(),
      options: options,
    );
    return response as Uint8List;
  }

  /// Retrieves the details of an existing file
  Future<FileObjectV2> info(String path) async {
    final finalPath = _getFinalPath(path);
    final options = _fetchOptions;
    final response = await _storageFetch.get(
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
    } on StorageException catch (e) {
      if (e.statusCode == '400' || e.statusCode == '404') {
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
  String getPublicUrl(
    String path, {
    TransformOptions? transform,
    DownloadBehavior? download,
  }) {
    final finalPath = _getFinalPath(path);

    final transformationQuery = transform?.toQueryParams;
    final wantsTransformation =
        transformationQuery != null && transformationQuery.isNotEmpty;
    final renderPath = wantsTransformation ? 'render/image' : 'object';

    var publicUrl = Uri.parse('$url/$renderPath/public/$finalPath');

    if (wantsTransformation) {
      publicUrl = publicUrl.replace(queryParameters: transformationQuery);
    }

    return _withDownload(publicUrl.toString(), download);
  }

  /// Appends a `download` query parameter to [urlString] when [download] is
  /// set, so the response is served with a `Content-Disposition` header.
  String _withDownload(String urlString, DownloadBehavior? download) {
    if (download == null) {
      return urlString;
    }
    final separator = urlString.contains('?') ? '&' : '?';
    return '$urlString${separator}download='
        '${Uri.encodeQueryComponent(download.queryValue)}';
  }

  /// Deletes files within the same bucket
  ///
  /// [paths] is an array of files to be deleted, including the path and file
  /// name. For example: `remove(['folder/image.png'])`.
  Future<List<FileObject>> remove(List<String> paths) async {
    final options = _fetchOptions;
    final response = await _storageFetch.delete(
      '$url/object/$bucketId',
      {'prefixes': paths},
      options: options,
    );
    final fileObjects = List<FileObject>.from(
      (response as List).map(
        (item) => FileObject.fromJson(item),
      ),
    );
    return fileObjects;
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
      'prefix': path ?? '',
      ...searchOptions.toMap(),
    };
    final options = _fetchOptions;
    final response = await _storageFetch.post(
      '$url/object/list/$bucketId',
      body,
      options: options,
    );
    final fileObjects = List<FileObject>.from(
      (response as List).map(
        (item) => FileObject.fromJson(item),
      ),
    );
    return fileObjects;
  }
}
