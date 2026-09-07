part of 'postgrest_typed_builder.dart';

/// A PostgREST filter operator and the token it is sent as.
@experimental
enum PostgrestFilterOperator {
  /// Equals, `eq`.
  eq('eq'),

  /// Does not equal, `neq`.
  neq('neq'),

  /// Greater than, `gt`.
  gt('gt'),

  /// Greater than or equal to, `gte`.
  gte('gte'),

  /// Less than, `lt`.
  lt('lt'),

  /// Less than or equal to, `lte`.
  lte('lte'),

  /// Is distinct from, `isdistinct`.
  isDistinct('isdistinct'),

  /// The `IS` check for `null`, `true` and `false`, `is`.
  isFilter('is'),

  /// One of a list of values, `in`.
  inFilter('in'),

  /// Case-sensitive `LIKE`, `like`.
  like('like'),

  /// Case-insensitive `LIKE`, `ilike`.
  ilike('ilike'),

  /// Case-sensitive POSIX regular expression, `match`.
  matchRegex('match'),

  /// Case-insensitive POSIX regular expression, `imatch`.
  imatchRegex('imatch'),

  /// Case-sensitive `LIKE ALL`, `like(all)`.
  likeAllOf('like(all)'),

  /// Case-sensitive `LIKE ANY`, `like(any)`.
  likeAnyOf('like(any)'),

  /// Case-insensitive `LIKE ALL`, `ilike(all)`.
  ilikeAllOf('ilike(all)'),

  /// Case-insensitive `LIKE ANY`, `ilike(any)`.
  ilikeAnyOf('ilike(any)'),

  /// Contains, `cs`.
  contains('cs'),

  /// Contained by, `cd`.
  containedBy('cd'),

  /// Overlaps, `ov`.
  overlaps('ov'),

  /// Range strictly left of, `sl`.
  rangeLt('sl'),

  /// Range strictly right of, `sr`.
  rangeGt('sr'),

  /// Range does not extend to the left of, `nxl`.
  rangeGte('nxl'),

  /// Range does not extend to the right of, `nxr`.
  rangeLte('nxr'),

  /// Range adjacent to, `adj`.
  rangeAdjacent('adj'),

  /// Full text search, `fts`, prefixed by the query type and suffixed by the
  /// configuration when given.
  textSearch('fts');

  const PostgrestFilterOperator(this.token);

  /// The operator as it appears after the column in a query parameter.
  final String token;
}

/// A filter on the rows of a table, built from the operator methods on a
/// [PostgrestFilterableExpression] and composed with `&`, `|` and [not]:
///
/// ```dart
/// final List<Book> books = await client
///     .table(Books.table)
///     .select()
///     .where(
///       (Books.isDone.eq(false) & Books.priority.gt(3)) | Books.id.eq(7),
///     );
/// ```
///
/// A top-level `&` renders as separate query parameters, `|` as one
/// `or=(…)`, and an `&` nested inside a `|` as `and(…)`.
///
/// [Row] is the row type of the table the filter belongs to, so a filter on
/// one table cannot be applied to a query on another.
@experimental
final class PostgrestFilter<Row> {
  const PostgrestFilter._(this._node);

  PostgrestFilter._comparison(
    PostgrestFilterableExpression<Row, Object> column,
    PostgrestFilterOperator operator,
    Object? value,
  ) : _node = _Comparison(column, operator, value);

  PostgrestFilter._textSearch(
    PostgrestFilterableExpression<Row, Object> column,
    String query, {
    required String? config,
    required TextSearchType? type,
  }) : _node = _TextSearch(column, query, config: config, type: type);

  PostgrestFilter._raw(String column, String operand)
    : _node = _Raw(column, operand);

  final _FilterNode<Row> _node;

  /// A filter written entirely in PostgREST syntax, for an expression no
  /// column can name.
  ///
  /// Nothing here is checked. Prefer [PostgrestFilterableExpression.raw],
  /// which keeps the column compile-time checked and takes only the operand
  /// as a string.
  ///
  /// ```dart
  /// .where(
  ///   Books.isDone.eq(false) & PostgrestFilter.raw('cost::text', 'eq.10'),
  /// )
  /// ```
  ///
  /// The filter is sent as written, so keep it out of any subtree beneath `|`
  /// or [not] unless it is valid inside `or=(…)`; a `::` in the column name,
  /// for example, parses at top level only.
  ///
  /// [column] is the query parameter name, for example `cost::text`, and
  /// [operand] everything after the `=`, for example `eq.10`.
  static PostgrestFilter<Row> raw<Row>(String column, String operand) =>
      PostgrestFilter._raw(column, operand);

  /// Only rows satisfying both this filter and [other].
  PostgrestFilter<Row> operator &(PostgrestFilter<Row> other) =>
      PostgrestFilter._(_And([..._andParts(_node), ..._andParts(other._node)]));

