import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart' show hex;
import 'package:meta/meta.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_common/supabase_common.dart' show SortDirection;

part 'postgrest_bytea.dart';
part 'postgrest_column_expression.dart';
part 'postgrest_derived_expression.dart';
part 'postgrest_embedded_relation.dart';
part 'postgrest_filter.dart';
part 'postgrest_filter_operators.dart';
part 'postgrest_ordering.dart';
part 'postgrest_range.dart';
part 'postgrest_table.dart';
part 'postgrest_table_executor.dart';
part 'postgrest_table_request.dart';
part 'postgrest_typed_query_builder.dart';
part 'postgrest_typed_transform_builder.dart';
part 'postgrest_typed_filter_builder.dart';

List<Row> _rowsFromJson<Row>(
  RowConverter<Row> rowFromJson,
  PostgrestList rows,
) => [for (final row in rows) rowFromJson(row)];

/// The `select` parameter for [columns], or `*` when none are given.
String _selectList(List<PostgrestColumnExpression<Object?, Object>>? columns) {
  if (columns == null) return '*';
  return columns.map((column) => column.expression).join(',');
}

/// [columns] as the request stores them, rejecting an empty list up front so
/// the error surfaces where `select` is called rather than when awaited.
List<PostgrestColumnExpression<Object?, Object>> _checkedColumns<Row>(
  List<PostgrestColumnExpression<Row, Object>> columns,
) {
  if (columns.isEmpty) {
    throw ArgumentError.value(
      columns,
      'columns',
      'select needs at least one column',
    );
  }
  return List.unmodifiable(columns);
}

/// Converts the result of a [PostgrestTableRequest] into [T].
typedef _ResultConverter<T> = T Function(PostgrestTableResult result);

_ResultConverter<List<Row>> _rowsConverter<Row>(
  RowConverter<Row> rowFromJson,
) =>
    (result) => _rowsFromJson(rowFromJson, result.data! as PostgrestList);

void _noResult(PostgrestTableResult result) {}

/// A typed PostgREST request that can be awaited.
///
/// Holds the [request] the builder methods have collected so far and the
/// [PostgrestTableExecutor] that runs it. Awaiting the builder executes the
/// request and converts the result into [T], so awaiting it never exposes raw
/// `Map<String, dynamic>` data.
@experimental
class PostgrestTypedBuilder<T> implements Future<T> {
  const PostgrestTypedBuilder._(this.request, this._executor, this._convert);

  /// The request awaiting this builder executes.
  final PostgrestTableRequest request;

  final PostgrestTableExecutor _executor;
  final _ResultConverter<T> _convert;

  Future<T> _execute() => _executor.execute(request).then(_convert);

  @override
  Stream<T> asStream() {
    final controller = StreamController<T>.broadcast();
    unawaited(
      _execute()
          .then(controller.add)
          .catchError(controller.addError)
          .whenComplete(controller.close),
    );
    return controller.stream;
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) =>
      _execute().catchError(onError, test: test);

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) => _execute().then(onValue, onError: onError);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _execute().timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      _execute().whenComplete(action);
}
