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
  ComparisonFilter eq(Value value) =>
      ComparisonFilter._(name, ComparisonOperator.eq, value);

  /// Only rows where this column does not equal [value].
  ComparisonFilter neq(Value value) =>
      ComparisonFilter._(name, ComparisonOperator.neq, value);

  /// Only rows where this column is greater than [value].
  ComparisonFilter gt(Value value) =>
      ComparisonFilter._(name, ComparisonOperator.gt, value);

  /// Only rows where this column is greater than or equal to [value].
  ComparisonFilter gte(Value value) =>
      ComparisonFilter._(name, ComparisonOperator.gte, value);

  /// Only rows where this column is less than [value].
  ComparisonFilter lt(Value value) =>
      ComparisonFilter._(name, ComparisonOperator.lt, value);

  /// Only rows where this column is less than or equal to [value].
  ComparisonFilter lte(Value value) =>
      ComparisonFilter._(name, ComparisonOperator.lte, value);

  /// Only rows where this column is `null`.
  IsNullFilter isNull() => IsNullFilter._(name);

  /// Only rows where this column is not `null`.
  ColumnFilter isNotNull() => isNull().not();

  /// Only rows where this column equals one of [values].
  InListFilter inFilter(List<Value> values) => InListFilter._(name, values);

  /// Only rows where this column is not equal to [value], treating `null` as
  /// a comparable value.
  IsDistinctFilter isDistinctFrom(Value? value) =>
      IsDistinctFilter._(name, value);

  /// Only rows whose json, array, or range value contains [value].
  ///
  /// See [PostgrestFilterBuilder.contains] for the accepted value shapes.
  ContainmentFilter contains(Object value) =>
      ContainmentFilter._(name, ContainmentOperator.contains, value);

  /// Only rows whose json, array, or range value is contained by [value].
  ///
  /// See [PostgrestFilterBuilder.containedBy] for the accepted value shapes.
  ContainmentFilter containedBy(Object value) =>
      ContainmentFilter._(name, ContainmentOperator.containedBy, value);

  /// Only rows whose array or range value overlaps with [value].
  ContainmentFilter overlaps(Object value) =>
      ContainmentFilter._(name, ContainmentOperator.overlaps, value);

  /// Only rows whose range value is strictly to the left of [range].
  RangeFilter rangeLt(String range) =>
      RangeFilter._(name, RangeOperator.rangeLt, range);

  /// Only rows whose range value is strictly to the right of [range].
  RangeFilter rangeGt(String range) =>
      RangeFilter._(name, RangeOperator.rangeGt, range);

  /// Only rows whose range value does not extend to the left of [range].
  RangeFilter rangeGte(String range) =>
      RangeFilter._(name, RangeOperator.rangeGte, range);

  /// Only rows whose range value does not extend to the right of [range].
  RangeFilter rangeLte(String range) =>
      RangeFilter._(name, RangeOperator.rangeLte, range);

  /// Only rows whose range value is adjacent to [range].
  RangeFilter rangeAdjacent(String range) =>
      RangeFilter._(name, RangeOperator.rangeAdjacent, range);
}

/// Filters that only apply to text columns.
extension TextTableColumnFilters on TableColumn<String> {
  /// Only rows whose value matches [pattern] case-sensitively.
  PatternFilter like(String pattern) =>
      PatternFilter._(name, PatternOperator.like, pattern);

  /// Only rows whose value matches [pattern] case-insensitively.
  PatternFilter ilike(String pattern) =>
      PatternFilter._(name, PatternOperator.ilike, pattern);

  /// Only rows whose value matches [pattern] as a PostgreSQL regular
  /// expression, case-sensitively.
  PatternFilter matchRegex(String pattern) =>
      PatternFilter._(name, PatternOperator.matchRegex, pattern);

  /// Only rows whose value matches [pattern] as a PostgreSQL regular
  /// expression, case-insensitively.
  PatternFilter imatchRegex(String pattern) =>
      PatternFilter._(name, PatternOperator.imatchRegex, pattern);

  /// Only rows whose value matches all of [patterns] case-sensitively.
  PatternListFilter likeAllOf(List<String> patterns) =>
      PatternListFilter._(name, PatternListOperator.likeAllOf, patterns);

  /// Only rows whose value matches any of [patterns] case-sensitively.
  PatternListFilter likeAnyOf(List<String> patterns) =>
      PatternListFilter._(name, PatternListOperator.likeAnyOf, patterns);

  /// Only rows whose value matches all of [patterns] case-insensitively.
  PatternListFilter ilikeAllOf(List<String> patterns) =>
      PatternListFilter._(name, PatternListOperator.ilikeAllOf, patterns);

