part of 'postgrest_typed_builder.dart';

/// Anything that can appear in a `select` list.
///
/// [Row] is the row type of the table the entry belongs to, so selecting an
/// entry of one table from a query on another is a compile error rather than
/// a PostgREST 400.
///
/// A [PostgrestColumnExpression] is a single value of the row: a stored
/// column or something derived from one. A [PostgrestEmbed] is an embedded
/// relation selected as a whole.
@experimental
sealed class PostgrestSelectable<Row> {
  const PostgrestSelectable._();

  /// The text PostgREST expects in a `select` list and, for a column
  /// expression, on the left of an operator.
  String get expression;

  /// The key the entry comes back under in a response row: the column name,
  /// the function name of an aggregate, the last key of a JSON path, or the
  /// [PostgrestRelation.key] of an embed.
  String get responseKey;

  @override
  String toString() => expression;
}

/// A single value of the row in a `select` list: a stored column, or an
/// expression derived from one.
///
/// Every filter and ordering built from the expression carries [Row], so
/// using a column of one table against a query on another is a compile error
/// rather than a PostgREST 400.
///
/// [Value] is the Dart type the expression produces. Operators require a
/// matching operand, so `.eq('seven')` on an `int` column does not compile.
///
/// Stored columns are declared as [PostgrestColumn] or
/// [PostgrestNullableColumn].
@experimental
sealed class PostgrestColumnExpression<Row, Value extends Object>
    extends PostgrestSelectable<Row> {
  const PostgrestColumnExpression._() : super._();

  /// The text PostgREST expects in `order`; differs from [expression] for an
  /// aliased embed.
  String get _orderKey => expression;

  /// Converts the decoded JSON of a present value into [Value], or `null`
  /// when the decoded JSON is the value.
  Value Function(Object json)? get _fromJson;

  /// Applies [derivation] where PostgREST expects it: appended, or inside an
  /// embedded projection's parentheses. The result comes back under [key]
  /// and is decoded with [fromJson].
  PostgrestDerivedExpression<Row, Derived> _derive<Derived extends Object>(
    String derivation, {
    required String key,
    required Derived Function(Object json)? fromJson,
  }) => _Derivation._('$expression$derivation', key, fromJson);

  /// Casts this expression to another Postgres type, `cost::text`.
  ///
  /// Select position only: PostgREST drops a cast from a filter, so
  /// `cost::text=eq.10` compares the uncast column, and rejects one in
  /// `order`. Make it the last step in a chain, since PostgREST applies only
  /// the first of two casts and rejects a JSON path on a cast.
  ///
  /// The cast value comes back under the key of what was cast.
  PostgrestDerivedExpression<Row, Target> cast<Target extends Object>(
    PostgrestCastTarget<Target> target,
  ) => _derive(
    '::${target.sqlType}',
    key: responseKey,
    fromJson: target._fromJson,
  );

  /// Reads a `json`/`jsonb` path as text, with `->>`.
  ///
  /// ```dart
  /// .where(Items.data.jsonText('name').eq('Ada')) // data->>name=eq.Ada
  /// ```
  ///
  /// Comparison is textual, so `data->>n=gt.2` excludes a row where `n` is
  /// `10`; use [jsonObject] for numeric comparison. The result keeps the
  /// positions of what it was applied to.
  PostgrestColumnExpression<Row, String> jsonText(String path);

  /// Reads a `json`/`jsonb` path as JSON, with `->`.
  ///
  /// Comparison is numeric for numbers, so `data->n=gt.2` includes a row
  /// where `n` is `10`.
  ///
  /// The result keeps this expression's [Value], but `->` returns `jsonb`;
  /// chain [jsonText] or [cast] to reach a scalar.
  PostgrestColumnExpression<Row, Value> jsonObject(String path);

  /// The sum of this expression across the group, typed [double] whatever
  /// the column's type. Past 2^53 the value rounds silently.
  ///
  /// {@template postgrest_aggregate}
  /// Select position only: PostgREST has no `HAVING` and rejects an aggregate
  /// in `order`. Selecting a plain column alongside an aggregate groups by
  /// it. Needs PostgREST's `db-aggregates-enabled` setting, which is on for
  /// hosted Supabase. The response is keyed by the function name alone, so
  /// two aggregates of the same function in one `select` collide. `sum`,
  /// `avg`, `min` and `max` are `null` when no row matches; the type
  /// parameter describes a present value.
  /// {@endtemplate}
  PostgrestDerivedExpression<Row, double> sum() => _derive(
    _AggregateFunction.sum.suffix,
    key: _AggregateFunction.sum.name,
    fromJson: _toDouble,
  );

  /// The mean of this expression across the group.
  ///
  /// {@macro postgrest_aggregate}
  PostgrestDerivedExpression<Row, double> avg() => _derive(
    _AggregateFunction.avg.suffix,
    key: _AggregateFunction.avg.name,
    fromJson: _toDouble,
  );

  /// The smallest value of this expression in the group, keeping the
  /// expression's own type.
  ///
  /// {@macro postgrest_aggregate}
  PostgrestDerivedExpression<Row, Value> min() => _derive(
    _AggregateFunction.min.suffix,
    key: _AggregateFunction.min.name,
    fromJson: _fromJson,
  );

  /// The largest value of this expression in the group, keeping the
  /// expression's own type.
  ///
  /// {@macro postgrest_aggregate}
  PostgrestDerivedExpression<Row, Value> max() => _derive(
    _AggregateFunction.max.suffix,
    key: _AggregateFunction.max.name,
    fromJson: _fromJson,
  );

  /// How many non-null values of this expression are in the group.
  ///
  /// Use [PostgrestDerivedExpression.countAll] to count rows instead.
  ///
  /// {@macro postgrest_aggregate}
  PostgrestDerivedExpression<Row, int> count() => _derive(
    _AggregateFunction.count.suffix,
    key: _AggregateFunction.count.name,
    fromJson: null,
  );
}

