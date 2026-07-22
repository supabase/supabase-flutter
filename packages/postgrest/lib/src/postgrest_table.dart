part of 'postgrest_typed_builder.dart';

/// Converts a single decoded PostgREST row into [Row].
typedef RowConverter<Row> = Row Function(Map<String, dynamic> json);

/// Describes a database table (or view) together with the Dart type its rows
/// are converted into.
///
/// Passing a [PostgrestTable] to [PostgrestClient.table] gives fully typed
/// query results, so no raw `Map<String, dynamic>` needs to be handled:
///
/// ```dart
/// extension type Book(Map<String, dynamic> json) {
///   int get id => json['id'] as int;
///   String get title => json['title'] as String;
/// }
///
/// class Books {
///   static const table = PostgrestTable('books', Book.new);
///   static const id = TableColumn<int>('id');
///   static const title = TableColumn<String>('title');
/// }
///
/// final List<Book> books = await client
///     .table(Books.table)
///     .select()
///     .where(Books.title.like('%Dart%'));
/// ```
///
/// Extension types over the decoded JSON map (as above) are the recommended
/// row representation since they carry no conversion cost and tolerate
/// partial selects, but any converter works, for example `Book.fromJson` on a
/// regular data class.
class PostgrestTable<Row> {
  const PostgrestTable(this.name, this.rowFromJson);

  /// Name of the table in the database.
  final String name;

  /// Converts a decoded row into [Row].
  final RowConverter<Row> rowFromJson;
}

/// A reference to a column of type [Value] on a database table.
///
/// Used to build compile-time checked filters through methods like
/// [TableColumn.eq], which only accept values matching the column type.
///
/// [Value] is always the non-nullable value type of the column. Null checks
/// are expressed with [isNull] and [isNotNull] instead of nullable values.
class TableColumn<Value extends Object> {
  const TableColumn(this.name);

  /// Name of the column in the database.
  final String name;

  @override
  String toString() => name;

  /// Only rows where this column equals [value].
  ///
  /// For `null` equality, use [isNull] instead.
  ColumnFilter eq(Value value) =>
      ColumnFilter._(name, 'eq', value, (builder) => builder.eq(name, value));

  /// Only rows where this column does not equal [value].
  ColumnFilter neq(Value value) =>
      ColumnFilter._(name, 'neq', value, (builder) => builder.neq(name, value));

  /// Only rows where this column is greater than [value].
  ColumnFilter gt(Value value) =>
      ColumnFilter._(name, 'gt', value, (builder) => builder.gt(name, value));

  /// Only rows where this column is greater than or equal to [value].
  ColumnFilter gte(Value value) =>
      ColumnFilter._(name, 'gte', value, (builder) => builder.gte(name, value));

  /// Only rows where this column is less than [value].
  ColumnFilter lt(Value value) =>
      ColumnFilter._(name, 'lt', value, (builder) => builder.lt(name, value));

  /// Only rows where this column is less than or equal to [value].
  ColumnFilter lte(Value value) =>
      ColumnFilter._(name, 'lte', value, (builder) => builder.lte(name, value));

  /// Only rows where this column is `null`.
  ColumnFilter isNull() => ColumnFilter._(
    name,
    'is',
    null,
    (builder) => builder.isFilter(name, null),
  );

  /// Only rows where this column is not `null`.
  ColumnFilter isNotNull() => isNull().not();

  /// Only rows where this column equals one of [values].
  ColumnFilter inFilter(List<Value> values) => ColumnFilter._(
    name,
    'in',
    values,
    (builder) => builder.inFilter(name, values),
  );

  /// Only rows where this column is not equal to [value], treating `null` as
  /// a comparable value.
  ColumnFilter isDistinctFrom(Value? value) => ColumnFilter._(
    name,
    'isdistinct',
    value,
    (builder) => builder.isDistinct(name, value),
  );

  /// Only rows whose json, array, or range value contains [value].
  ///
  /// See [PostgrestFilterBuilder.contains] for the accepted value shapes.
  ColumnFilter contains(Object value) => ColumnFilter._(
    name,
    'cs',
    value,
    (builder) => builder.contains(name, value),
  );

  /// Only rows whose json, array, or range value is contained by [value].
  ///
  /// See [PostgrestFilterBuilder.containedBy] for the accepted value shapes.
  ColumnFilter containedBy(Object value) => ColumnFilter._(
    name,
    'cd',
    value,
    (builder) => builder.containedBy(name, value),
  );

  /// Only rows whose array or range value overlaps with [value].
  ColumnFilter overlaps(Object value) => ColumnFilter._(
    name,
    'ov',
    value,
    (builder) => builder.overlaps(name, value),
  );

  /// Only rows whose range value is strictly to the left of [range].
  ColumnFilter rangeLt(String range) => ColumnFilter._(
    name,
    'sl',
    range,
    (builder) => builder.rangeLt(name, range),
  );

