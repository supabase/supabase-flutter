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
part 'postgrest_typed_query_builder.dart';
part 'postgrest_typed_transform_builder.dart';
part 'postgrest_typed_filter_builder.dart';

List<Row> _rowsFromJson<Row>(
  RowConverter<Row> rowFromJson,
  PostgrestList rows,
) => [for (final row in rows) rowFromJson(row)];

/// The `select` parameter for [columns], or `*` when none are given.
String _selectList<Row>(List<PostgrestColumnExpression<Row, Object>>? columns) {
  if (columns == null) return '*';
  if (columns.isEmpty) {
    throw ArgumentError.value(
      columns,
      'columns',
      'select needs at least one column',
    );
  }
  return columns.map((column) => column.expression).join(',');
}

/// A typed PostgREST request that can be awaited.
///
/// Wraps a [PostgrestBuilder] whose decoder already produces [T], so awaiting
/// it never exposes raw `Map<String, dynamic>` data.
@experimental
class PostgrestTypedBuilder<T> implements Future<T> {
  const PostgrestTypedBuilder._(this._builder);

  final PostgrestBuilder<T> _builder;

  @override
  Stream<T> asStream() => _builder.asStream();

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) =>
      _builder.catchError(onError, test: test);

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) => _builder.then(onValue, onError: onError);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _builder.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      _builder.whenComplete(action);
}
