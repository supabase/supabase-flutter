import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:storage_client/src/fetch.dart';
import 'package:storage_client/src/types.dart';

class StorageBucketApi {
  final String url;
  final Map<String, String> headers;
  @internal
  late Fetch storageFetch;

  StorageBucketApi(this.url, this.headers, {Client? httpClient}) {
    storageFetch = Fetch(httpClient);
  }

  /// Retrieves the details of all Storage buckets within an existing project.
  Future<List<Bucket>> listBuckets() async {
    final FetchOptions options = FetchOptions(headers: headers);
    final response = await storageFetch.get('$url/bucket', options: options);
    final buckets = List<Bucket>.from(
      (response as List).map(
        (value) => Bucket.fromJson(value),
      ),
    );
    return buckets;
  }

  /// Retrieves the details of an existing Storage bucket.
  ///
  /// [id] is the unique identifier of the bucket you would like to retrieve.
  Future<Bucket> getBucket(String id) async {
    final FetchOptions options = FetchOptions(headers: headers);
    final response =
        await storageFetch.get('$url/bucket/$id', options: options);
    return Bucket.fromJson(response);
  }

  /// Creates a new Storage bucket
  ///
  /// [id] is a unique identifier for the bucket you are creating.
  ///
  /// [bucketOptions] is a parameter to optionally make the bucket public.
  ///
  /// It returns the newly created bucket it. To get the bucket reference, use
  /// [getBucket]:
  ///
  /// ```dart
  /// void bucket() async {
  ///   final newBucketId = await createBucket('images');
  ///   final bucket = await Bucket(newBucketId);
  ///   print('${bucket.id}');
  /// }
  /// ```
  Future<String> createBucket(
    String id, [
    BucketOptions bucketOptions = const BucketOptions(public: false),
  ]) async {
    final FetchOptions options = FetchOptions(headers: headers);
    final response = await storageFetch.post(
      '$url/bucket',
      {
        'id': id,
        'name': id,
        'public': bucketOptions.public,
        if (bucketOptions.fileSizeLimit != null)
          'file_size_limit': bucketOptions.fileSizeLimit,
        if (bucketOptions.allowedMimeTypes != null)
          'allowed_mime_types': bucketOptions.allowedMimeTypes,
      },
      options: options,
    );
    final bucketId = (response as Map<String, dynamic>)['name'] as String;
    return bucketId;
  }

  /// Updates a new Storage bucket
  ///
  /// [id] is a unique identifier for the bucket you are creating.
  ///
  /// [bucketOptions] is a parameter to set the publicity of the bucket.
  Future<String> updateBucket(
    String id,
    BucketOptions bucketOptions,
  ) async {
    final FetchOptions options = FetchOptions(headers: headers);
    final response = await storageFetch.put(
      '$url/bucket/$id',
      {
        'id': id,
        'name': id,
        'public': bucketOptions.public,
        if (bucketOptions.fileSizeLimit != null)
          'file_size_limit': bucketOptions.fileSizeLimit,
        if (bucketOptions.allowedMimeTypes != null)
          'allowed_mime_types': bucketOptions.allowedMimeTypes,
      },
      options: options,
    );
    final message = (response as Map<String, dynamic>)['message'] as String;
    return message;
  }

  /// Removes all objects inside a single bucket.
  ///
  /// [id] is the unique identifier of the bucket you would like to empty.
  Future<String> emptyBucket(String id) async {
    final FetchOptions options = FetchOptions(headers: headers);
    final response =
        await storageFetch.post('$url/bucket/$id/empty', {}, options: options);
    return (response as Map<String, dynamic>)['message'] as String;
  }

  /// Deletes an existing bucket. A bucket can't be deleted with existing
  /// objects inside it. You must first clear the bucket using [emptyBucket].
  ///
  /// [id] is the unique identifier of the bucket you would like to delete.
  Future<String> deleteBucket(String id) async {
    final FetchOptions options = FetchOptions(headers: headers);
    final response = await storageFetch.delete(
      '$url/bucket/$id',
      {},
      options: options,
    );
    return (response as Map<String, dynamic>)['message'] as String;
  }
}
