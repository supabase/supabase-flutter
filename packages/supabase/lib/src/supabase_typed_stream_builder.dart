import 'dart:async';

import 'package:meta/meta.dart';
import 'package:supabase/src/typed_postgres_change_filter.dart';
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

  /// Orders the result by [ordering], the same [PostgrestOrdering] that
  /// [PostgrestTypedTransformBuilder.order] takes.
  ///
  /// Rows come back in ascending order unless [PostgrestOrdering.desc] is
  /// chained, with `null` values last in ascending order and first in
  /// descending order, matching [SupabaseStreamBuilder.order].
  ///
  /// ```dart
  /// supabase
  ///     .table(Books.table)
  ///     .stream(primaryKey: [Books.id])
  ///     .order(Books.createdAt.desc());
  /// ```
  ///
  /// Throws an [ArgumentError] for an ordering realtime cannot keep while
  /// merging changes: one by anything but a stored column, or one with
  /// [PostgrestOrdering.nullsFirst] or [PostgrestOrdering.nullsLast].
  SupabaseTypedStreamBuilder<Row, Element> order(
    PostgrestOrdering<Row> ordering,
  ) {
    // ignore: invalid_use_of_internal_member
    final column = ordering.column;
    if (column is! PostgrestStoredColumn<Row, Object>) {
      throw ArgumentError.value(
        ordering,
        'ordering',
        'Realtime streams order by stored columns only.',
      );
    }
    // ignore: invalid_use_of_internal_member
    if (ordering.placesNullsFirst != null) {
      throw ArgumentError.value(
        ordering,
        'ordering',
        'Realtime streams place nulls last in ascending order and first in '
            'descending order; remove nullsFirst() or nullsLast().',
      );
    }
    _streamBuilder.order(
      column.name,
      // ignore: invalid_use_of_internal_member
      ascending: ordering.direction != SortDirection.descending,
    );
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
    final change = postgresChangeFilterOf(filter);
    _streamFilterBuilder.addFilter(
      change.column,
      change.type,
      change.value,
      negated: change.negate,
    );
    return this;
  }
}