/// Reads a number PostgREST may have sent as a JSON integer as a [double].
double _toDouble(Object json) => (json as num).toDouble();

/// The aggregate functions PostgREST applies to a `select` list entry.
enum _AggregateFunction {
  sum,
  avg,
  min,
  max,
  count;

  /// The call appended to the expression, `.sum()`.
  String get suffix => '.$name()';
}

/// A column expression that can also sit on the left of a filter operator.
///
/// Each PostgREST operator is a method here, returning a [PostgrestFilter]
/// that [PostgrestTypedFilterBuilder.where] applies and that composes with
/// `&`, `|` and [PostgrestFilter.not].
///
/// Expression kinds PostgREST cannot filter on do not mix this in.
@experimental
base mixin PostgrestFilterableExpression<Row, Value extends Object>
    on PostgrestColumnExpression<Row, Value> {
  /// Only rows where this expression equals [value].
  ///
  /// `null` is not accepted; use [PostgrestNullableExpression.isNull] to
  /// test for SQL `NULL`.
  PostgrestFilter<Row> eq(Value value) =>
      PostgrestFilter._comparison(this, PostgrestFilterOperator.eq, value);

  /// Only rows where this expression does not equal [value].
  PostgrestFilter<Row> neq(Value value) => PostgrestFilter._comparison(
    this,
    PostgrestFilterOperator.neq,
    value,
  );

  /// Only rows where this expression is greater than [value].
  PostgrestFilter<Row> gt(Value value) =>
      PostgrestFilter._comparison(this, PostgrestFilterOperator.gt, value);

  /// Only rows where this expression is greater than or equal to [value].
  PostgrestFilter<Row> gte(Value value) => PostgrestFilter._comparison(
    this,
    PostgrestFilterOperator.gte,
    value,
  );

  /// Only rows where this expression is less than [value].
  PostgrestFilter<Row> lt(Value value) =>
      PostgrestFilter._comparison(this, PostgrestFilterOperator.lt, value);

  /// Only rows where this expression is less than or equal to [value].
  PostgrestFilter<Row> lte(Value value) => PostgrestFilter._comparison(
    this,
    PostgrestFilterOperator.lte,
    value,
  );

  /// Only rows where this expression is distinct from [value].
  ///
  /// Unlike [neq], a `NULL` row matches any operand.
  PostgrestFilter<Row> isDistinct(Value value) => PostgrestFilter._comparison(
    this,
    PostgrestFilterOperator.isDistinct,
    value,
  );

  /// Applies an operator this package has no method for, keeping the column
  /// compile-time checked.
  ///
  /// ```dart
  /// .where(Books.tags.raw('someop.value')) // tags=someop.value
  /// ```
  ///
  /// The operand is sent unescaped, so keep the filter out of any subtree
  /// beneath `|` or [PostgrestFilter.not] unless it is valid inside `or=(…)`.
  PostgrestFilter<Row> raw(String operand) =>
      PostgrestFilter._raw(expression, operand);

  /// Only rows where this expression equals one of [values].
  ///
  /// There is no `notIn`; negate instead: `Books.id.inFilter([1, 2]).not()`
  /// renders `id=not.in.(1,2)`.
  ///
  /// An empty [values] matches no rows.
  PostgrestFilter<Row> inFilter(List<Value> values) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.inFilter,
        values,
      );

  /// Only rows whose `json`/`jsonb` value contains [value].
  ///
  /// [value] is the decoded JSON to look for, for example `{'a': 1}` or
  /// `null`, and is encoded before it is sent.
  PostgrestFilter<Row> containsJson(Object? value) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.contains,
        json.encode(value),
      );

  /// Only rows whose `json`/`jsonb` value is contained by [value].
  PostgrestFilter<Row> containedByJson(Object? value) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.containedBy,
        json.encode(value),
      );

  /// Only rows whose `text` or `tsvector` value matches the full text search
  /// [query].
  ///
  /// [config] is the text search configuration, for example `english`;
  /// omitted, the database default applies. [type] chooses how [query] is
  /// turned into a `tsquery`; omitted, `to_tsquery` is used.
  PostgrestFilter<Row> textSearch(
    String query, {
    String? config,
    TextSearchType? type,
  }) => PostgrestFilter._textSearch(
    this,
    query,
    config: config,
    type: type,
  );
}

