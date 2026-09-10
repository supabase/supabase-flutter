import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_common/supabase_common.dart' show SortDirection;

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

List<Row> _rowsFromJson<Row>(PostgrestTable<Row> table, dynamic data) => [
  for (final row in data as List)
    table.rowFromJson(row as Map<String, dynamic>),
];

Row _rowFromJson<Row>(PostgrestTable<Row> table, dynamic data) =>
    table.rowFromJson(data as Map<String, dynamic>);

Row? _maybeRowFromJson<Row>(PostgrestTable<Row> table, dynamic data) =>
    data == null ? null : table.rowFromJson(data as Map<String, dynamic>);

void _toVoid(dynamic data) {}

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
/// Wraps an untyped [PostgrestBuilder] and converts its result into [T]
/// before it is returned, so awaiting it never exposes raw
/// `Map<String, dynamic>` data.
@experimental
class PostgrestTypedBuilder<T> implements Future<T> {
  const PostgrestTypedBuilder._(this._rawBuilder, this._convert);

  final PostgrestBuilder<dynamic, dynamic, dynamic> _rawBuilder;
  final T Function(dynamic data) _convert;

  Future<T> _execute() async {
    final dynamic data = await _rawBuilder;
    return _convert(data);
  }

  @override
  Stream<T> asStream() {
    // Mirrors [PostgrestBuilder.asStream], which returns a broadcast stream.
    final controller = StreamController<T>.broadcast();

    unawaited(
      then((value) {
            controller.add(value);
          })
          .catchError((Object error, StackTrace stack) {
            controller.addError(error, stack);
          })
          .whenComplete(() {
            unawaited(controller.close());
          }),
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
