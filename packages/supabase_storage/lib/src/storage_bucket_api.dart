import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:supabase_storage/src/fetch.dart';
import 'package:supabase_storage/src/types.dart';
import 'package:supabase_common/supabase_common.dart';

/// API namespace for managing buckets, exposed on `SupabaseStorageClient`.
class StorageBucketApi {
  StorageBucketApi(
    this.url,
    Map<String, String> headers, {
    Client? httpClient,
    Duration? requestTimeout,
  }) : _headers = {...headers} {
    storageFetch = Fetch(httpClient, requestTimeout);
  }

  /// The storage endpoint requests are sent to.
  final String url;

  final Map<String, String> _headers;

  /// The headers sent with every request, as an unmodifiable view.
  ///
  /// Pass headers to the constructor instead of mutating them here. Use
  /// `SupabaseStorageClient.setHeader` to add one, or assign
  /// `SupabaseClient.headers` to replace them all on a managed client.
  Map<String, String> get headers => Map.unmodifiable(_headers);

  /// Sends requests to [url].
  @internal
  late final Fetch storageFetch;

  /// Replaces the request headers with [newHeaders].
  @internal
  void replaceHeaders(Map<String, String> newHeaders) {
    _headers
      ..clear()
      ..addAll(newHeaders);
  }

  Map<String, dynamic> _bucketPayload(String id, BucketOptions bucketOptions) {
    return {
      'id': id,
      'name': id,
      'public': ?bucketOptions.public,
      'file_size_limit': ?bucketOptions.fileSizeLimit,
      'allowed_mime_types': ?bucketOptions.allowedMimeTypes,
      'versioning_status': ?bucketOptions.versioningStatus?.snakeCase
          .toUpperCase(),
    };
  }

  /// Retrieves the details of all Storage buckets within an existing project.
  ///
  /// [options] optionally filters, sorts and paginates the returned buckets.
  /// Calling [listBuckets] without any options returns all buckets.
  Future<List<Bucket>> listBuckets([ListBucketsOptions? options]) async {
    final FetchOptions fetchOptions = FetchOptions(_headers);
    final queryParameters = options?.toQueryParameters() ?? const {};
    final uri = Uri.parse('$url/bucket').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final response = await storageFetch.get<List<dynamic>>(
      uri.toString(),
      options: fetchOptions,
    );
    return [
      for (final bucket in jsonObjectList(response, description: 'the buckets'))
        Bucket.fromJson(bucket),
    ];
  }

  /// Retrieves the details of an existing Storage bucket.
  ///
  /// [id] is the unique identifier of the bucket you would like to retrieve.
  Future<Bucket> getBucket(String id) async {
    final FetchOptions options = FetchOptions(_headers);
    final response = await storageFetch.get<Map<String, dynamic>>(
      '$url/bucket/${encodePathSegment(id)}',
      options: options,
    );
    return Bucket.fromJson(response);
  }

  /// Creates a new Storage bucket
  ///
  /// [id] is a unique identifier for the bucket you are creating.
  ///
  /// [bucketOptions] optionally makes the bucket public, limits what it
  /// accepts and turns on object versioning. Its
  /// [BucketOptions.versioningStatus] can only be [VersioningStatus.disabled]
  /// or [VersioningStatus.enabled] here.
  ///
  /// Use [getBucket] to read the created bucket back.
  Future<void> createBucket(
    String id, [
    BucketOptions bucketOptions = const BucketOptions(),
  ]) async {
    await storageFetch.post(
      '$url/bucket',
      _bucketPayload(id, bucketOptions),
      options: FetchOptions(_headers),
    );
  }

  /// Updates an existing Storage bucket
  ///
  /// [id] is the unique identifier of the bucket you are updating.
  ///
  /// [bucketOptions] sets the publicity of the bucket, what it accepts and
  /// its object versioning. Only the options that are set are changed. Its
  /// [BucketOptions.versioningStatus] can only be [VersioningStatus.enabled]
  /// or [VersioningStatus.suspended] here, and a bucket has to be enabled
  /// before it can be suspended.
  Future<void> updateBucket(
    String id,
    BucketOptions bucketOptions,
  ) async {
    await storageFetch.put(
      '$url/bucket/${encodePathSegment(id)}',
      _bucketPayload(id, bucketOptions),
      options: FetchOptions(_headers),
    );
  }

  /// Removes all objects inside a single bucket.
  ///
  /// [id] is the unique identifier of the bucket you would like to empty.
  ///
  /// The server queues the removal, so objects can still be listed for a
  /// while after this completes.
  Future<void> emptyBucket(String id) async {
    await storageFetch.post(
      '$url/bucket/${encodePathSegment(id)}/empty',
      {},
      options: FetchOptions(_headers),
    );
  }

  /// Deletes an existing bucket. A bucket can't be deleted with existing
  /// objects inside it. You must first clear the bucket using [emptyBucket].
  ///
  /// [id] is the unique identifier of the bucket you would like to delete.
  Future<void> deleteBucket(String id) async {
    await storageFetch.delete(
      '$url/bucket/${encodePathSegment(id)}',
      {},
      options: FetchOptions(_headers),
    );
  }

