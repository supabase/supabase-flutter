import 'dart:async';

import 'package:supabase/supabase.dart';

/// The typed counterpart of [SupabaseStreamBuilder]; emits the rows of the
/// table converted into [Row] through [PostgrestTable.rowFromJson].
class SupabaseTypedStreamBuilder<Row> extends Stream<List<Row>> {
  const SupabaseTypedStreamBuilder(
    SupabaseStreamBuilder streamBuilder,
    this._table,
  ) : _streamBuilder = streamBuilder;

  final SupabaseStreamBuilder _streamBuilder;
  final PostgrestTable<Row> _table;

  /// Orders the result with the specified [column].
  ///
  /// ```dart
  /// supabase
  ///     .table(Books.table)
  ///     .stream(primaryKey: [Books.id])
  ///     .order(Books.title, ascending: true);
  /// ```
  SupabaseTypedStreamBuilder<Row> order(
    TableColumn<Object> column, {
    bool ascending = false,
  }) {
    _streamBuilder.order(column.name, ascending: ascending);
    return this;
  }

  /// Limits the result with the specified [count].
  SupabaseTypedStreamBuilder<Row> limit(int count) {
    _streamBuilder.limit(count);
    return this;
  }

  @override
  bool get isBroadcast => _streamBuilder.isBroadcast;

  @override
  StreamSubscription<List<Row>> listen(
    void Function(List<Row> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _streamBuilder
        .map(
          (rows) => [for (final row in rows) _table.rowFromJson(row)],
        )
        .listen(
          onData,
          onError: onError,
          onDone: onDone,
          cancelOnError: cancelOnError,
        );
  }
}

/// A [SupabaseTypedStreamBuilder] that can still be filtered with [filter].
class SupabaseTypedStreamFilterBuilder<Row>
    extends SupabaseTypedStreamBuilder<Row> {
  const SupabaseTypedStreamFilterBuilder(
    SupabaseStreamFilterBuilder super.streamBuilder,
    super.table,
  );

  SupabaseStreamFilterBuilder get _streamFilterBuilder =>
      _streamBuilder as SupabaseStreamFilterBuilder;

  /// Only rows satisfying [columnFilter].
  ///
  /// Named [filter] instead of `where` because [Stream.where] already exists.
  ///
  /// Only one filter can be applied to a stream, and only equality and
  /// comparison filters are supported: [TableColumn.eq], [TableColumn.neq],
  /// [TableColumn.lt], [TableColumn.lte], [TableColumn.gt], [TableColumn.gte]
  /// and [TableColumn.inFilter].
  ///
  /// ```dart
  /// supabase
  ///     .table(Books.table)
  ///     .stream(primaryKey: [Books.id])
  ///     .filter(Books.title.eq('foo'));
  /// ```
  SupabaseTypedStreamBuilder<Row> filter(ColumnFilter columnFilter) {
    switch (columnFilter.operator) {
      case 'eq':
        _streamFilterBuilder.eq(
          columnFilter.column,
          columnFilter.value as Object,
        );
      case 'neq':
        _streamFilterBuilder.neq(
          columnFilter.column,
          columnFilter.value as Object,
        );
      case 'lt':
        _streamFilterBuilder.lt(
          columnFilter.column,
          columnFilter.value as Object,
        );
      case 'lte':
        _streamFilterBuilder.lte(
          columnFilter.column,
          columnFilter.value as Object,
        );
      case 'gt':
        _streamFilterBuilder.gt(
          columnFilter.column,
          columnFilter.value as Object,
        );
      case 'gte':
        _streamFilterBuilder.gte(
          columnFilter.column,
          columnFilter.value as Object,
        );
      case 'in':
        _streamFilterBuilder.inFilter(
          columnFilter.column,
          List<Object>.from(columnFilter.value as List),
        );
      default:
        throw ArgumentError.value(
          columnFilter.operator,
          'columnFilter',
          'Streams only support the eq, neq, lt, lte, gt, gte and inFilter '
              'filters.',
        );
    }
    return this;
  }
}
