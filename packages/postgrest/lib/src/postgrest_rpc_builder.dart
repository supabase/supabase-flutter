part of 'postgrest_builder.dart';

class PostgrestRpcBuilder extends RawPostgrestBuilder {
  PostgrestRpcBuilder(
    String url, {
    Map<String, String>? headers,
    String? schema,
    Client? httpClient,
    required YAJsonIsolate isolate,
    bool retryEnabled = true,
    Duration Function(int attempt)? retryDelay,
  }) : super(
          PostgrestBuilder(
            url: Uri.parse(url),
            headers: headers ?? {},
            schema: schema,
            httpClient: httpClient,
            isolate: isolate,
            retryEnabled: retryEnabled,
            retryDelay: retryDelay,
          ),
        );

  /// {@macro postgrest_rpc}
  PostgrestFilterBuilder<T> rpc<T>([
    Object? params,
    bool get = false,
  ]) {
    var newUrl = _url;
    final _HttpMethod method;
    if (get) {
      method = _HttpMethod.get;
      if (params is Map) {
        for (final entry in params.entries) {
          assert(entry.key is String,
              "RPC params map keys must be of type String");

          final MapEntry(:key, :value) = entry;
          final formattedValue =
              value is List ? '{${_cleanFilterArray(value)}}' : value;
          newUrl =
              appendSearchParams(key.toString(), '$formattedValue', newUrl);
        }
      } else {
        throw ArgumentError.value(params, 'params', 'argument must be a Map');
      }
    } else {
      method = _HttpMethod.post;
    }

    return PostgrestFilterBuilder(_copyWithType(
      method: method,
      url: newUrl,
      body: params,
    ));
  }
}
