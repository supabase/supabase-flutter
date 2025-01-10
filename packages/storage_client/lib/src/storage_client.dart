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
          url,
          {...Constants.defaultHeaders, ...headers},
          httpClient: httpClient,
        ) {
    _log.config(
        'Initialize SupabaseStorageClient v$version with url: $url, retryAttempts: $_defaultRetryAttempts');
    _log.finest('Initialize with headers: $headers');
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
}
