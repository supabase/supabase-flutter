import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:supabase/supabase.dart';

import 'counter.dart';

/// Used to perform [rpc] and [from] operations with a different schema than in
/// [SupabaseClient].
class SupabaseQuerySchema {
  const SupabaseQuerySchema({
    required Counter counter,
    required String restUrl,
    required String schema,
    required AsyncJsonCodec jsonCodec,
    required Client? authHttpClient,
    required RealtimeClient realtime,
    required PostgrestClient rest,
  }) : _counter = counter,
       _restUrl = restUrl,
       _schema = schema,
       _jsonCodec = jsonCodec,
       _authHttpClient = authHttpClient,
       _realtime = realtime,
       _rest = rest;
  final Counter _counter;
  final String _restUrl;
  final String _schema;
  final AsyncJsonCodec _jsonCodec;
  final Client? _authHttpClient;
  final RealtimeClient _realtime;
  final PostgrestClient _rest;

  /// Perform a table operation.
  SupabaseQueryBuilder from(String table) {
    final url = '$_restUrl/$table';
    return SupabaseQueryBuilder(
      url,
      _realtime,
      headers: _rest.headers,
      schema: _schema,
      table: table,
      httpClient: _authHttpClient,
      incrementId: _counter.increment(),
      jsonCodec: _jsonCodec,
      retryOptions: _rest.retryOptions,
      requestTimeout: _rest.requestTimeout,
    );
  }

  /// Perform a typed table operation, see [SupabaseClient.table].
  @experimental
  SupabaseTypedQueryBuilder<Row> table<Row>(PostgrestTable<Row> table) {
    return SupabaseTypedQueryBuilder(from(table.name), table);
  }

  /// {@macro postgrest_rpc}
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    bool get = false,
  }) {
    return _rest.rpc(
      fn,
      params: params,
      get: get,
    );
  }

  /// Returns a copy of this scoped to [schema] instead.
  SupabaseQuerySchema schema(String schema) {
    final newRest = _rest.schema(schema);
    return SupabaseQuerySchema(
      counter: _counter,
      restUrl: _restUrl,
      schema: schema,
      jsonCodec: _jsonCodec,
      authHttpClient: _authHttpClient,
      realtime: _realtime,
      rest: newRest,
    );
  }
}
