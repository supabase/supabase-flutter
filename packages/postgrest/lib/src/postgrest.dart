import 'package:http/http.dart';
import 'package:postgrest/postgrest.dart';
import 'package:postgrest/src/constants.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

/// A PostgREST api client written in Dartlang. The goal of this library is to make an "ORM-like" restful interface.
class PostgrestClient {
  final String url;
  final Map<String, String> headers;
  final String? schema;
  final Client? httpClient;
  final YAJsonIsolate _isolate;
  final bool _hasCustomIsolate;

  /// To create a [PostgrestClient], you need to provide an [url] endpoint.
  ///
  /// You can also provide custom [headers] and [schema] if needed
  /// ```dart
  /// PostgrestClient(REST_URL)
  /// PostgrestClient(REST_URL, headers: {'apikey': 'foo'})
  /// ```
  ///
  /// [httpClient] is optional and can be used to provide a custom http client
  ///
  /// [isolate] is optional and can be used to provide a custom isolate, which is used for heavy json computation
  PostgrestClient(
    this.url, {
    Map<String, String>? headers,
    this.schema,
    this.httpClient,
    YAJsonIsolate? isolate,
  })  : headers = {...defaultHeaders, if (headers != null) ...headers},
        _isolate = isolate ?? (YAJsonIsolate()..initialize()),
        _hasCustomIsolate = isolate != null;

  /// Authenticates the request with JWT.
  @Deprecated("Use setAuth() instead")
  PostgrestClient auth(String token) {
    headers['Authorization'] = 'Bearer $token';
    return this;
  }

  PostgrestClient setAuth(String? token) {
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      headers.remove('Authorization');
    }
    return this;
  }

  /// Perform a table operation.
  PostgrestQueryBuilder<void> from(String table) {
    final url = '${this.url}/$table';
    return PostgrestQueryBuilder<void>(
      url,
      headers: {...headers},
      schema: schema,
      httpClient: httpClient,
      isolate: _isolate,
    );
  }

  /// Perform a stored procedure call.
  ///
  /// ```dart
  /// postgrest.rpc('get_status', params: {'name_param': 'supabot'})
  /// ```
  PostgrestFilterBuilder rpc(
    String fn, {
    Map? params,
    FetchOptions options = const FetchOptions(),
  }) {
    final url = '${this.url}/rpc/$fn';
    return PostgrestRpcBuilder(
      url,
      headers: {...headers},
      schema: schema,
      httpClient: httpClient,
      options: options,
      isolate: _isolate,
    ).rpc(params, options);
  }

  Future<void> dispose() async {
    if (!_hasCustomIsolate) {
      return _isolate.dispose();
    }
  }
}
