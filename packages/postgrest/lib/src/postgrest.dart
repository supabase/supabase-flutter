import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:postgrest/postgrest.dart';
import 'package:postgrest/src/constants.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

/// A PostgREST api client written in Dartlang. The goal of this library is to make an "ORM-like" restful interface.
class PostgrestClient {
  /// HTTP status codes that trigger an automatic retry by default.
  static const Set<int> defaultRetryableStatusCodes = {503, 520};

  final String url;
  final Map<String, String> headers;
  final String? _schema;
  final Client? httpClient;
  final YAJsonIsolate _isolate;
  final bool _hasCustomIsolate;
  final bool retryEnabled;
  final int retryCount;
  final Set<int> retryableStatusCodes;
  final Duration? requestTimeout;
  final Duration Function(int attempt)? _retryDelay;
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
  /// HEAD requests that fail with a retryable status code or a network error.
  /// Defaults to `true`. Use [PostgrestBuilder.retry] to override this per request.
  ///
  /// [retryCount] is the number of retry attempts made for a retryable request
  /// before giving up. Defaults to `3`.
  ///
  /// [retryableStatusCodes] are the HTTP status codes that trigger a retry.
  /// Defaults to `{503, 520}`.
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
    this.retryEnabled = true,
    this.retryCount = 3,
    Set<int> retryableStatusCodes = defaultRetryableStatusCodes,
    this.requestTimeout,
    @visibleForTesting Duration Function(int attempt)? retryDelay,
  }) : retryableStatusCodes = Set.unmodifiable(retryableStatusCodes),
       _schema = schema,
       headers = {...defaultHeaders, ...?headers},
       _isolate = isolate ?? (YAJsonIsolate()..initialize()),
       _hasCustomIsolate = isolate != null,
       _retryDelay = retryDelay {
    if (retryCount < 0) {
      throw ArgumentError.value(
        retryCount,
        'retryCount',
        'must not be negative',
      );
    }
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
    final requestUrl = '$url/$table';
    return PostgrestQueryBuilder(
      url: Uri.parse(requestUrl),
      headers: {...headers},
      schema: _schema,
      httpClient: httpClient,
      isolate: _isolate,
      retryEnabled: retryEnabled,
      retryCount: retryCount,
      retryableStatusCodes: retryableStatusCodes,
      requestTimeout: requestTimeout,
      retryDelay: _retryDelay,
    );
  }

  /// Perform a typed table operation.
  ///
  /// Unlike [from], results are converted into the row type of [table]
  /// instead of raw `Map<String, dynamic>` data, and filters are built from
  /// [TableColumn]s, which makes them compile-time checked.
  ///
  /// ```dart
  /// final List<Book> books = await client
  ///     .table(Books.table)
  ///     .select()
  ///     .where(Books.id.gt(10));
  /// ```
  @experimental
  PostgrestTypedQueryBuilder<Row> table<Row>(PostgrestTable<Row> table) {
    return PostgrestTypedQueryBuilder(from(table.name), table);
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
      retryCount: retryCount,
      retryableStatusCodes: retryableStatusCodes,
      requestTimeout: requestTimeout,
      retryDelay: _retryDelay,
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
      retryEnabled: retryEnabled,
      retryCount: retryCount,
      retryableStatusCodes: retryableStatusCodes,
      requestTimeout: requestTimeout,
      retryDelay: _retryDelay,
    ).rpc(params, get);
  }

  Future<void> dispose() async {
    _log.fine("dispose PostgrestClient");
    if (!_hasCustomIsolate) {
      return _isolate.dispose();
    }
  }
}
