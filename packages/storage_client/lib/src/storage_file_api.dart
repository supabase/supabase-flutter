import 'dart:typed_data';

import 'package:storage_client/src/fetch.dart';
import 'package:storage_client/src/types.dart';

import 'file_io.dart' if (dart.library.js) './file_stub.dart';

class StorageFileApi {
  final String url;
  final Map<String, String> headers;
  final String? bucketId;
  final int _retryAttempts;

  const StorageFileApi(
    this.url,
    this.headers,
    this.bucketId,
    this._retryAttempts,
  );

  String _getFinalPath(String path) {
    return '$bucketId/$path';
  }

  String _removeEmptyFolders(String path) {
    return path
        .replaceAll(RegExp(r'/^\/|\/$/g'), '')
        .replaceAll(RegExp(r'/\/+/g'), '/');
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
    assert(retryAttempts == null || retryAttempts >= 0,
        'retryAttempts has to be greater or equal to 0');
    final finalPath = _getFinalPath(path);
    final response = await storageFetch.postFile(
      '$url/object/$finalPath',
      file,
      fileOptions,
      options: FetchOptions(headers: headers),
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
    assert(retryAttempts == null || retryAttempts >= 0,
        'retryAttempts has to be greater or equal to 0');
    final finalPath = _getFinalPath(path);
    final response = await storageFetch.postBinaryFile(
      '$url/object/$finalPath',
      data,
      fileOptions,
      options: FetchOptions(headers: headers),
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
    assert(retryAttempts == null || retryAttempts >= 0,
        'retryAttempts has to be greater or equal to 0');

    final cleanPath = _removeEmptyFolders(path);
    final finalPath = _getFinalPath(cleanPath);
    var url = Uri.parse('${this.url}/object/upload/sign/$finalPath');
    url = url.replace(queryParameters: {'token': token});

    await storageFetch.putFile(
      url.toString(),
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
    assert(retryAttempts == null || retryAttempts >= 0,
        'retryAttempts has to be greater or equal to 0');

    final cleanPath = _removeEmptyFolders(path);
    final path0 = _getFinalPath(cleanPath);
    var url = Uri.parse('${this.url}/object/upload/sign/$path0');
    url = url.replace(queryParameters: {'token': token});

    await storageFetch.putBinaryFile(
      url.toString(),
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
  Future<SignedUploadURLResponse> createSignedUploadUrl(String path) async {
    final finalPath = _getFinalPath(path);

    final data = await storageFetch.post(
      '$url/object/upload/sign/$finalPath',
      {},
      options: FetchOptions(headers: headers),
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

    //   return { data: { signedUrl: url.toString(), path, token }, error: null }
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
    assert(retryAttempts == null || retryAttempts >= 0,
        'retryAttempts has to be greater or equal to 0');
    final finalPath = _getFinalPath(path);
    final response = await storageFetch.putFile(
      '$url/object/$finalPath',
      file,
      fileOptions,
      options: FetchOptions(headers: headers),
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
    assert(retryAttempts == null || retryAttempts >= 0,
        'retryAttempts has to be greater or equal to 0');
    final finalPath = _getFinalPath(path);
    final response = await storageFetch.putBinaryFile(
      '$url/object/$finalPath',
      data,
      fileOptions,
      options: FetchOptions(headers: headers),
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
  Future<String> move(String fromPath, String toPath) async {
    final options = FetchOptions(headers: headers);
    final response = await storageFetch.post(
      '$url/object/move',
      {
        'bucketId': bucketId,
        'sourceKey': fromPath,
        'destinationKey': toPath,
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
  Future<String> copy(String fromPath, String toPath) async {
    final options = FetchOptions(headers: headers);
    final response = await storageFetch.post(
      '$url/object/copy',
      {
        'bucketId': bucketId,
        'sourceKey': fromPath,
        'destinationKey': toPath,
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
  Future<String> createSignedUrl(
    String path,
    int expiresIn, {
    TransformOptions? transform,
  }) async {
    final finalPath = _getFinalPath(path);
    final options = FetchOptions(headers: headers);
    final response = await storageFetch.post(
      '$url/object/sign/$finalPath',
      {
        'expiresIn': expiresIn,
        if (transform != null) 'transform': transform.toQueryParams,
      },
      options: options,
    );
    final signedUrlPath = (response as Map<String, dynamic>)['signedURL'];
    final signedUrl = '$url$signedUrlPath';
    return signedUrl;
  }

  /// Create signed URLs to download files without requiring permissions. These
  /// URLs can be valid for a set number of seconds.
  ///
  /// [paths] is the file paths to be downloaded, including the current file
  /// names. For example: `createdSignedUrl(['folder/image.png', 'folder2/image2.png'])`.
  ///
  /// [expiresIn] is the number of seconds until the signed URLs expire. For
  /// example, `60` for URLs which are valid for one minute.
  ///
  /// A list of [SignedUrl]s is returned.
  Future<List<SignedUrl>> createSignedUrls(
    List<String> paths,
    int expiresIn,
  ) async {
    final options = FetchOptions(headers: headers);
    final response = await storageFetch.post(
      '$url/object/sign/$bucketId',
      {
        'expiresIn': expiresIn,
        'paths': paths,
      },
      options: options,
    );
    final List<SignedUrl> urls = (response as List).map((e) {
      return SignedUrl(
        // Prevents exceptions being thrown when null value is returned
        // https://github.com/supabase/storage-api/issues/353
        path: e['path'] ?? '',
        signedUrl: '$url${e['signedURL']}',
      );
    }).toList();
    return urls;
  }

  /// Downloads a file.
  ///
  /// [path] is the file path to be downloaded, including the path and file
  /// name. For example `download('folder/image.png')`.
  ///
  /// [transform] download a transformed variant of the image with the provided options
  Future<Uint8List> download(String path, {TransformOptions? transform}) async {
    final wantsTransformations = transform != null;
    final finalPath = _getFinalPath(path);
    final renderPath =
        wantsTransformations ? 'render/image/authenticated' : 'object';
    final queryParams = transform?.toQueryParams;
    final options = FetchOptions(headers: headers, noResolveJson: true);

    var fetchUrl = Uri.parse('$url/$renderPath/$finalPath');
    fetchUrl = fetchUrl.replace(queryParameters: queryParams);

    final response =
        await storageFetch.get(fetchUrl.toString(), options: options);
    return response as Uint8List;
  }

  /// Retrieve URLs for assets in public buckets
  ///
  /// [path] is the file path to be downloaded, including the current file name.
  /// For example `getPublicUrl('folder/image.png')`.
  ///
  /// [transform] adds image transformations parameters to the generated url.
  String getPublicUrl(
    String path, {
    TransformOptions? transform,
  }) {
    final finalPath = _getFinalPath(path);

    final wantsTransformation = transform != null;
    final renderPath = wantsTransformation ? 'render/image' : 'object';
    final transformationQuery = transform?.toQueryParams;

    var publicUrl = Uri.parse('$url/$renderPath/public/$finalPath');

    publicUrl = publicUrl.replace(queryParameters: transformationQuery);

    return publicUrl.toString();
  }

  /// Deletes files within the same bucket
  ///
  /// [paths] is an array of files to be deleted, including the path and file
  /// name. For example: `remove(['folder/image.png'])`.
  Future<List<FileObject>> remove(List<String> paths) async {
    final options = FetchOptions(headers: headers);
    final response = await storageFetch.delete(
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
    final options = FetchOptions(headers: headers);
    final response = await storageFetch.post(
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