  /// Only rows satisfying this filter, [other], or both.
  PostgrestFilter<Row> operator |(PostgrestFilter<Row> other) =>
      PostgrestFilter._(_Or([..._orParts(_node), ..._orParts(other._node)]));

  /// Only rows that do not satisfy this filter.
  PostgrestFilter<Row> not() => PostgrestFilter._(_Not(_node));

  /// The query parameters this filter contributes to a request.
  @internal
  List<({String key, String value})> get queryParameters =>
      _queryParameters(_node);

  /// The one comparison this filter consists of, or `null` for a raw or a
  /// composed filter.
  PostgrestComparison<Row>? get comparison => switch (_node) {
    _Comparison(:final column, :final operator, :final value) =>
      PostgrestComparison._(column, operator, value),
    _Raw() || _And() || _Or() || _Not() => null,
  };

  /// Absorbs a child `&` so `a & b & c` renders flat rather than nested.
  static List<_FilterNode<Row>> _andParts<Row>(_FilterNode<Row> node) =>
      switch (node) {
        _And(:final children) => children,
        _Comparison() || _Raw() || _Or() || _Not() => [node],
      };

  /// Absorbs a child `|` so `a | b | c` renders `or=(a,b,c)` rather than
  /// `or=(or(a,b),c)`.
  static List<_FilterNode<Row>> _orParts<Row>(_FilterNode<Row> node) =>
      switch (node) {
        _Or(:final children) => children,
        _Comparison() || _Raw() || _And() || _Not() => [node],
      };
}

/// One operator applied to one column, the shape a consumer that cannot
/// apply a whole tree, such as a realtime stream, reads through
/// [PostgrestFilter.comparison].
@experimental
final class PostgrestComparison<Row> {
  const PostgrestComparison._(this.column, this.operator, this.value);

  /// The expression on the left of the operator.
  final PostgrestFilterableExpression<Row, Object> column;

  /// The operator.
  final PostgrestFilterOperator operator;

  /// The operand as it was given: the value for a comparison, a `List` for
  /// `in` and the array operators, and `null`, `true` or `false` for `is`.
  final Object? value;
}

sealed class _FilterNode<Row> {
  const _FilterNode();
}

/// One operator applied to one column.
base class _Comparison<Row> extends _FilterNode<Row> {
  const _Comparison(this.column, this.operator, this.value);

  final PostgrestFilterableExpression<Row, Object> column;
  final PostgrestFilterOperator operator;

  /// The operand as given, rendered when the request is built.
  final Object? value;

  String get operatorToken => operator.token;

  /// The operand as sent at top level.
  String get operand {
    if (operator == PostgrestFilterOperator.inFilter) {
      final members = (value! as List<Object?>).map(
        (member) => _escapeFilterValue(_renderFilterValue(member)),
      );
      return '(${members.join(',')})';
    }
    return _renderFilterValue(value);
  }

  /// The operand as sent inside a group, escaped. The parentheses of an `in`
  /// list stay literal there; its members are escaped already.
  String get groupOperand {
    if (operator == PostgrestFilterOperator.inFilter) return operand;
    return _escapeFilterValue(operand);
  }
}

/// A full text search, whose operator token carries the query type and the
/// configuration: `wfts(english)`.
final class _TextSearch<Row> extends _Comparison<Row> {
  const _TextSearch(
    PostgrestFilterableExpression<Row, Object> column,
    String query, {
    required this.config,
    required this.type,
  }) : super(column, PostgrestFilterOperator.textSearch, query);

  final String? config;
  final TextSearchType? type;

  @override
  String get operatorToken {
    final prefix = switch (type) {
      TextSearchType.plain => 'pl',
      TextSearchType.phrase => 'ph',
      TextSearchType.websearch => 'w',
      null => '',
    };
    final suffix = config == null ? '' : '($config)';
    return '$prefix${operator.token}$suffix';
  }
}

/// Everything after the `=` as one string, sent as written in every position.
final class _Raw<Row> extends _FilterNode<Row> {
  const _Raw(this.column, this.operand);

  final String column;
  final String operand;
}

final class _And<Row> extends _FilterNode<Row> {
  const _And(this.children);

  final List<_FilterNode<Row>> children;
}

final class _Or<Row> extends _FilterNode<Row> {
  const _Or(this.children);

  final List<_FilterNode<Row>> children;
}

final class _Not<Row> extends _FilterNode<Row> {
  const _Not(this.inner);

  final _FilterNode<Row> inner;
}

