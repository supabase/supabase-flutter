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
    PostgrestColumn<Row, Object> column, {
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

  /// Only rows satisfying [filter].
  ///
  /// Named [filter] instead of `where` because [Stream.where] already exists.
  ///
  /// Can be called multiple times to combine filters with AND. [filter] has
  /// to be a single operator call, not one composed with `&`, `|` or
  /// [PostgrestFilter.not], using one of `eq`, `neq`, `lt`, `lte`, `gt`,
  /// `gte`, `inFilter`, `like`, `ilike`, `matchRegex`, `imatchRegex`,
  /// `isNull`, `isTrue`, `isFalse` or `isDistinct`.
  ///
  /// ```dart
  /// supabase
  ///     .table(Books.table)
  ///     .stream(primaryKey: [Books.id])
  ///     .filter(Books.title.eq('foo'));
  /// ```
  SupabaseTypedStreamFilterBuilder<Row> filter(PostgrestFilter<Row> filter) {
    final comparison = filter.comparison;
    if (comparison == null) {
      throw ArgumentError.value(
        filter,
        'filter',
        'Streams apply one comparison per filter call; combine filters by '
            'calling filter repeatedly instead of with &, | or not().',
      );
    }
    final PostgrestComparison(:column, :operator, :value) = comparison;
    if (column is! PostgrestColumn<Row, Object>) {
      throw ArgumentError.value(
        filter,
        'filter',
        'Streams filter on stored columns only.',
      );
    }
    final name = column.name;
    switch (operator) {
      case PostgrestFilterOperator.eq:
        _streamFilterBuilder.eq(name, value!);
      case PostgrestFilterOperator.neq:
        _streamFilterBuilder.neq(name, value!);
      case PostgrestFilterOperator.lt:
        _streamFilterBuilder.lt(name, value!);
      case PostgrestFilterOperator.lte:
        _streamFilterBuilder.lte(name, value!);
      case PostgrestFilterOperator.gt:
        _streamFilterBuilder.gt(name, value!);
      case PostgrestFilterOperator.gte:
        _streamFilterBuilder.gte(name, value!);
      case PostgrestFilterOperator.inFilter:
        _streamFilterBuilder.inFilter(name, value! as List<Object>);
      case PostgrestFilterOperator.like:
        _streamFilterBuilder.like(name, value! as String);
      case PostgrestFilterOperator.ilike:
        _streamFilterBuilder.ilike(name, value! as String);
      case PostgrestFilterOperator.matchRegex:
        _streamFilterBuilder.matchRegex(name, value! as String);
      case PostgrestFilterOperator.imatchRegex:
        _streamFilterBuilder.imatchRegex(name, value! as String);
      case PostgrestFilterOperator.isFilter:
        _streamFilterBuilder.isFilter(name, value as bool?);
      case PostgrestFilterOperator.isDistinct:
        _streamFilterBuilder.isDistinct(name, value);
      case PostgrestFilterOperator.likeAllOf:
      case PostgrestFilterOperator.likeAnyOf:
      case PostgrestFilterOperator.ilikeAllOf:
      case PostgrestFilterOperator.ilikeAnyOf:
      case PostgrestFilterOperator.contains:
      case PostgrestFilterOperator.containedBy:
      case PostgrestFilterOperator.overlaps:
      case PostgrestFilterOperator.rangeLt:
      case PostgrestFilterOperator.rangeGt:
      case PostgrestFilterOperator.rangeGte:
      case PostgrestFilterOperator.rangeLte:
      case PostgrestFilterOperator.rangeAdjacent:
      case PostgrestFilterOperator.textSearch:
        throw ArgumentError.value(
          filter,
          'filter',
          'Streams do not support the ${operator.name} operator.',
        );
    }
    return this;
  }
}
