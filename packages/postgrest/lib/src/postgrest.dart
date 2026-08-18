import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:postgrest/postgrest.dart';
import 'package:postgrest/src/constants.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

/// A PostgREST api client written in Dartlang. The goal of this library is to
/// make an "ORM-like" restful interface.
class PostgrestClient {
  final String url;
  final Map<String, String> headers;
  final String? _schema;
  final Client? httpClient;
  final YAJsonIsolate _isolate;
  final bool _hasCustomIsolate;

  /// Configures the automatic retry of GET and HEAD requests.
  final PostgrestRetryOptions retryOptions;

  final Duration? requestTimeout;
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
  /// [isolate] is optional and can be used to provide a custom isolate, which
  /// is used for heavy json computation
  ///
  /// [retryOptions] configures the automatic retry of GET and HEAD requests
  /// that fail with a retryable status code or a network error. Use
  /// [PostgrestBuilder.retry] to override it for a single request.
  ///
  /// [requestTimeout] optionally bounds how long a single request attempt may
  /// take. It is implemented on top of the abort mechanism, so it actually
  /// cancels a stalled attempt instead of leaving it running. A timed-out
  /// attempt is retried like any other failure, and a [TimeoutException] is
  /// thrown once the retries are exhausted. When `null` (the default) no
  /// timeout is applied. Use [PostgrestBuilder.abortSignal] to cancel a request
  /// outright, which stops retrying immediately.
  PostgrestClient(
    this.url, {
    Map<String, String>? headers,
    String? schema,
    this.httpClient,
    YAJsonIsolate? isolate,
    PostgrestRetryOptions retryOptions = const PostgrestRetryOptions(),
    this.requestTimeout,
  }) : // Snapshot the status codes so that mutating the set the caller passed
       // does not change the retry behavior of an existing client.
       retryOptions = retryOptions.copyWith(
         statusCodes: Set.unmodifiable(retryOptions.statusCodes),
       ),
       _schema = schema,
       headers = {...defaultHeaders, ...?headers},
       _isolate = isolate ?? (YAJsonIsolate()..initialize()),
       _hasCustomIsolate = isolate != null {
    _log.config('Initialize PostgrestClient with url: $url, schema: $_schema');
    _log.finest('Initialize with headers: $headers');
  }

  /// Authenticates the request with JWT.
  ///
  /// Passing `null` clears the `Authorization` header.
  PostgrestClient setAccessToken(String? token) {
    _log.finest("setAccessToken with: $token");
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      headers.remove('Authorization');
    }
    return this;
  }

  /// Perform a table operation.
  PostgrestQueryBuilder<void> from(String table) {
    final requestUrl = '$url/$table';
    return PostgrestQueryBuilder(
      url: Uri.parse(requestUrl),
      headers: {...headers},
      schema: _schema,
      httpClient: httpClient,
      isolate: _isolate,
      retryOptions: retryOptions,
      requestTimeout: requestTimeout,
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
      retryOptions: retryOptions,
      requestTimeout: requestTimeout,
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
    Map<dynamic, dynamic>? params,
    bool get = false,
  }) {
    final requestUrl = '$url/rpc/$fn';
    return PostgrestRpcBuilder(
      requestUrl,
      headers: {...headers},
      schema: _schema,
      httpClient: httpClient,
      isolate: _isolate,
      retryOptions: retryOptions,
      requestTimeout: requestTimeout,
    ).rpc(params, get);
  }

  Future<void> dispose() async {
    _log.fine("dispose PostgrestClient");
    if (!_hasCustomIsolate) {
      return _isolate.dispose();
    }
  }
}
