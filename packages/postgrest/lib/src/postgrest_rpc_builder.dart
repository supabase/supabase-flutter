part of 'postgrest_builder.dart';

/// Builds a stored procedure call.
///
/// Like [PostgrestQueryBuilder] it is not executable itself: [rpc] has to be
/// called to obtain an executable builder.
@immutable
class PostgrestRpcBuilder {
  PostgrestRpcBuilder(
    String url, {
    Map<String, String>? headers,
    String? schema,
    Client? httpClient,
    required AsyncJsonCodec jsonCodec,
    SupabaseRetryOptions retryOptions = const SupabaseRetryOptions(),
    Duration? requestTimeout,
  }) : _config = _RequestConfig(
         url: Uri.parse(url),
         headers: {...?headers},
         schema: schema,
         httpClient: httpClient,
         jsonCodec: jsonCodec,
         retry: retryOptions,
         requestTimeout: requestTimeout,
       );
  final _RequestConfig _config;

  /// Performs a database function call.
  ///
  /// [params] is an optional object to pass as arguments to the function call.
  ///
  /// When [get] is set to `true`, [params] must be a [Map] or `null`, and the
  /// function is called with a `GET` request in read-only access mode, with
  /// [params] as query parameters. A call with an argument PostgREST would
  /// read as an option of the request, such as `limit`, a `null` value, or a
  /// value it would read as a filter, such as `eq.foo`, is sent as a `POST`
  /// instead and not retried.
  PostgrestFilterBuilder<T> rpc<T>([
    Object? params,
    bool get = false,
  ]) {
    final query = get && postgrestArgumentsFitQuery(params);
    return _filterBuilder(
      _config.copyWith(
        method: query ? HttpMethod.get : HttpMethod.post,
        url: query ? _appendArguments(_config.url, params) : null,
        body: params,
        functionCall: true,
      ),
    );
  }
}

/// [url] with each of the function arguments in [params] appended as a query
/// parameter, for a call sent without a body.
Uri _appendArguments(Uri url, Object? params) {
  if (params == null) return url;
  if (params is! Map) {
    throw ArgumentError.value(params, 'params', 'argument must be a Map');
  }
  var withArguments = url;
  for (final entry in params.entries) {
    assert(
      entry.key is String,
      "RPC params map keys must be of type String",
    );
    withArguments = withArguments.appendSearchParameters(
      entry.key.toString(),
      renderPostgrestQueryValue(entry.value),
    );
  }
  return withArguments;
}
