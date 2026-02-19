import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:storage_client/src/constants.dart';
import 'package:storage_client/src/storage_bucket_api.dart';
import 'package:storage_client/src/storage_file_api.dart';
import 'package:storage_client/src/version.dart';

class SupabaseStorageClient extends StorageBucketApi {
  final int _defaultRetryAttempts;
  final _log = Logger('supabase.storage');

  /// To create a [SupabaseStorageClient], you need to provide an [url] and [headers].
  ///
  /// ```dart
  /// SupabaseStorageClient(STORAGE_URL, {'apikey': 'foo'});
  /// ```
  ///
  /// [httpClient] is optional and can be used to provide a custom http client
  ///
  /// [retryAttempts] specifies how many retry attempts there should be to
  ///  upload a file when failed due to network interruption.
  ///
  /// Time between each retries are set as the following:
  ///  1. 400 ms +/- 25%
  ///  2. 800 ms +/- 25%
  ///  3. 1600 ms +/- 25%
  ///  4. 3200 ms +/- 25%
  ///  5. 6400 ms +/- 25%
  ///  6. 12800 ms +/- 25%
  ///  7. 25600 ms +/- 25%
  ///  8. 30000 ms +/- 25%
  ///
  /// Anything beyond the 8th try will have 30 second delay.
  SupabaseStorageClient(
    String url,
    Map<String, String> headers, {
    Client? httpClient,
    int retryAttempts = 0,
  })  : assert(
          retryAttempts >= 0,
          'retryAttempts has to be greater than or equal to 0',
        ),
        _defaultRetryAttempts = retryAttempts,
        super(
          _transformStorageUrl(url),
          {...Constants.defaultHeaders, ...headers},
          httpClient: httpClient,
        ) {
    _log.config(
        'Initialize SupabaseStorageClient v$version with url: $url, retryAttempts: $_defaultRetryAttempts');
    _log.finest('Initialize with headers: $headers');
  }

  /// Transforms legacy storage URLs to use the dedicated storage host.
  ///
  /// If legacy URI is used, replace with new storage host (disables request buffering to allow > 50GB uploads).
  /// "project-ref.supabase.co/storage/v1" becomes "project-ref.storage.supabase.co/v1"
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
      _defaultRetryAttempts,
      storageFetch,
    );
  }

  void setAuth(String jwt) {
    headers['Authorization'] = 'Bearer $jwt';
  }

  /// Sets an HTTP header for subsequent requests.
  ///
  /// Creates a shallow copy of headers to avoid mutating shared state.
  /// Returns this for method chaining.
  ///
  /// ```dart
  /// storage.setHeader('x-custom-header', 'value').from('bucket').upload(...);
  /// ```
  SupabaseStorageClient setHeader(String key, String value) {
    headers[key] = value;
    return this;
  }
}
