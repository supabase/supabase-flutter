import 'dart:async';

import 'package:meta/meta.dart';
import 'package:supabase/supabase.dart';

/// The typed counterpart of [SupabaseStreamBuilder]; emits the rows of the
/// table converted into [Row] through [PostgrestTable.rowFromJson].
@experimental
class SupabaseTypedStreamBuilder<Row> extends Stream<List<Row>> {
  const SupabaseTypedStreamBuilder(
    SupabaseStreamBuilder streamBuilder,
    this._table,
  ) : _streamBuilder = streamBuilder;

  final SupabaseStreamBuilder _streamBuilder;
  final PostgrestTable<Row> _table;

  /// Orders the result with the specified [column].
  ///
  /// Rows come back in ascending order unless `ascending: false` is passed,
  /// matching [SupabaseStreamBuilder.order].
  ///
  /// ```dart
  /// supabase
  ///     .table(Books.table)
  ///     .stream(primaryKey: [Books.id])
  ///     .order(Books.title);
  /// ```
  SupabaseTypedStreamBuilder<Row> order(
    TableColumn<Object> column, {
    bool ascending = true,
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
@experimental
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
  /// Can be called multiple times to combine filters with AND. Only
  /// [ComparisonFilter]s, [InListFilter], [PatternFilter]s, [IsNullFilter] and
  /// [IsDistinctFilter] are supported: [TableColumn.eq], [TableColumn.neq],
  /// [TableColumn.lt], [TableColumn.lte], [TableColumn.gt], [TableColumn.gte],
  /// [TableColumn.inFilter], [TableColumn.isNull],
  /// [TableColumn.isDistinctFrom], [TextTableColumnFilters.like],
  /// [TextTableColumnFilters.ilike], [TextTableColumnFilters.matchRegex] and
  /// [TextTableColumnFilters.imatchRegex].
  ///
  /// ```dart
  /// supabase
  ///     .table(Books.table)
  ///     .stream(primaryKey: [Books.id])
  ///     .filter(Books.title.eq('foo'));
  /// ```
  SupabaseTypedStreamFilterBuilder<Row> filter(ColumnFilter columnFilter) {
    switch (columnFilter) {
      case EqFilter():
        _streamFilterBuilder.eq(columnFilter.column, columnFilter.value);
      case NeqFilter():
        _streamFilterBuilder.neq(columnFilter.column, columnFilter.value);
      case LtFilter():
        _streamFilterBuilder.lt(columnFilter.column, columnFilter.value);
      case LteFilter():
        _streamFilterBuilder.lte(columnFilter.column, columnFilter.value);
      case GtFilter():
        _streamFilterBuilder.gt(columnFilter.column, columnFilter.value);
      case GteFilter():
        _streamFilterBuilder.gte(columnFilter.column, columnFilter.value);
      case InListFilter():
        _streamFilterBuilder.inFilter(columnFilter.column, columnFilter.values);
      case LikeFilter():
        _streamFilterBuilder.like(columnFilter.column, columnFilter.pattern);
      case IlikeFilter():
        _streamFilterBuilder.ilike(columnFilter.column, columnFilter.pattern);
      case MatchRegexFilter():
        _streamFilterBuilder.matchRegex(
          columnFilter.column,
          columnFilter.pattern,
        );
      case ImatchRegexFilter():
        _streamFilterBuilder.imatchRegex(
          columnFilter.column,
          columnFilter.pattern,
        );
      case IsNullFilter():
        _streamFilterBuilder.isFilter(columnFilter.column, null);
      case IsDistinctFilter():
        _streamFilterBuilder.isDistinct(
          columnFilter.column,
          columnFilter.value,
        );
      case ContainmentFilter() ||
          RangeFilter() ||
          PatternListFilter() ||
          TextSearchFilter() ||
          NegatedFilter():
        throw ArgumentError.value(
          columnFilter,
          'columnFilter',
          'Streams only support the eq, neq, lt, lte, gt, gte, inFilter, like, '
              'ilike, matchRegex, imatchRegex, isNull and isDistinctFrom '
              'filters.',
        );
    }
    return this;
  }
}