  /// Retrieves the lifecycle policy of the bucket [id].
  ///
  /// Throws a [StorageApiException] with the error code
  /// `NoSuchLifecycleConfiguration` when the bucket has no policy, and
  /// `FeatureNotEnabled` when the storage server does not have lifecycle
  /// policies enabled.
  Future<List<LifecycleRule>> getBucketLifecycle(String id) async {
    final response = await storageFetch.get<Map<String, dynamic>>(
      '$url/bucket/${encodePathSegment(id)}/lifecycle',
      options: FetchOptions(_headers),
    );
    return _lifecycleRules(response);
  }

  /// Replaces the lifecycle policy of the bucket [id] with [rules].
  ///
  /// [rules] is the whole policy, between 1 and 1000 rules, and overwrites
  /// whatever was stored before. Use [deleteBucketLifecycle] to remove the
  /// policy instead.
  ///
  /// Returns the stored rules, including the identifiers the server generated
  /// for the rules without one.
  Future<List<LifecycleRule>> updateBucketLifecycle(
    String id,
    List<LifecycleRule> rules,
  ) async {
    assert(
      rules.isNotEmpty && rules.length <= 1000,
      'A lifecycle policy has between 1 and 1000 rules',
    );
    final response = await storageFetch.put<Map<String, dynamic>>(
      '$url/bucket/${encodePathSegment(id)}/lifecycle',
      {'rules': rules.map((rule) => rule.toJson()).toList()},
      options: FetchOptions(_headers),
    );
    return _lifecycleRules(response);
  }

  /// Removes the lifecycle policy of the bucket [id].
  ///
  /// Succeeds even when the bucket has no policy.
  Future<void> deleteBucketLifecycle(String id) async {
    await storageFetch.delete(
      '$url/bucket/${encodePathSegment(id)}/lifecycle',
      {},
      options: FetchOptions(_headers),
    );
  }

  List<LifecycleRule> _lifecycleRules(Map<String, dynamic> response) {
    final rules =
        response.listOf<Map<String, dynamic>>('rules') ??
        (throw const FormatException(
          'Expected "rules" to be a list, got Null',
        ));
    return rules.map(LifecycleRule.fromJson).toList();
  }

  /// Purges the CDN cache for an entire bucket.
  ///
  /// Invalidates the CDN cache for every object in the bucket [id]. Maps to
  /// `DELETE /cdn/{bucket}` on the storage server.
  ///
  /// When [transformations] is `true`, only the resized/formatted variants are
  /// purged, leaving the original cached files intact. Otherwise both the
  /// originals and their resized/formatted variants are purged.
  ///
  /// Requires the service-role key and the tenant `purgeCache` feature to be
  /// enabled on the storage server.
  Future<void> purgeBucketCache(
    String id, {
    bool transformations = false,
  }) async {
    var requestUrl = Uri.parse('$url/cdn/${encodePathSegment(id)}');
    if (transformations) {
      requestUrl = requestUrl.replace(
        queryParameters: {'transformations': 'true'},
      );
    }
    await storageFetch.delete(
      requestUrl.toString(),
      {},
      options: FetchOptions(_headers),
    );
  }

  /// Purges the CDN cache for every bucket in the project.
  ///
  /// Invalidates the CDN cache for every object in every bucket. Maps to
  /// `DELETE /cdn/` on the storage server.
  ///
  /// When [transformations] is `true`, only the resized/formatted variants are
  /// purged, leaving the original cached files intact. Otherwise both the
  /// originals and their resized/formatted variants are purged.
  ///
  /// Requires the service-role key and the tenant `purgeCache` feature to be
  /// enabled on the storage server.
  Future<void> purgeProjectCache({bool transformations = false}) async {
    await storageFetch.delete(
      Uri.parse('$url/cdn/')
          .replace(
            queryParameters: transformations
                ? const {'transformations': 'true'}
                : null,
          )
          .toString(),
      {},
      options: FetchOptions(_headers),
    );
  }

  /// Creates a new analytics bucket backed by the Apache Iceberg table format.
  ///
  /// [id] is the unique identifier for the bucket you are creating.
  Future<AnalyticsBucket> createAnalyticsBucket(String id) async {
    final FetchOptions options = FetchOptions(_headers);
    final response = await storageFetch.post<Map<String, dynamic>>(
      '$url/iceberg/bucket',
      {'name': id},
      options: options,
    );
    return AnalyticsBucket.fromJson(response);
  }

  /// Retrieves the details of all analytics buckets within an existing project.
  ///
  /// [options] optionally filters, sorts and paginates the returned buckets.
  /// Calling [listAnalyticsBuckets] without any options returns all buckets.
  Future<List<AnalyticsBucket>> listAnalyticsBuckets([
    ListBucketsOptions? options,
  ]) async {
    final FetchOptions fetchOptions = FetchOptions(_headers);
    final queryParameters = options?.toQueryParameters() ?? const {};
    final uri = Uri.parse('$url/iceberg/bucket').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final response = await storageFetch.get<List<dynamic>>(
      uri.toString(),
      options: fetchOptions,
    );
    return [
      for (final bucket in jsonObjectList(
        response,
        description: 'the analytics buckets',
      ))
        AnalyticsBucket.fromJson(bucket),
    ];
  }

  /// Deletes an existing analytics bucket. A bucket can't be deleted while it
  /// still contains namespaces or tables.
  ///
  /// [id] is the unique identifier of the bucket you would like to delete.
  Future<void> deleteAnalyticsBucket(String id) async {
    await storageFetch.delete(
      '$url/iceberg/bucket/${encodePathSegment(id)}',
      {},
      options: FetchOptions(_headers),
    );
  }
}
