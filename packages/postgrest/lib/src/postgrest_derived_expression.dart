part of 'postgrest_typed_builder.dart';

/// A Postgres type to cast to, paired with the Dart type that cast produces so
/// the two cannot disagree.
///
/// A type with no shipped target is still reachable:
/// `PostgrestCastTarget<String>('citext')`.
@experimental
final class PostgrestCastTarget<Value extends Object> {
  /// Creates a target for the Postgres type called [sqlType], as it appears
  /// after `::`.
  ///
  /// [fromJson] converts the decoded JSON of a cast value into [Value] when
  /// reading it from a [PostgrestPartialRow]; left out, the decoded JSON is
  /// cast to [Value].
  const PostgrestCastTarget(
    this.sqlType, {
    Value Function(Object json)? fromJson,
  }) : _fromJson = fromJson;

  /// `::text`
  static const text = PostgrestCastTarget<String>('text');

  /// `::int`
  static const integer = PostgrestCastTarget<int>('int');

  /// `::float8`
  static const doublePrecision = PostgrestCastTarget(
    'float8',
    fromJson: _toDouble,
  );

  /// `::boolean`
  static const boolean = PostgrestCastTarget<bool>('boolean');

  /// The Postgres type name, as it appears after `::`.
  final String sqlType;

  final Value Function(Object json)? _fromJson;
}

/// A cast or an aggregate applied to another expression, or [countAll]:
/// select position only, whatever it was applied to.
///
/// PostgREST drops a cast from a filter, has no `HAVING` for an aggregate and
/// rejects both in `order`. A JSON path chained onto one stays select-only,
/// and a derivation of an embedded column stays inside the embed's
/// parentheses, `todo(amount::text)`.
///
/// Read from a [PostgrestPartialRow] as `Value?`: `sum`, `avg`, `min` and
/// `max` are `NULL` when no row matches, and a cast keeps the nullability of
/// what it was applied to, which the type does not track.
@experimental
sealed class PostgrestDerivedExpression<Row, Value extends Object>
    extends PostgrestColumnExpression<Row, Value>
    implements PostgrestReadable<Row, Value?> {
  const PostgrestDerivedExpression._() : super._();

  /// `count()`, which counts rows rather than the values of a column.
  ///
  /// ```dart
  /// final rows = await client
  ///     .table(Orders.table)
  ///     .selectOnly([PostgrestDerivedExpression.countAll()]); // select=count()
  /// ```
  ///
  /// {@macro postgrest_aggregate}
  static PostgrestDerivedExpression<Row, int> countAll<Row>() =>
      const _Derivation._('count()', 'count', null);

  @override
  PostgrestDerivedExpression<Row, String> jsonText(String path) =>
      _derive('->>$path', key: null, fromJson: null);

  @override
  PostgrestDerivedExpression<Row, Value> jsonObject(String path) =>
      _derive('->$path', key: null, fromJson: null);

  @override
  bool get _selectedByStar => false;

  @override
  Value? _read(Object? json, _NestedSelection nested) {
    if (json == null) return null;
    return switch (_fromJson) {
      null => json as Value,
      final fromJson => fromJson(json),
    };
  }
}

/// A derivation of a value of this table, kept as the text PostgREST reads.
///
/// Without a key, it is keyed by its own expression and sent under that
/// alias, see [PostgrestJsonPath].
final class _Derivation<Row, Value extends Object>
    extends PostgrestDerivedExpression<Row, Value> {
  const _Derivation._(this.expression, this._castKey, this._fromJson)
    : super._();

  @override
  final String expression;

  @override
  final String? _castKey;

  @override
  String get responseKey => _castKey ?? _expressionKey(expression);

  @override
  String get _selectExpression =>
      _castKey == null ? _aliased(expression) : expression;

  @override
  final Value Function(Object json)? _fromJson;

  @override
  PostgrestDerivedExpression<Row, Derived> _derive<Derived extends Object>(
    String derivation, {
    required String? key,
    required Derived Function(Object json)? fromJson,
  }) => _Derivation._('$expression$derivation', key, fromJson);
}

