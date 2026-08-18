part of 'postgrest_builder.dart';

class PostgrestRpcBuilder
    extends RawPostgrestBuilder<dynamic, dynamic, dynamic> {
  PostgrestRpcBuilder(
    String url, {
    Map<String, String>? headers,
    String? schema,
    Client? httpClient,
    required YAJsonIsolate isolate,
    PostgrestRetryOptions retryOptions = const PostgrestRetryOptions(),
    Duration? requestTimeout,
    Future<void>? abortSignal,
  }) : super(
         PostgrestBuilder(
           url: Uri.parse(url),
           headers: headers ?? {},
           schema: schema,
           httpClient: httpClient,
           isolate: isolate,
           retryOptions: retryOptions,
           requestTimeout: requestTimeout,
           abortSignal: abortSignal,
         ),
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
    var newUrl = _url;
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
              ? '{${_cleanFilterArray(value)}}'
              : value;
          newUrl = appendSearchParameters(
            key.toString(),
            '$formattedValue',
            newUrl,
          );
        }
      } else {
        throw ArgumentError.value(params, 'params', 'argument must be a Map');
      }
    } else {
      method = HttpMethod.post;
    }

    return PostgrestFilterBuilder(
      _copyWithType(
        method: method,
        url: newUrl,
        body: params,
      ),
    );
  }
}
