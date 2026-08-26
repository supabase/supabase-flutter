import 'package:http/http.dart';
import 'package:iceberg/iceberg.dart';
import 'package:supabase_storage/src/logger.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:supabase_storage/src/storage_constants.dart';
import 'package:supabase_storage/src/storage_bucket_api.dart';
import 'package:supabase_storage/src/storage_file_api.dart';
import 'package:supabase_storage/src/vector_client.dart';
import 'package:supabase_storage/src/version.dart';

class SupabaseStorageClient extends StorageBucketApi {
  /// To create a [SupabaseStorageClient], you need to provide an [url] and
  /// [headers].
  ///
  /// ```dart
  /// SupabaseStorageClient(STORAGE_URL, {'apikey': 'foo'});
  /// ```
  ///
  /// [httpClient] is optional and can be used to provide a custom http client
  ///
  /// [retryOptions] configures how an upload that failed due to a network
  /// interruption is retried. Uploads are not retried unless
  /// [SupabaseRetryOptions.count] is above zero, since repeating one costs
  /// bandwidth. With the default backoff the delays are 400 ms, 800 ms,
  /// 1600 ms and so on, each randomized by up to 25%, capped at 30 seconds.
  ///
  /// Override it for a single upload with the `retryOptions` parameter of
  /// [StorageFileApi.upload] and its siblings.
  ///
  /// [accessToken] is resolved before every request and sent as
  /// `Authorization: Bearer <token>`. Use it when the token rotates, for
  /// example a session token that is refreshed. Returning `null` sends no
  /// bearer token, and it is resolved again for every upload retry. A header
  /// set with [setHeader] still wins over it.
  ///
  /// [useNewHostname] controls whether legacy storage URLs are rewritten to use
  /// the dedicated storage host (`<ref>.storage.supabase.co`). Set to `true`
  /// only if your project has the dedicated storage host enabled; otherwise
  /// every storage request will fail with an `Invalid Storage request` error.
  /// Defaults to `false` (opt-in).
  SupabaseStorageClient(
    String url,
    Map<String, String> headers, {
    Client? httpClient,
    this.retryOptions = const SupabaseRetryOptions(count: 0),
    bool useNewHostname = false,
    Future<String?> Function()? accessToken,
  }) : assert(
         accessToken == null || headers.header('Authorization') == null,
         'Pass either an Authorization header or accessToken, not both: the '
         'header would win over the resolved token on every request.',
       ),
       super(
         useNewHostname ? _transformStorageUrl(url) : url,
         {...StorageConstants.defaultHeaders, ...headers},
         httpClient: accessToken == null
             ? httpClient
             : AccessTokenClient(accessToken, httpClient),
       ) {
    storageLogger.config(
      'Initialize SupabaseStorageClient v$version with url: '
      '${Uri.parse(url).redacted}, '
      'retryOptions: $retryOptions',
    );
    storageLogger.finest('Initialize with headers: ${headers.redacted}');
  }

  /// Configures the automatic retry of uploads.
  final SupabaseRetryOptions retryOptions;

  /// Transforms legacy storage URLs to use the dedicated storage host.
  ///
  /// If legacy URI is used, replace with new storage host (disables request
  /// buffering to allow > 50GB uploads). "project-ref.supabase.co/storage/v1"
  /// becomes "project-ref.storage.supabase.co/v1"
  static String _transformStorageUrl(String url) {
    final uri = Uri.parse(url);
    final hostname = uri.host;

    // Check if it's a Supabase host (supabase.co, supabase.in, or supabase.red)
    final isSupabaseHost = RegExp(r'supabase\.(co|in|red)$').hasMatch(hostname);

    // If it's a legacy storage URL, transform it
    const legacyStoragePrefix = '/storage';
    if (isSupabaseHost &&
        !hostname.contains('storage.supabase.') &&
        uri.path.startsWith(legacyStoragePrefix)) {
      // Remove /storage from pathname
      final newPath = uri.path.substring(legacyStoragePrefix.length);
      // Replace supabase. with storage.supabase. in hostname
      final newHostname = hostname.replaceAll('supabase.', 'storage.supabase.');

      // Reconstruct the URI
      return uri
          .replace(
            host: newHostname,
            path: newPath,
          )
          .toString();
    }

    return url;
  }

  /// Perform file operation in a bucket.
  ///
  /// [id] The bucket id to operate on.
  StorageFileApi from(String id) {
    return StorageFileApi(
      url,
      headers,
      id,
      retryOptions,
      storageFetch,
    );
  }

  /// Returns an Iceberg REST Catalog client for an analytics bucket.
  ///
  /// [bucketId] is the identifier of the analytics bucket (the warehouse) whose
  /// namespaces and tables you want to manage.
  ///
  /// ```dart
  /// final catalog = storage.analyticsCatalog('my-analytics-bucket');
  /// await catalog.createNamespace(['analytics']);
  /// ```
  IcebergRestCatalog analyticsCatalog(
    String bucketId, {
    List<AccessDelegation>? accessDelegation,
  }) {
    return IcebergRestCatalog(
      baseUrl: '$url/iceberg',
      headers: headers,
      warehouse: bucketId,
      accessDelegation: accessDelegation,
      httpClient: storageFetch.httpClient,
    );
  }

  /// Access the Storage Vectors API to manage vector buckets, indexes and the
  /// vectors stored inside them.
  ///
  /// This API is part of a public alpha and may not be available to every
  /// project.
  ///
  /// ```dart
  /// final vectors = storage.vectors;
  /// await vectors.createBucket('embeddings');
  /// ```
  @experimental
  SupabaseVectorsClient get vectors => SupabaseVectorsClient(
    '$url/vector',
    headers,
    storageFetch,
  );

  /// Sets an HTTP header for subsequent requests.
  ///
  /// Instances of [StorageFileApi] already obtained through [from] hold their
  /// own copy of the headers, so only calls to [from] made after this one will
  /// include the new header. Returns this for method chaining.
  ///
  /// ```dart
  /// storage.setHeader('x-custom-header', 'value').from('bucket').upload(...);
  /// ```
  SupabaseStorageClient setHeader(String key, String value) {
    replaceHeaders({...headers, key: value});
    return this;
  }
}
