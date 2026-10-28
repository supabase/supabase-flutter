// The typed table executor is @experimental.
// ignore_for_file: experimental_member_use

import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_common/supabase_common.dart'
    show ClientInfoFeature, withClientInfoFeatures;

import 'counter.dart';

/// Used to perform [rpc] and [from] operations with a different schema than in
/// [SupabaseClient].
class SupabaseQuerySchema {
  /// Use [SupabaseClient.schema] to create one.
  @internal
  SupabaseQuerySchema({
    required Counter counter,
    required String restUrl,
    required String schema,
    required AsyncJsonCodec jsonCodec,
    required Client? authHttpClient,
    required RealtimeClient realtime,
    required PostgrestClient rest,
    PostgrestTableExecutor? tableExecutor,
  }) : _counter = counter,
       _restUrl = restUrl,
       _schema = schema,
       _jsonCodec = jsonCodec,
       _authHttpClient = authHttpClient,
       _realtime = realtime,
       _rest = rest,
       _tableExecutor = tableExecutor ?? PostgrestHttpTableExecutor(rest);
  final Counter _counter;
  final String _restUrl;
  final String _schema;
  final AsyncJsonCodec _jsonCodec;
  final Client? _authHttpClient;
  final RealtimeClient _realtime;
  final PostgrestClient _rest;
  final PostgrestTableExecutor _tableExecutor;

  /// Perform a table operation.
  SupabaseQueryBuilder from(String table) => _from(table, _rest.headers);

  SupabaseQueryBuilder _from(String table, Map<String, String> headers) {
    final url = '$_restUrl/$table';
    return SupabaseQueryBuilder(
      url,
      _realtime,
      headers: headers,
      schema: _schema,
      table: table,
      httpClient: _authHttpClient,
      counter: _counter,
      jsonCodec: _jsonCodec,
      retryOptions: _rest.retryOptions,
      requestTimeout: _rest.requestTimeout,
    );
  }

  /// Perform a typed table operation in this schema, see
  /// [SupabaseClient.table]. The schema of this object wins over
  /// [PostgrestTable.schema].
  @experimental
  SupabaseTypedQueryBuilder<Row, Insert, Update> table<Row, Insert, Update>(
    PostgrestTable<Row, Insert, Update> table,
  ) {
    return SupabaseTypedQueryBuilder(
      _from(
        table.name,
        withClientInfoFeatures(_rest.headers, const {
          ClientInfoFeature.typedApi,
        }),
      ),
      table,
      executor: _tableExecutor,
      schema: _schema,
    );
  }

  /// Calls Postgres functions in this schema, see [PostgrestClient.rpc].
  ///
  /// The schema of this object wins over the schema a generated function
  /// method addresses. The typed calls run through the interceptors of the
  /// client.
  // ignore: invalid_use_of_internal_member
  PostgrestRpc get rpc => _rest.rpc.withExecutor(_tableExecutor);

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
      tableExecutor: _tableExecutor,
    );
  }
}
