import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:storage_client/src/fetch.dart';
import 'package:storage_client/src/types.dart';
import 'package:supabase_common/supabase_common.dart';

class StorageBucketApi {
  final String url;
  final Map<String, String> headers;
  @internal
  late Fetch storageFetch;

  StorageBucketApi(this.url, this.headers, {Client? httpClient}) {
    storageFetch = Fetch(httpClient);
  }

  Map<String, dynamic> _bucketPayload(String id, BucketOptions bucketOptions) {
    return {
      'id': id,
      'name': id,
      'public': bucketOptions.public,
      'file_size_limit': ?bucketOptions.fileSizeLimit,
      'allowed_mime_types': ?bucketOptions.allowedMimeTypes,
    };
  }

  /// Retrieves the details of all Storage buckets within an existing project.
  ///
  /// [options] optionally filters, sorts and paginates the returned buckets.
  /// Calling [listBuckets] without any options returns all buckets.
  Future<List<Bucket>> listBuckets([ListBucketsOptions? options]) async {
    final FetchOptions fetchOptions = FetchOptions(headers);
    final queryParameters = options?.toQueryParameters() ?? const {};
    final uri = Uri.parse('$url/bucket').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final response = await storageFetch.get(
      uri.toString(),
      options: fetchOptions,
    );
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
    final FetchOptions options = FetchOptions(headers);
    final response = await storageFetch.get(
      '$url/bucket/$id',
      options: options,
    );
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
    final FetchOptions options = FetchOptions(headers);
    final response = await storageFetch.post(
      '$url/bucket',
      _bucketPayload(id, bucketOptions),
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
    final FetchOptions options = FetchOptions(headers);
    final response = await storageFetch.put(
      '$url/bucket/$id',
      _bucketPayload(id, bucketOptions),
      options: options,
    );
    final message = (response as Map<String, dynamic>)['message'] as String;
    return message;
  }

  /// Removes all objects inside a single bucket.
  ///
  /// [id] is the unique identifier of the bucket you would like to empty.
  Future<String> emptyBucket(String id) async {
    final FetchOptions options = FetchOptions(headers);
    final response = await storageFetch.post(
      '$url/bucket/$id/empty',
      {},
      options: options,
    );
    return (response as Map<String, dynamic>)['message'] as String;
  }

  /// Deletes an existing bucket. A bucket can't be deleted with existing
  /// objects inside it. You must first clear the bucket using [emptyBucket].
  ///
  /// [id] is the unique identifier of the bucket you would like to delete.
  Future<String> deleteBucket(String id) async {
    final FetchOptions options = FetchOptions(headers);
    final response = await storageFetch.delete(
      '$url/bucket/$id',
      {},
      options: options,
    );
    return (response as Map<String, dynamic>)['message'] as String;
  }

  /// Purges the CDN cache for an entire bucket.
  ///
  /// Invalidates the CDN cache for every object in the bucket [id]. Maps to
  /// `DELETE /cdn/{bucket}` on the storage server.
  ///
  /// When [transformations] is `true`, only the resized/formatted variants are
  /// purged, leaving the original cached files intact. When omitted the bucket
  /// cache is purged.
  ///
  /// Requires the service-role key and the tenant `purgeCache` feature to be
  /// enabled on the storage server.
  Future<String> purgeBucketCache(
    String id, {
    bool transformations = false,
  }) async {
    var requestUrl = Uri.parse('$url/cdn/$id');
    if (transformations) {
      requestUrl = requestUrl.replace(
        queryParameters: {'transformations': 'true'},
      );
    }
    final response = await storageFetch.delete(
      requestUrl.toString(),
      {},
      options: FetchOptions(headers),
    );
    return (response as Map<String, dynamic>)['message'] as String;
  }

  /// Creates a new analytics bucket backed by the Apache Iceberg table format.
  ///
  /// [id] is the unique identifier for the bucket you are creating.
  Future<AnalyticsBucket> createAnalyticsBucket(String id) async {
    final FetchOptions options = FetchOptions(headers);
    final response = await storageFetch.post(
      '$url/iceberg/bucket',
      {'name': id},
      options: options,
    );
    return AnalyticsBucket.fromJson(response as Map<String, dynamic>);
  }

  /// Retrieves the details of all analytics buckets within an existing project.
  ///
  /// [options] optionally filters, sorts and paginates the returned buckets.
  /// Calling [listAnalyticsBuckets] without any options returns all buckets.
  Future<List<AnalyticsBucket>> listAnalyticsBuckets([
    ListBucketsOptions? options,
  ]) async {
    final FetchOptions fetchOptions = FetchOptions(headers);
    final queryParameters = options?.toQueryParameters() ?? const {};
    final uri = Uri.parse('$url/iceberg/bucket').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final response = await storageFetch.get(
      uri.toString(),
      options: fetchOptions,
    );
    return (response as List)
        .map((value) => AnalyticsBucket.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  /// Deletes an existing analytics bucket. A bucket can't be deleted while it
  /// still contains namespaces or tables.
  ///
  /// [id] is the unique identifier of the bucket you would like to delete.
  Future<String> deleteAnalyticsBucket(String id) async {
    final FetchOptions options = FetchOptions(headers);
    final response = await storageFetch.delete(
      '$url/iceberg/bucket/$id',
      {},
      options: options,
    );
    return (response as Map<String, dynamic>)['message'] as String;
  }
}
