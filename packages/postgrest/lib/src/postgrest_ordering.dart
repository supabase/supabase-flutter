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
    this._expression, {
    SortDirection? direction,
    _NullPlacement? nulls,
  }) : _direction = direction,
       _nulls = nulls,
       super._();

  final String _expression;

  /// `null` sends no direction, so PostgREST's default applies.
  final SortDirection? _direction;

  /// `null` sends no placement, so the database default applies.
  final _NullPlacement? _nulls;

  @override
  String get orderKey {
    final direction = _direction == null ? '' : '.${_direction.value}';
    final placement = _nulls == null ? '' : '.${_nulls.token}';
    return '$_expression$direction$placement';
  }

  @override
  PostgrestOrdering<Row> asc() =>
      _Ordering(_expression, direction: SortDirection.ascending, nulls: _nulls);

  @override
  PostgrestOrdering<Row> desc() => _Ordering(
    _expression,
    direction: SortDirection.descending,
    nulls: _nulls,
  );

  @override
  PostgrestOrdering<Row> nullsFirst() => _Ordering(
    _expression,
    direction: _direction,
    nulls: _NullPlacement.first,
  );

  @override
  PostgrestOrdering<Row> nullsLast() =>
      _Ordering(_expression, direction: _direction, nulls: _NullPlacement.last);
}
