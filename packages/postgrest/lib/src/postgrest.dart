import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:postgrest/postgrest.dart';
import 'package:postgrest/src/constants.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

/// A PostgREST api client written in Dartlang. The goal of this library is to make an "ORM-like" restful interface.
class PostgrestClient {
  final String url;
  final Map<String, String> headers;
  final String? _schema;
  final Client? httpClient;
  final YAJsonIsolate _isolate;
  final bool _hasCustomIsolate;
  final bool retryEnabled;
  final Duration Function(int attempt)? _retryDelay;

  /// Optional timeout in milliseconds for PostgREST requests. When set,
  /// requests automatically abort after this duration to prevent indefinite hangs.
  final int? timeout;

  /// Maximum URL length in characters before a warning is logged. Defaults to 8000.
  /// Protects against exceeding server URL limits with large queries.
  final int urlLengthLimit;

  final _log = Logger('supabase.postgrest');

  /// To create a [PostgrestClient], you need to provide an [url] endpoint.
  ///
  /// You can also provide custom [headers] and [_schema] if needed
  /// ```dart
  /// PostgrestClient(REST_URL)
  /// PostgrestClient(REST_URL, headers: {'apikey': 'foo'})
  /// ```
  ///
  /// [httpClient] is optional and can be used to provide a custom http client
  ///
  /// [isolate] is optional and can be used to provide a custom isolate, which is used for heavy json computation
  ///
  /// [retryEnabled] controls whether automatic retries are performed for GET and
  /// HEAD requests that fail with HTTP 503, HTTP 520, or a network error. Defaults to `true`.
  /// Use [PostgrestBuilder.retry] to override this per request.
  ///
  /// [timeout] is optional and can be used to set a timeout in milliseconds for requests
  ///
  /// [urlLengthLimit] is optional and can be used to set the maximum URL length before a warning is logged. Defaults to 8000.
  PostgrestClient(
    this.url, {
    Map<String, String>? headers,
    String? schema,
    this.httpClient,
    YAJsonIsolate? isolate,
    this.retryEnabled = true,
    @visibleForTesting Duration Function(int attempt)? retryDelay,
    this.timeout,
    this.urlLengthLimit = 8000,
  })  : _schema = schema,
        headers = {...defaultHeaders, if (headers != null) ...headers},
        _isolate = isolate ?? (YAJsonIsolate()..initialize()),
        _hasCustomIsolate = isolate != null,
        _retryDelay = retryDelay {
    _log.config('Initialize PostgrestClient with url: $url, schema: $_schema');
    _log.finest('Initialize with headers: $headers');
  }

  /// Authenticates the request with JWT.
  @Deprecated("Use setAuth() instead")
  PostgrestClient auth(String token) {
    headers['Authorization'] = 'Bearer $token';
    return this;
  }

  PostgrestClient setAuth(String? token) {
    _log.finest("setAuth with: $token");
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
      url: Uri.parse(url),
      headers: {...headers},
      schema: _schema,
      httpClient: httpClient,
      isolate: _isolate,
      retryEnabled: retryEnabled,
      retryDelay: _retryDelay,
      timeout: timeout,
      urlLengthLimit: urlLengthLimit,
    );
  }

  /// Select a schema to query or perform an function (rpc) call.
  ///
  /// The schema needs to be on the list of exposed schemas inside Supabase.
  PostgrestClient schema(String schema) {
    return PostgrestClient(
      url,
      headers: {...headers},
      schema: schema,
      httpClient: httpClient,
      isolate: _isolate,
      retryEnabled: retryEnabled,
      retryDelay: _retryDelay,
      timeout: timeout,
      urlLengthLimit: urlLengthLimit,
    );
  }

  /// {@template postgrest_rpc}
  /// Performs a stored procedure call.
  ///
  /// [fn] is the name of the function to call.
  ///
  /// [params] is an optional object to pass as arguments to the function call.
  ///
  /// When [get] is set to `true`, the function will be called with read-only
  /// access mode.
  ///
  /// {@endtemplate}
  ///
  /// ```dart
  /// supabase.rpc('get_status', params: {'name_param': 'supabot'})
  /// ```
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map? params,
    bool get = false,
  }) {
    final url = '${this.url}/rpc/$fn';
    return PostgrestRpcBuilder(
      url,
      headers: {...headers},
      schema: _schema,
      httpClient: httpClient,
      isolate: _isolate,
      retryEnabled: retryEnabled,
      retryDelay: _retryDelay,
      timeout: timeout,
      urlLengthLimit: urlLengthLimit,
    ).rpc(params, get);
  }

  Future<void> dispose() async {
    _log.fine("dispose PostgrestClient");
    if (!_hasCustomIsolate) {
      return _isolate.dispose();
    }
  }
}
