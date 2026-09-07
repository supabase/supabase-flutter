part of 'postgrest_typed_builder.dart';

/// A Postgres type to cast to, paired with the Dart type that cast produces so
/// the two cannot disagree.
///
/// A type with no shipped target is still reachable:
/// `PostgrestCastTarget<String>('citext')`.
@experimental
// ignore: avoid-unused-generics
final class PostgrestCastTarget<Value extends Object> {
  /// Creates a target for the Postgres type called [sqlType], as it appears
  /// after `::`.
  const PostgrestCastTarget(this.sqlType);

  /// `::text`
  static const text = PostgrestCastTarget<String>('text');

  /// `::int`
  static const integer = PostgrestCastTarget<int>('int');

  /// `::float8`
  static const doublePrecision = PostgrestCastTarget<double>('float8');

  /// `::boolean`
  static const boolean = PostgrestCastTarget<bool>('boolean');

  /// The Postgres type name, as it appears after `::`.
  final String sqlType;
}

/// A cast or an aggregate applied to another expression, or [countAll]:
/// select position only, whatever it was applied to.
///
/// PostgREST drops a cast from a filter, has no `HAVING` for an aggregate and
/// rejects both in `order`. A JSON path chained onto one stays select-only,
/// and a derivation of an embedded column stays inside the embed's
/// parentheses, `todo(amount::text)`.
@experimental
final class PostgrestDerivedExpression<Row, Value extends Object>
    extends PostgrestColumnExpression<Row, Value> {
  const PostgrestDerivedExpression._({
    required String? embed,
    required String inner,
  }) : _embed = embed,
       _inner = inner,
       super._();

  final String? _embed;
  final String _inner;

  /// `count()`, which counts rows rather than the values of a column.
  ///
  /// ```dart
  /// final rows = await client
  ///     .table(Orders.table)
  ///     .select([PostgrestDerivedExpression.countAll()]); // select=count()
  /// ```
  ///
  /// {@macro postgrest_aggregate}
  static PostgrestDerivedExpression<Row, int> countAll<Row>() =>
      const PostgrestDerivedExpression._(embed: null, inner: 'count()');

  @override
  String get expression => switch (_embed) {
    null => _inner,
    final embed => '$embed($_inner)',
  };

  /// Keeps the embed, so a chained derivation stays inside the parentheses.
  @override
  PostgrestDerivedExpression<Row, Derived> _derive<Derived extends Object>(
    String derivation,
  ) => PostgrestDerivedExpression._(
    embed: _embed,
    inner: '$_inner$derivation',
  );

  @override
  PostgrestDerivedExpression<Row, String> jsonText(String path) =>
      _derive('->>$path');

  @override
  PostgrestDerivedExpression<Row, Value> jsonObject(String path) =>
      _derive('->$path');
}

/// A JSON path read from a stored column, at every position the column is.
///
/// Filters and orders like the column it was read from, and is null-testable
/// whatever the column's own nullability: `data->>name` is `NULL` when the
/// key is absent, even on a `NOT NULL` `jsonb` column.
@experimental
final class PostgrestJsonPath<Row, Value extends Object>
    extends PostgrestColumnExpression<Row, Value>
    with
        PostgrestFilterableExpression<Row, Value>,
        PostgrestOrderableExpression<Row, Value>,
        PostgrestNullableExpression<Row, Value> {
  const PostgrestJsonPath._(this.expression) : super._();

  @override
  final String expression;

  @override
  PostgrestJsonPath<Row, String> jsonText(String path) =>
      PostgrestJsonPath._('$expression->>$path');

  @override
  PostgrestJsonPath<Row, Value> jsonObject(String path) =>
      PostgrestJsonPath._('$expression->$path');
}
