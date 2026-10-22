part of 'postgrest_typed_builder.dart';

/// One sort key for [PostgrestTypedTransformBuilder.order]: a column
/// expression, optionally with a direction and a null placement.
///
/// ```dart
/// .order(Books.priority.desc())
/// .order(Books.id) // breaks ties in the first; direction left to PostgREST
/// ```
///
/// Only what was asked for is sent: `order(Books.id)` renders `order=id`,
/// and `Books.title.nullsFirst()` renders `title.nullsfirst`.
///
/// [Row] is the row type of the table the key belongs to, so an ordering on
/// one table cannot be applied to a query on another.
@experimental
sealed class PostgrestOrdering<Row> {
  const PostgrestOrdering._();

  /// The rendered key as it appears in the `order` parameter, for example
  /// `title.desc.nullslast`.
  String get orderKey;

  /// The expression this ordering sorts by.
  @internal
  PostgrestColumnExpression<Row, Object> get column;

  /// The direction asked for, or `null` when none was given.
  @internal
  SortDirection? get direction;

  /// Whether `NULL`s were asked to sort first (`true`) or last (`false`), or
  /// `null` when no placement was given.
  @internal
  bool? get placesNullsFirst;

  /// Sorts smallest first.
  PostgrestOrdering<Row> asc();

  /// Sorts largest first.
  PostgrestOrdering<Row> desc();

  /// Places `NULL`s before non-null values.
  PostgrestOrdering<Row> nullsFirst();

  /// Places `NULL`s after non-null values.
  PostgrestOrdering<Row> nullsLast();
}

/// Where `NULL`s sort relative to other values.
enum _NullPlacement {
  first('nullsfirst'),
  last('nullslast');

  const _NullPlacement(this.token);

  final String token;
}

final class _Ordering<Row> extends PostgrestOrdering<Row> {
  const _Ordering(
    this.column, {
    this.direction,
    _NullPlacement? nulls,
  }) : _nulls = nulls,
       super._();

  @override
  final PostgrestColumnExpression<Row, Object> column;

  /// `null` sends no direction, so PostgREST's default applies.
  @override
  final SortDirection? direction;

  /// `null` sends no placement, so the database default applies.
  final _NullPlacement? _nulls;

  @override
  bool? get placesNullsFirst => switch (_nulls) {
    null => null,
    _NullPlacement.first => true,
    _NullPlacement.last => false,
  };

  @override
  String get orderKey {
    final suffix = switch (direction) {
      null => '',
      final sortDirection => '.${sortDirection.value}',
    };
    final placement = _nulls == null ? '' : '.${_nulls.token}';
    return '${column._orderKey}$suffix$placement';
  }

  @override
  PostgrestOrdering<Row> asc() =>
      _Ordering(column, direction: SortDirection.ascending, nulls: _nulls);

  @override
  PostgrestOrdering<Row> desc() => _Ordering(
    column,
    direction: SortDirection.descending,
    nulls: _nulls,
  );

  @override
  PostgrestOrdering<Row> nullsFirst() => _Ordering(
    column,
    direction: direction,
    nulls: _NullPlacement.first,
  );

  @override
  PostgrestOrdering<Row> nullsLast() =>
      _Ordering(column, direction: direction, nulls: _NullPlacement.last);
}
