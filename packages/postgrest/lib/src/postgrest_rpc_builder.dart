part of 'postgrest_builder.dart';

/// Builds a stored procedure call.
///
/// Like [PostgrestQueryBuilder] it is not executable itself: [rpc] has to be
/// called to obtain an executable builder.
@immutable
class PostgrestRpcBuilder {
  final _RequestConfig _config;

  PostgrestRpcBuilder(
    String url, {
    Map<String, String>? headers,
    String? schema,
    Client? httpClient,
    required YAJsonIsolate isolate,
    SupabaseRetryOptions retryOptions = const SupabaseRetryOptions(),
    Duration? requestTimeout,
  }) : _config = _RequestConfig(
         url: Uri.parse(url),
         headers: {...?headers},
         schema: schema,
         httpClient: httpClient,
         isolate: isolate,
         retry: retryOptions,
         requestTimeout: requestTimeout,
       );

  /// Performs a database function call.
  ///
  /// [params] is an optional object to pass as arguments to the function call.
  ///
  /// When [get] is set to `true`, [params] must be a [Map], and the function
  /// is called with read-only access mode.
  PostgrestFilterBuilder<T> rpc<T>([
    Object? params,
    bool get = false,
  ]) {
    var newUrl = _config.url;
    final HttpMethod method;
    if (get) {
      method = HttpMethod.get;
      if (params is Map) {
        for (final entry in params.entries) {
          assert(
            entry.key is String,
            "RPC params map keys must be of type String",
          );

          final MapEntry(:key, :value) = entry;
          final formattedValue = value is List
              ? '{${_cleanFilterList(value)}}'
              : value;
          newUrl = newUrl.appendSearchParameters(
            key.toString(),
            '$formattedValue',
          );
        }
      } else {
        throw ArgumentError.value(params, 'params', 'argument must be a Map');
      }
    } else {
      method = HttpMethod.post;
    }

    return _filterBuilder(
      _config.copyWith(
        method: method,
        url: newUrl,
        body: params,
      ),
    );
  }
}
