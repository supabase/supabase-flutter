part of 'postgrest_typed_builder.dart';

/// Anything that can appear in a `select` list: a stored column, or an
/// expression derived from one.
///
/// [Row] is the row type of the table the expression belongs to. Every
/// filter and ordering built from the expression carries it, so using a
/// column of one table against a query on another is a compile error rather
/// than a PostgREST 400.
///
/// [Value] is the Dart type the expression produces. Operators require a
/// matching operand, so `.eq('seven')` on an `int` column does not compile.
///
/// Stored columns are declared as [PostgrestColumn] or
/// [PostgrestNullableColumn].
@experimental
sealed class PostgrestColumnExpression<Row, Value extends Object> {
  const PostgrestColumnExpression._();

  /// The text PostgREST expects, in a `select` list or on the left of an
  /// operator.
  String get expression;

  /// Applies [derivation] where PostgREST expects it: appended, or inside an
  /// embedded projection's parentheses.
  PostgrestDerivedExpression<Row, Derived> _derive<Derived extends Object>(
    String derivation,
  ) => PostgrestDerivedExpression._(
    embed: null,
    inner: '$expression$derivation',
  );

  /// Casts this expression to another Postgres type, `cost::text`.
  ///
  /// Select position only: PostgREST drops a cast from a filter, so
  /// `cost::text=eq.10` compares the uncast column, and rejects one in
  /// `order`. Make it the last step in a chain, since PostgREST applies only
  /// the first of two casts and rejects a JSON path on a cast.
  PostgrestDerivedExpression<Row, Target> cast<Target extends Object>(
    PostgrestCastTarget<Target> target,
  ) => _derive('::${target.sqlType}');

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

  @override
  String toString() => expression;
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

  /// Only rows whose range value contains [range].
  ///
  /// [range] is a Postgres range literal, for example `[2,3)`.
  PostgrestFilter<Row> containsRange(String range) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.contains,
        range,
      );

  /// Only rows whose range value is contained by [range].
  PostgrestFilter<Row> containedByRange(String range) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.containedBy,
        range,
      );

  /// Only rows whose range value overlaps [range].
  PostgrestFilter<Row> overlapsRange(String range) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.overlaps,
        range,
      );

  /// Only rows whose range value is strictly to the left of [range].
  ///
  /// [range] is a Postgres range literal, for example
  /// `[2024-01-01,2024-02-01)`.
  PostgrestFilter<Row> rangeLt(String range) => PostgrestFilter._comparison(
    this,
    PostgrestFilterOperator.rangeLt,
    range,
  );

  /// Only rows whose range value is strictly to the right of [range].
  PostgrestFilter<Row> rangeGt(String range) => PostgrestFilter._comparison(
    this,
    PostgrestFilterOperator.rangeGt,
    range,
  );

  /// Only rows whose range value does not extend to the left of [range].
  PostgrestFilter<Row> rangeGte(String range) => PostgrestFilter._comparison(
    this,
    PostgrestFilterOperator.rangeGte,
    range,
  );

  /// Only rows whose range value does not extend to the right of [range].
  PostgrestFilter<Row> rangeLte(String range) => PostgrestFilter._comparison(
    this,
    PostgrestFilterOperator.rangeLte,
    range,
  );

  /// Only rows whose range value is adjacent to [range].
  PostgrestFilter<Row> rangeAdjacent(String range) =>
      PostgrestFilter._comparison(
        this,
        PostgrestFilterOperator.rangeAdjacent,
        range,
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
  String get orderKey => expression;

  @override
  PostgrestOrdering<Row> asc() =>
      _Ordering(expression, direction: SortDirection.ascending);

  @override
  PostgrestOrdering<Row> desc() =>
      _Ordering(expression, direction: SortDirection.descending);

  @override
  PostgrestOrdering<Row> nullsFirst() =>
      _Ordering(expression, nulls: _NullPlacement.first);

  @override
  PostgrestOrdering<Row> nullsLast() =>
      _Ordering(expression, nulls: _NullPlacement.last);
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

/// A stored `NOT NULL` column of the table whose rows are [Row].
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
///   );
/// }
/// ```
///
/// [Value] is the column's non-nullable Dart type; a column that allows
/// `NULL` is a [PostgrestNullableColumn].
@experimental
final class PostgrestColumn<Row, Value extends Object>
    extends PostgrestColumnExpression<Row, Value>
    with
        PostgrestFilterableExpression<Row, Value>,
        PostgrestOrderableExpression<Row, Value> {
  /// Creates a reference to the column called [name] in the database.
  const PostgrestColumn(this.name) : super._();

  /// Name of the column in the database.
  final String name;

  @override
  // ignore: match-getter-setter-field-names
  String get expression => name;

  @override
  PostgrestJsonPath<Row, String> jsonText(String path) =>
      PostgrestJsonPath._('$name->>$path');

  @override
  PostgrestJsonPath<Row, Value> jsonObject(String path) =>
      PostgrestJsonPath._('$name->$path');
}

/// A stored column the database allows to be `NULL`.
///
/// [Value] stays the non-nullable type, `PostgrestNullableColumn<Row, String>`
/// for a nullable `text` column; `NULL` is tested with
/// [PostgrestNullableExpression.isNull].
@experimental
final class PostgrestNullableColumn<Row, Value extends Object>
    extends PostgrestColumn<Row, Value>
    with PostgrestNullableExpression<Row, Value> {
  /// Creates a reference to the nullable column called [name] in the
  /// database.
  const PostgrestNullableColumn(super.name);
}