List<({String key, String value})> _queryParameters<Row>(
  _FilterNode<Row> node,
) => switch (node) {
  _Comparison(:final column, :final operatorToken, :final operand) => [
    (key: column.expression, value: '$operatorToken.$operand'),
  ],
  _Raw(:final column, :final operand) => [(key: column, value: operand)],
  _And(:final children) => [
    for (final child in children) ..._queryParameters(child),
  ],
  _Or(:final children) => [(key: 'or', value: _groupList(children))],
  _Not(inner: _And(:final children)) => [
    (key: 'not.and', value: _groupList(children)),
  ],
  _Not(inner: _Or(:final children)) => [
    (key: 'not.or', value: _groupList(children)),
  ],
  _Not(
    inner: _Comparison(:final column, :final operatorToken, :final operand),
  ) =>
    [
      (key: column.expression, value: 'not.$operatorToken.$operand'),
    ],
  _Not(inner: _Raw(:final column, :final operand)) => [
    (key: column, value: 'not.$operand'),
  ],
  _Not(inner: _Not(:final inner)) => _queryParameters(inner),
};

String _groupList<Row>(List<_FilterNode<Row>> children) =>
    '(${children.map(_group).join(',')})';

/// A node in the comma-separated form used inside `or=(…)`: an AND is spelled
/// `and(…)`, operands are escaped, a negated leaf puts `not.` after the
/// column (`id.not.eq.2`) while a negated group keeps it in front
/// (`not.and(…)`), and double negation collapses.
String _group<Row>(_FilterNode<Row> node) => switch (node) {
  _Comparison(:final column, :final operatorToken, :final groupOperand) =>
    '${column.expression}.$operatorToken.$groupOperand',
  _Raw(:final column, :final operand) => '$column.$operand',
  _And(:final children) => 'and${_groupList(children)}',
  _Or(:final children) => 'or${_groupList(children)}',
  _Not(inner: _Not(:final inner)) => _group(inner),
  _Not(inner: final inner && (_And() || _Or())) => 'not.${_group(inner)}',
  _Not(
    inner: _Comparison(
      :final column,
      :final operatorToken,
      :final groupOperand,
    ),
  ) =>
    '${column.expression}.not.$operatorToken.$groupOperand',
  _Not(inner: _Raw(:final column, :final operand)) => '$column.not.$operand',
};

/// Renders an operand the way PostgREST expects it after the operator.
///
/// - `null` is `NULL`, for the `is` check.
/// - A [String] is sent as is.
/// - A [DateTime] is sent in ISO 8601, so a UTC instant carries its `Z`.
/// - A [List] becomes a Postgres array literal, `{a,b}`, with each element
///   escaped as the literal requires.
/// - A [Map] is encoded as JSON, for `json`/`jsonb` columns.
/// - Anything else uses its [Object.toString], which for a Dart enum
///   generated by `supabase_typegen` is the database wire name.
String _renderFilterValue(Object? value) => switch (value) {
  null => 'null',
  String() => value,
  DateTime() => value.toIso8601String(),
  List() => _renderArrayLiteral(value),
  Map() => json.encode(value),
  _ => value.toString(),
};

/// `{a,b}`, the array literal the array operators and an array-typed
/// comparison take. A nested list is a nested literal, and `null` is SQL
/// `NULL`.
String _renderArrayLiteral(List<Object?> values) {
  final elements = values.map(
    (element) => switch (element) {
      null => 'NULL',
      List() => _renderArrayLiteral(element),
      _ => _escapeArrayElement(_renderFilterValue(element)),
    },
  );
  return '{${elements.join(',')}}';
}

/// Characters that carry structural meaning in a PostgREST filter value list,
/// such as `in.(a,b)` or `or=(…)`, and therefore require quoting.
const _filterReservedCharacters = [',', '(', ')', '"', r'\'];

/// Characters that carry structural meaning inside a Postgres array literal,
/// such as `cs.{a,b}`, and therefore require quoting.
const _arrayReservedCharacters = [',', '{', '}', '"', r'\'];

/// Quotes [raw] when it is empty, contains a filter-reserved character or has
/// surrounding whitespace, escaping `\` and `"` inside the quotes.
String _escapeFilterValue(String raw) {
  final needsQuoting =
      raw.isEmpty ||
      _filterReservedCharacters.any(raw.contains) ||
      raw != raw.trim();
  return needsQuoting ? _quote(raw) : raw;
}

/// Quotes [raw] when it is empty, spells `NULL`, contains an array-reserved
/// character or has surrounding whitespace, escaping `\` and `"` inside the
/// quotes.
String _escapeArrayElement(String raw) {
  final needsQuoting =
      raw.isEmpty ||
      raw.toUpperCase() == 'NULL' ||
      _arrayReservedCharacters.any(raw.contains) ||
      raw != raw.trim();
  return needsQuoting ? _quote(raw) : raw;
}

String _quote(String raw) =>
    '"${raw.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