/// A derivation applied inside an embed's parentheses, `todo(amount.sum())`.
///
/// Keeps the relation, so a chained derivation stays inside the parentheses
/// and the entry merges with the other entries of the same embed.
final class _EmbeddedDerivation<Row, Value extends Object>
    extends PostgrestDerivedExpression<Row, Value>
    with _Embedded<Row> {
  const _EmbeddedDerivation._(this.relation, this._inner) : super._();

  @override
  final PostgrestRelation<Row, Object?> relation;

  final PostgrestDerivedExpression<Object?, Value> _inner;

  @override
  List<PostgrestSelectable<Object?>> get _selections => [_inner];

  @override
  Value Function(Object json)? get _fromJson => _inner._fromJson;

  @override
  String? get _castKey => _inner._castKey;

  @override
  PostgrestDerivedExpression<Row, Derived> _derive<Derived extends Object>(
    String derivation, {
    required String? key,
    required Derived Function(Object json)? fromJson,
  }) => _EmbeddedDerivation._(
    relation,
    _inner._derive(derivation, key: key, fromJson: fromJson),
  );

  @override
  // ignore: avoid-unnecessary-nullable-return-type
  Value? _read(Object? json, _NestedSelection nested) =>
      throw _embeddedReadError(relation);
}

/// A JSON path read from a stored column, at every position the column is.
///
/// Filters and orders like the column it was read from, and is null-testable
/// whatever the column's own nullability: `data->>name` is `NULL` when the
/// key is absent, even on a `NOT NULL` `jsonb` column. Read from a
/// [PostgrestPartialRow] as `Value?` for the same reason.
///
/// The `select` list sends the path under an alias of its own [expression],
/// `"data->>name":data->>name`, so it never shares a key with the column or
/// another path of it. An expression longer than the 63 bytes Postgres keeps
/// of a name is shortened to a prefix and a digest of the whole.
@experimental
final class PostgrestJsonPath<Row, Value extends Object>
    extends PostgrestColumnExpression<Row, Value>
    with
        PostgrestFilterableExpression<Row, Value>,
        PostgrestOrderableExpression<Row, Value>,
        PostgrestNullableExpression<Row, Value>
    implements PostgrestReadable<Row, Value?> {
  const PostgrestJsonPath._(this.expression) : super._();

  @override
  final String expression;

  @override
  String get responseKey => _expressionKey(expression);

  @override
  String get _selectExpression => _aliased(expression);

  @override
  String? get _castKey => null;

  @override
  Value Function(Object json)? get _fromJson => null;

  @override
  PostgrestJsonPath<Row, String> jsonText(String path) =>
      PostgrestJsonPath._('$expression->>$path');

  @override
  PostgrestJsonPath<Row, Value> jsonObject(String path) =>
      PostgrestJsonPath._('$expression->$path');

  @override
  bool get _selectedByStar => false;

  @override
  Value? _read(Object? json, _NestedSelection nested) {
    if (json == null) return null;
    return json as Value;
  }
}

/// The bytes of a name Postgres keeps, `NAMEDATALEN - 1`.
const _maximumNameBytes = 63;

/// [expression] as a response key: itself, or when it is longer than
/// Postgres keeps of a name, a prefix of it followed by a digest of the whole,
/// so two long expressions sharing a prefix get different keys.
String _expressionKey(String expression) {
  final bytes = utf8.encode(expression);
  if (bytes.length <= _maximumNameBytes) return expression;
  final suffix = '~${sha256.convert(bytes).toString().substring(0, 16)}';
  final prefix = StringBuffer();
  var prefixBytes = 0;
  for (final rune in expression.runes) {
    final character = String.fromCharCode(rune);
    prefixBytes += utf8.encode(character).length;
    if (prefixBytes > _maximumNameBytes - suffix.length) break;
    prefix.write(character);
  }
  return '$prefix$suffix';
}

/// [expression] renamed to its [_expressionKey] in a `select` list.
String _aliased(String expression) {
  final key = _expressionKey(expression).replaceAllMapped(
    RegExp(r'["\\]'),
    (match) => '\\${match[0]}',
  );
  return '"$key":$expression';
}