  /// Only rows whose range value is strictly to the right of [range].
  ColumnFilter rangeGt(String range) => ColumnFilter._(
    name,
    'sr',
    range,
    (builder) => builder.rangeGt(name, range),
  );

  /// Only rows whose range value does not extend to the left of [range].
  ColumnFilter rangeGte(String range) => ColumnFilter._(
    name,
    'nxl',
    range,
    (builder) => builder.rangeGte(name, range),
  );

  /// Only rows whose range value does not extend to the right of [range].
  ColumnFilter rangeLte(String range) => ColumnFilter._(
    name,
    'nxr',
    range,
    (builder) => builder.rangeLte(name, range),
  );

  /// Only rows whose range value is adjacent to [range].
  ColumnFilter rangeAdjacent(String range) => ColumnFilter._(
    name,
    'adj',
    range,
    (builder) => builder.rangeAdjacent(name, range),
  );
}

/// Filters that only apply to text columns.
extension TextTableColumnFilters on TableColumn<String> {
  /// Only rows whose value matches [pattern] case-sensitively.
  ColumnFilter like(String pattern) => ColumnFilter._(
    name,
    'like',
    pattern,
    (builder) => builder.like(name, pattern),
  );

  /// Only rows whose value matches all of [patterns] case-sensitively.
  ColumnFilter likeAllOf(List<String> patterns) => ColumnFilter._(
    name,
    'like(all)',
    patterns,
    (builder) => builder.likeAllOf(name, patterns),
  );

  /// Only rows whose value matches any of [patterns] case-sensitively.
  ColumnFilter likeAnyOf(List<String> patterns) => ColumnFilter._(
    name,
    'like(any)',
    patterns,
    (builder) => builder.likeAnyOf(name, patterns),
  );

  /// Only rows whose value matches [pattern] case-insensitively.
  ColumnFilter ilike(String pattern) => ColumnFilter._(
    name,
    'ilike',
    pattern,
    (builder) => builder.ilike(name, pattern),
  );

  /// Only rows whose value matches all of [patterns] case-insensitively.
  ColumnFilter ilikeAllOf(List<String> patterns) => ColumnFilter._(
    name,
    'ilike(all)',
    patterns,
    (builder) => builder.ilikeAllOf(name, patterns),
  );

  /// Only rows whose value matches any of [patterns] case-insensitively.
  ColumnFilter ilikeAnyOf(List<String> patterns) => ColumnFilter._(
    name,
    'ilike(any)',
    patterns,
    (builder) => builder.ilikeAnyOf(name, patterns),
  );

  /// Only rows whose value matches [pattern] as a PostgreSQL regular
  /// expression, case-sensitively.
  ColumnFilter matchRegex(String pattern) => ColumnFilter._(
    name,
    'match',
    pattern,
    (builder) => builder.matchRegex(name, pattern),
  );

  /// Only rows whose value matches [pattern] as a PostgreSQL regular
  /// expression, case-insensitively.
  ColumnFilter imatchRegex(String pattern) => ColumnFilter._(
    name,
    'imatch',
    pattern,
    (builder) => builder.imatchRegex(name, pattern),
  );

  /// Only rows whose text or tsvector value matches the tsquery in [query].
  ///
  /// See [PostgrestFilterBuilder.textSearch] for [config] and [type].
  ColumnFilter textSearch(
    String query, {
    String? config,
    TextSearchType? type,
  }) {
    final typePart = switch (type) {
      TextSearchType.plain => 'pl',
      TextSearchType.phrase => 'ph',
      TextSearchType.websearch => 'w',
      null => '',
    };
    final configPart = config == null ? '' : '($config)';
    return ColumnFilter._(
      name,
      '${typePart}fts$configPart',
      query,
      (builder) => builder.textSearch(name, query, config: config, type: type),
    );
  }
}

/// A single filter condition on a column, created through the methods on
/// [TableColumn] such as [TableColumn.eq].
///
/// Applied to a typed query with [PostgrestTypedFilterBuilder.where].
class ColumnFilter {
  const ColumnFilter._(this.column, this.operator, this.value, this._apply);

  /// Name of the column being filtered on.
  final String column;

  /// The PostgREST operator of this filter, for example `eq` or `like(all)`.
  final String operator;

  /// The value the filter compares against.
  final Object? value;

  final PostgrestFilterBuilder<dynamic> Function(
    PostgrestFilterBuilder<dynamic> builder,
  )
  _apply;

  /// Negates this filter.
  ///
  /// ```dart
  /// client.table(Books.table).select().where(Books.id.eq(1).not());
  /// ```
  ColumnFilter not() {
    if (operator.startsWith('not.')) {
      throw StateError('The filter on "$column" is already negated.');
    }
    final positiveOperator = operator;
    return ColumnFilter._(
      column,
      'not.$operator',
      value,
      (builder) => builder.not(column, positiveOperator, value),
    );
  }
}