/// A column expression that can be used as an `order` key.
///
/// On its own it is a [PostgrestOrdering] with no direction, so
/// `order(Books.title)` sends `order=title`. Chain [asc], [desc],
/// [nullsFirst] or [nullsLast] to say more.
@experimental
base mixin PostgrestOrderableExpression<Row, Value extends Object>
    on PostgrestColumnExpression<Row, Value>
    implements PostgrestOrdering<Row> {
  @override
  String get orderKey => _orderKey;

  @override
  PostgrestOrdering<Row> asc() =>
      _Ordering(_orderKey, direction: SortDirection.ascending);

  @override
  PostgrestOrdering<Row> desc() =>
      _Ordering(_orderKey, direction: SortDirection.descending);

  @override
  PostgrestOrdering<Row> nullsFirst() =>
      _Ordering(_orderKey, nulls: _NullPlacement.first);

  @override
  PostgrestOrdering<Row> nullsLast() =>
      _Ordering(_orderKey, nulls: _NullPlacement.last);
}

/// A filterable expression whose value the database allows to be `NULL`,
/// which is what makes [isNull] available.
@experimental
base mixin PostgrestNullableExpression<Row, Value extends Object>
    on PostgrestFilterableExpression<Row, Value> {
  /// Only rows where this expression is SQL `NULL`.
  ///
  /// There is no `isNotNull`; negate instead: `Books.dueDate.isNull().not()`
  /// renders `due_date=not.is.null`.
  PostgrestFilter<Row> isNull() =>
      PostgrestFilter._comparison(this, PostgrestFilterOperator.isFilter, null);
}

/// `IS` checks that only apply to boolean columns.
@experimental
extension PostgrestBooleanFilters<Row>
    on PostgrestFilterableExpression<Row, bool> {
  /// Only rows where this boolean expression `IS TRUE`.
  ///
  /// On a nullable column this differs from `eq(true)`: `eq.true` is unknown
  /// for a `NULL` row, `is.true` is false.
  PostgrestFilter<Row> isTrue() =>
      PostgrestFilter._comparison(this, PostgrestFilterOperator.isFilter, true);

  /// Only rows where this boolean expression `IS FALSE`.
  PostgrestFilter<Row> isFalse() => PostgrestFilter._comparison(
    this,
    PostgrestFilterOperator.isFilter,
    false,
  );
}