  /// Only rows whose value matches any of [patterns] case-insensitively.
  PatternListFilter ilikeAnyOf(List<String> patterns) =>
      PatternListFilter._(name, PatternListOperator.ilikeAnyOf, patterns);

  /// Only rows whose text or tsvector value matches the tsquery in [query].
  ///
  /// See [PostgrestFilterBuilder.textSearch] for [config] and [type].
  TextSearchFilter textSearch(
    String query, {
    String? config,
    TextSearchType? type,
  }) => TextSearchFilter._(name, query, config: config, type: type);
}

/// A single filter condition on a column, created through the methods on
/// [TableColumn] such as [TableColumn.eq].
///
/// Applied to a typed query with [PostgrestTypedFilterBuilder.where]. The
/// concrete subtypes carry the operator as structured data, so consumers can
/// exhaustively match on the filter shape instead of comparing strings;
/// realtime streams for example only accept [ComparisonFilter] and
/// [InListFilter].
sealed class ColumnFilter {
  const ColumnFilter._();

  /// Name of the column being filtered on.
  String get column;

  /// The PostgREST wire representation of the operator, for example `eq` or
  /// `like(all)`.
  String get operator;

  /// The value the filter compares against.
  Object? get value;

  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  );

  /// Negates this filter.
  ///
  /// ```dart
  /// client.table(Books.table).select().where(Books.id.eq(1).not());
  /// ```
  ColumnFilter not() => _NegatedColumnFilter(this);
}

/// The comparison applied by a [ComparisonFilter].
enum ComparisonOperator {
  eq('eq'),
  neq('neq'),
  gt('gt'),
  gte('gte'),
  lt('lt'),
  lte('lte');

  const ComparisonOperator(this.wireName);

  /// The PostgREST wire representation of the operator.
  final String wireName;
}

/// An equality or ordering comparison against a single value.
///
/// Besides regular queries, these are the filters that realtime streams
/// support, together with [InListFilter].
final class ComparisonFilter extends ColumnFilter {
  const ComparisonFilter._(this.column, this.comparison, this.value)
    : super._();

  @override
  final String column;

  /// The comparison being applied.
  final ComparisonOperator comparison;

  @override
  final Object value;

  @override
  String get operator => comparison.wireName;

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => switch (comparison) {
    ComparisonOperator.eq => builder.eq(column, value),
    ComparisonOperator.neq => builder.neq(column, value),
    ComparisonOperator.gt => builder.gt(column, value),
    ComparisonOperator.gte => builder.gte(column, value),
    ComparisonOperator.lt => builder.lt(column, value),
    ComparisonOperator.lte => builder.lte(column, value),
  };
}

/// A filter matching rows whose column value equals one of [values].
///
/// Besides regular queries, this filter is supported by realtime streams,
/// together with [ComparisonFilter].
final class InListFilter extends ColumnFilter {
  const InListFilter._(this.column, this.values) : super._();

  @override
  final String column;

  /// The values the column is compared against.
  final List<Object> values;

  @override
  String get operator => 'in';

  @override
  Object get value => values;

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.inFilter(column, values);
}

/// A filter matching rows whose column value is `null`.
final class IsNullFilter extends ColumnFilter {
  const IsNullFilter._(this.column) : super._();

  @override
  final String column;

  @override
  String get operator => 'is';

  @override
  Object? get value => null;

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.isFilter(column, null);
}

/// A filter matching rows whose column value is distinct from [value],
/// treating `null` as a comparable value.
final class IsDistinctFilter extends ColumnFilter {
  const IsDistinctFilter._(this.column, this.value) : super._();

  @override
  final String column;

  @override
  final Object? value;

  @override
  String get operator => 'isdistinct';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.isDistinct(column, value);
}

/// The operator applied by a [ContainmentFilter].
enum ContainmentOperator {
  contains('cs'),
  containedBy('cd'),
  overlaps('ov');

  const ContainmentOperator(this.wireName);

  /// The PostgREST wire representation of the operator.
  final String wireName;
}

/// A containment or overlap filter on a json, array, or range column.
final class ContainmentFilter extends ColumnFilter {
  const ContainmentFilter._(this.column, this.containment, this.value)
    : super._();

  @override
  final String column;

  /// The containment check being applied.
  final ContainmentOperator containment;

  @override
  final Object value;

  @override
  String get operator => containment.wireName;

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => switch (containment) {
    ContainmentOperator.contains => builder.contains(column, value),
    ContainmentOperator.containedBy => builder.containedBy(column, value),
    ContainmentOperator.overlaps => builder.overlaps(column, value),
  };
}

