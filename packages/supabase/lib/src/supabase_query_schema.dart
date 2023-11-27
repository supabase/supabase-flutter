import 'package:http/http.dart';
import 'package:supabase/supabase.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

import 'counter.dart';

/// Used to perform [rpc] and [from] operations with a different schema than in [SupabaseClient].
class SupabaseQuerySchema {
  final Counter _counter;
  final String _restUrl;
  final Map<String, String> _headers;
  final String _schema;
  final YAJsonIsolate _isolate;
  final Client? _authHttpClient;
  final RealtimeClient _realtime;
  final PostgrestClient _rest;

  SupabaseQuerySchema({
    required Counter counter,
    required String restUrl,
    required Map<String, String> headers,
    required String schema,
    required YAJsonIsolate isolate,
    required Client? authHttpClient,
    required RealtimeClient realtime,
    required PostgrestClient rest,
  })  : _counter = counter,
        _restUrl = restUrl,
        _headers = headers,
        _schema = schema,
        _isolate = isolate,
        _authHttpClient = authHttpClient,
        _realtime = realtime,
        _rest = rest;

  /// Perform a table operation.
  SupabaseQueryBuilder from(String table) {
    final url = '$_restUrl/$table';
    return SupabaseQueryBuilder(
      url,
      _realtime,
      headers: {..._rest.headers, ..._headers},
      schema: _schema,
      table: table,
      httpClient: _authHttpClient,
      incrementId: _counter.increment(),
      isolate: _isolate,
    );
  }

  /// Perform a stored procedure call.
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
  }) {
    _rest.headers.addAll({..._rest.headers, ..._headers});
    return _rest.rpc(fn, params: params);
  }

  SupabaseQuerySchema schema(String schema) {
    final newRest = _rest.schema(schema);
    return SupabaseQuerySchema(
      counter: _counter,
      restUrl: _restUrl,
      headers: _headers,
      schema: schema,
      isolate: _isolate,
      authHttpClient: _authHttpClient,
      realtime: _realtime,
      rest: newRest,
    );
  }
}