/// A stored column of the table whose rows are [Row]: a [PostgrestColumn]
/// when the database forbids `NULL`, a [PostgrestNullableColumn] when it
/// allows it.
///
/// Declared once per column, normally by `supabase_typegen`, as a static
/// member of the table's namespace class:
///
/// ```dart
/// class Books {
///   static const table = PostgrestTable('books', BooksRow.new);
///   static const id = PostgrestColumn<BooksRow, int>('id');
///   static const title = PostgrestColumn<BooksRow, String>('title');
///   static const dueDate = PostgrestNullableColumn<BooksRow, DateTime>(
///     'due_date',
///     fromJson: _dateTimeFromJson,
///   );
/// }
///
/// DateTime _dateTimeFromJson(Object json) => DateTime.parse(json as String);
/// ```
///
/// [Value] is the column's non-nullable Dart type; it is the operand type of
/// every filter, and what [PostgrestPartialRow.read] produces, nullable for a
/// [PostgrestNullableColumn].
///
/// `fromJson` converts the decoded JSON of a present value into [Value]. Left
/// out, the decoded JSON is cast to [Value], which is right for `int`,
/// `num`, `bool`, `String` and `Object`. `supabase_typegen` supplies it for
/// every column whose Dart type differs from its JSON representation.
@experimental
sealed class PostgrestStoredColumn<Row, Value extends Object>
    extends PostgrestColumnExpression<Row, Value>
    with
        PostgrestFilterableExpression<Row, Value>,
        PostgrestOrderableExpression<Row, Value> {
  const PostgrestStoredColumn._(this.name, this._fromJson) : super._();

  /// Name of the column in the database.
  final String name;

  @override
  final Value Function(Object json)? _fromJson;

  @override
  // ignore: match-getter-setter-field-names
  String get expression => name;

  @override
  // ignore: match-getter-setter-field-names
  String get responseKey => name;

  /// [json], the decoded JSON of a present value, as [Value].
  Value _decode(Object json) => switch (_fromJson) {
    null => json as Value,
    final fromJson => fromJson(json),
  };

  @override
  PostgrestJsonPath<Row, String> jsonText(String path) =>
      PostgrestJsonPath._('$name->>$path', path);

  @override
  PostgrestJsonPath<Row, Value> jsonObject(String path) =>
      PostgrestJsonPath._('$name->$path', path);
}

/// A stored `NOT NULL` column, see [PostgrestStoredColumn].
///
/// Read from a [PostgrestPartialRow] as [Value].
@experimental
final class PostgrestColumn<Row, Value extends Object>
    extends PostgrestStoredColumn<Row, Value>
    implements PostgrestReadable<Row, Value> {
  /// Creates a reference to the column called [name] in the database.
  const PostgrestColumn(String name, {Value Function(Object json)? fromJson})
    : super._(name, fromJson);

  @override
  Value _read(Object? json, _NestedSelection nested) => _decode(json as Object);

  @override
  bool get _selectedByStar => true;
}

/// A stored column the database allows to be `NULL`, see
/// [PostgrestStoredColumn].
///
/// [Value] stays the non-nullable type, `PostgrestNullableColumn<Row, String>`
/// for a nullable `text` column; `NULL` is tested with
/// [PostgrestNullableExpression.isNull], and the column is read from a
/// [PostgrestPartialRow] as `Value?`.
@experimental
final class PostgrestNullableColumn<Row, Value extends Object>
    extends PostgrestStoredColumn<Row, Value>
    with PostgrestNullableExpression<Row, Value>
    implements PostgrestReadable<Row, Value?> {
  /// Creates a reference to the nullable column called [name] in the
  /// database.
  const PostgrestNullableColumn(
    String name, {
    Value Function(Object json)? fromJson,
  }) : super._(name, fromJson);

  @override
  Value? _read(Object? json, _NestedSelection nested) =>
      json == null ? null : _decode(json);

  @override
  bool get _selectedByStar => true;
}