/// The operator applied by a [RangeFilter].
enum RangeOperator {
  rangeLt('sl'),
  rangeGt('sr'),
  rangeGte('nxl'),
  rangeLte('nxr'),
  rangeAdjacent('adj');

  const RangeOperator(this.wireName);

  /// The PostgREST wire representation of the operator.
  final String wireName;
}

/// A filter comparing a range column against the range literal [range].
final class RangeFilter extends ColumnFilter {
  const RangeFilter._(this.column, this.rangeComparison, this.range)
    : super._();

  @override
  final String column;

  /// The range comparison being applied.
  final RangeOperator rangeComparison;

  /// The PostgREST range literal, for example `[2,25)`.
  final String range;

  @override
  String get operator => rangeComparison.wireName;

  @override
  Object get value => range;

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => switch (rangeComparison) {
    RangeOperator.rangeLt => builder.rangeLt(column, range),
    RangeOperator.rangeGt => builder.rangeGt(column, range),
    RangeOperator.rangeGte => builder.rangeGte(column, range),
    RangeOperator.rangeLte => builder.rangeLte(column, range),
    RangeOperator.rangeAdjacent => builder.rangeAdjacent(column, range),
  };
}

/// The operator applied by a [PatternFilter].
enum PatternOperator {
  like('like'),
  ilike('ilike'),
  matchRegex('match'),
  imatchRegex('imatch');

  const PatternOperator(this.wireName);

  /// The PostgREST wire representation of the operator.
  final String wireName;
}

/// A filter matching a text column against a single [pattern].
final class PatternFilter extends ColumnFilter {
  const PatternFilter._(this.column, this.match, this.pattern) : super._();

  @override
  final String column;

  /// The kind of pattern match being applied.
  final PatternOperator match;

  /// The pattern the column is matched against.
  final String pattern;

  @override
  String get operator => match.wireName;

  @override
  Object get value => pattern;

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => switch (match) {
    PatternOperator.like => builder.like(column, pattern),
    PatternOperator.ilike => builder.ilike(column, pattern),
    PatternOperator.matchRegex => builder.matchRegex(column, pattern),
    PatternOperator.imatchRegex => builder.imatchRegex(column, pattern),
  };
}

/// The operator applied by a [PatternListFilter].
enum PatternListOperator {
  likeAllOf('like(all)'),
  likeAnyOf('like(any)'),
  ilikeAllOf('ilike(all)'),
  ilikeAnyOf('ilike(any)');

  const PatternListOperator(this.wireName);

  /// The PostgREST wire representation of the operator.
  final String wireName;
}

/// A filter matching a text column against several [patterns] at once.
final class PatternListFilter extends ColumnFilter {
  const PatternListFilter._(this.column, this.match, this.patterns) : super._();

  @override
  final String column;

  /// The kind of pattern match being applied.
  final PatternListOperator match;

  /// The patterns the column is matched against.
  final List<String> patterns;

  @override
  String get operator => match.wireName;

  @override
  Object get value => patterns;

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => switch (match) {
    PatternListOperator.likeAllOf => builder.likeAllOf(column, patterns),
    PatternListOperator.likeAnyOf => builder.likeAnyOf(column, patterns),
    PatternListOperator.ilikeAllOf => builder.ilikeAllOf(column, patterns),
    PatternListOperator.ilikeAnyOf => builder.ilikeAnyOf(column, patterns),
  };
}

/// A full text search filter on a text or tsvector column.
final class TextSearchFilter extends ColumnFilter {
  const TextSearchFilter._(
    this.column,
    this.query, {
    this.config,
    this.type,
  }) : super._();

  @override
  final String column;

  /// The tsquery the column is matched against.
  final String query;

  /// The text search configuration to use.
  final String? config;

  /// The type of tsquery conversion applied to [query].
  final TextSearchType? type;

  @override
  String get operator {
    final typePart = switch (type) {
      TextSearchType.plain => 'pl',
      TextSearchType.phrase => 'ph',
      TextSearchType.websearch => 'w',
      null => '',
    };
    final configPart = config == null ? '' : '($config)';
    return '${typePart}fts$configPart';
  }

  @override
  Object get value => query;

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.textSearch(column, query, config: config, type: type);
}

/// The negation of another [ColumnFilter], created through
/// [ColumnFilter.not].
final class _NegatedColumnFilter extends ColumnFilter {
  const _NegatedColumnFilter(this._inner) : super._();

  final ColumnFilter _inner;

  @override
  String get column => _inner.column;

  @override
  String get operator => 'not.${_inner.operator}';

  @override
  Object? get value => _inner.value;

  @override
  ColumnFilter not() =>
      throw StateError('The filter on "$column" is already negated.');

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.not(column, _inner.operator, _inner.value);
}
