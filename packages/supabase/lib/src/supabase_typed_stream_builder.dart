import 'dart:async';

import 'package:meta/meta.dart';
import 'package:supabase/supabase.dart';

/// The typed counterpart of [SupabaseStreamBuilder]; emits the rows of the
/// table converted into [Element]: the [Row] of
/// [SupabaseTypedQueryBuilder.stream], through [PostgrestTable.rowFromJson],
/// or the [PostgrestPartialRow] of [SupabaseTypedQueryBuilder.streamOnly].
@experimental
class SupabaseTypedStreamBuilder<Row, Element> extends Stream<List<Element>> {
  const SupabaseTypedStreamBuilder(
    SupabaseStreamBuilder streamBuilder,
    this._elementFromJson,
  ) : _streamBuilder = streamBuilder;

  final SupabaseStreamBuilder _streamBuilder;
  final RowConverter<Element> _elementFromJson;

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
  SupabaseTypedStreamBuilder<Row, Element> order(
    PostgrestStoredColumn<Row, Object> column, {
    bool ascending = true,
  }) {
    _streamBuilder.order(column.name, ascending: ascending);
    return this;
  }

  /// Limits the result with the specified [count].
  SupabaseTypedStreamBuilder<Row, Element> limit(int count) {
    _streamBuilder.limit(count);
    return this;
  }

  @override
  bool get isBroadcast => _streamBuilder.isBroadcast;

  @override
  StreamSubscription<List<Element>> listen(
    void Function(List<Element> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _streamBuilder
        .map(
          (rows) => [for (final row in rows) _elementFromJson(row)],
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
class SupabaseTypedStreamFilterBuilder<Row, Element>
    extends SupabaseTypedStreamBuilder<Row, Element> {
  const SupabaseTypedStreamFilterBuilder(
    SupabaseStreamFilterBuilder super.streamBuilder,
    super.elementFromJson,
  );

  SupabaseStreamFilterBuilder get _streamFilterBuilder =>
      _streamBuilder as SupabaseStreamFilterBuilder;

  /// Only rows satisfying [filter].
  ///
  /// Named [filter] instead of `where` because [Stream.where] already exists.
  ///
  /// Can be called multiple times to combine filters with AND. [filter] has
  /// to be a single operator call, optionally negated with
  /// [PostgrestFilter.not], not one composed with `&` or `|`, using one of
  /// `eq`, `neq`, `lt`, `lte`, `gt`, `gte`, `inFilter`, `like`, `ilike`,
  /// `matchRegex`, `imatchRegex`, `isNull`, `isTrue`, `isFalse` or
  /// `isDistinct`.
  ///
  /// ```dart
  /// supabase
  ///     .table(Books.table)
  ///     .stream(primaryKey: [Books.id])
  ///     .filter(Books.title.eq('foo'))
  ///     .filter(Books.status.inFilter(['draft', 'archived']).not());
  /// ```
  SupabaseTypedStreamFilterBuilder<Row, Element> filter(
    PostgrestFilter<Row> filter,
  ) {
    final comparison = filter.comparison;
    if (comparison == null) {
      throw ArgumentError.value(
        filter,
        'filter',
        'Streams apply one comparison per filter call, negated or not; '
            'combine filters by calling filter repeatedly instead of with & '
            'or |.',
      );
    }
    final PostgrestComparison(:column, :operator, :value, :negated) =
        comparison;
    if (column is! PostgrestStoredColumn<Row, Object>) {
      throw ArgumentError.value(
        filter,
        'filter',
        'Streams filter on stored columns only.',
      );
    }
    if (column is PostgrestIntegerVectorColumn ||
        column is PostgrestNullableIntegerVectorColumn) {
      throw ArgumentError.value(
        filter,
        'filter',
        'Streams cannot filter on int2vector or oidvector columns; realtime '
            'cannot compare their values.',
      );
    }
    final name = column.name;
    final type = switch (operator) {
      PostgrestFilterOperator.eq => PostgresChangeFilterType.eq,
      PostgrestFilterOperator.neq => PostgresChangeFilterType.neq,
      PostgrestFilterOperator.lt => PostgresChangeFilterType.lt,
      PostgrestFilterOperator.lte => PostgresChangeFilterType.lte,
      PostgrestFilterOperator.gt => PostgresChangeFilterType.gt,
      PostgrestFilterOperator.gte => PostgresChangeFilterType.gte,
      PostgrestFilterOperator.inFilter => PostgresChangeFilterType.inFilter,
      PostgrestFilterOperator.like => PostgresChangeFilterType.like,
      PostgrestFilterOperator.ilike => PostgresChangeFilterType.ilike,
      PostgrestFilterOperator.matchRegex => PostgresChangeFilterType.match,
      PostgrestFilterOperator.imatchRegex => PostgresChangeFilterType.imatch,
      PostgrestFilterOperator.isFilter => PostgresChangeFilterType.isFilter,
      PostgrestFilterOperator.isDistinct => PostgresChangeFilterType.isDistinct,
      PostgrestFilterOperator.likeAllOf ||
      PostgrestFilterOperator.likeAnyOf ||
      PostgrestFilterOperator.ilikeAllOf ||
      PostgrestFilterOperator.ilikeAnyOf ||
      PostgrestFilterOperator.contains ||
      PostgrestFilterOperator.containedBy ||
      PostgrestFilterOperator.overlaps ||
      PostgrestFilterOperator.rangeLt ||
      PostgrestFilterOperator.rangeGt ||
      PostgrestFilterOperator.rangeGte ||
      PostgrestFilterOperator.rangeLte ||
      PostgrestFilterOperator.rangeAdjacent ||
      PostgrestFilterOperator.textSearch => throw ArgumentError.value(
        filter,
        'filter',
        'Streams do not support the ${operator.name} operator.',
      ),
    };
    _streamFilterBuilder.addFilter(
      name,
      type,
      _vectorOperand(column, operator, value),
      negated: negated,
    );
    return this;
  }

  /// [value] as the literal a pgvector [column] reads, or [value] itself for
  /// any other column, since the stream sends it to PostgREST and to
  /// realtime as it is.
  static Object? _vectorOperand(
    PostgrestStoredColumn<Object?, Object> column,
    PostgrestFilterOperator operator,
    Object? value,
  ) {
    if (column is! PostgrestVectorColumn &&
        column is! PostgrestNullableVectorColumn) {
      return value;
    }
    if (value is! List<Object?>) return value;
    String render(Object? vector) =>
        postgresVector.encode((vector! as List<Object?>).cast());
    if (operator == PostgrestFilterOperator.inFilter) {
      return [for (final member in value) render(member)];
    }
    return render(value);
  }
}
