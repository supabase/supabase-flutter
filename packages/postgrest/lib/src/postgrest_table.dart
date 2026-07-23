part of 'postgrest_typed_builder.dart';

/// Converts a single decoded PostgREST row into [Row].
@experimental
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
@experimental
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
@experimental
class TableColumn<Value extends Object> {
  const TableColumn(this.name);

  /// Name of the column in the database.
  final String name;

  @override
  String toString() => name;

  /// Only rows where this column equals [value].
  ///
  /// For `null` equality, use [isNull] instead.
  EqFilter eq(Value value) => EqFilter._(name, value);

  /// Only rows where this column does not equal [value].
  NeqFilter neq(Value value) => NeqFilter._(name, value);

  /// Only rows where this column is greater than [value].
  GtFilter gt(Value value) => GtFilter._(name, value);

  /// Only rows where this column is greater than or equal to [value].
  GteFilter gte(Value value) => GteFilter._(name, value);

  /// Only rows where this column is less than [value].
  LtFilter lt(Value value) => LtFilter._(name, value);

  /// Only rows where this column is less than or equal to [value].
  LteFilter lte(Value value) => LteFilter._(name, value);

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
  ContainsFilter contains(Object value) => ContainsFilter._(name, value);

  /// Only rows whose json, array, or range value is contained by [value].
  ///
  /// See [PostgrestFilterBuilder.containedBy] for the accepted value shapes.
  ContainedByFilter containedBy(Object value) =>
      ContainedByFilter._(name, value);

  /// Only rows whose array or range value overlaps with [value].
  OverlapsFilter overlaps(Object value) => OverlapsFilter._(name, value);

  /// Only rows whose range value is strictly to the left of [range].
  RangeLtFilter rangeLt(String range) => RangeLtFilter._(name, range);

  /// Only rows whose range value is strictly to the right of [range].
  RangeGtFilter rangeGt(String range) => RangeGtFilter._(name, range);

  /// Only rows whose range value does not extend to the left of [range].
  RangeGteFilter rangeGte(String range) => RangeGteFilter._(name, range);

  /// Only rows whose range value does not extend to the right of [range].
  RangeLteFilter rangeLte(String range) => RangeLteFilter._(name, range);

  /// Only rows whose range value is adjacent to [range].
  RangeAdjacentFilter rangeAdjacent(String range) =>
      RangeAdjacentFilter._(name, range);
}

/// Filters that only apply to text columns.
@experimental
extension TextTableColumnFilters on TableColumn<String> {
  /// Only rows whose value matches [pattern] case-sensitively.
  LikeFilter like(String pattern) => LikeFilter._(name, pattern);

  /// Only rows whose value matches [pattern] case-insensitively.
  IlikeFilter ilike(String pattern) => IlikeFilter._(name, pattern);

  /// Only rows whose value matches [pattern] as a PostgreSQL regular
  /// expression, case-sensitively.
  MatchRegexFilter matchRegex(String pattern) =>
      MatchRegexFilter._(name, pattern);

  /// Only rows whose value matches [pattern] as a PostgreSQL regular
  /// expression, case-insensitively.
  ImatchRegexFilter imatchRegex(String pattern) =>
      ImatchRegexFilter._(name, pattern);

  /// Only rows whose value matches all of [patterns] case-sensitively.
  LikeAllOfFilter likeAllOf(List<String> patterns) =>
      LikeAllOfFilter._(name, patterns);

  /// Only rows whose value matches any of [patterns] case-sensitively.
  LikeAnyOfFilter likeAnyOf(List<String> patterns) =>
      LikeAnyOfFilter._(name, patterns);

  /// Only rows whose value matches all of [patterns] case-insensitively.
  IlikeAllOfFilter ilikeAllOf(List<String> patterns) =>
      IlikeAllOfFilter._(name, patterns);

  /// Only rows whose value matches any of [patterns] case-insensitively.
  IlikeAnyOfFilter ilikeAnyOf(List<String> patterns) =>
      IlikeAnyOfFilter._(name, patterns);

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
/// hierarchy is sealed with one class per operator, so consumers can switch
/// on the filter itself instead of comparing operator values; realtime
/// streams for example only accept [ComparisonFilter]s and [InListFilter].
@experimental
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
  NegatedFilter not() => NegatedFilter._(this);
}

/// An equality or ordering comparison against a single value.
///
/// Besides regular queries, these are the filters that realtime streams
/// support, together with [InListFilter].
@experimental
sealed class ComparisonFilter extends ColumnFilter {
  const ComparisonFilter._(this.column, this.value) : super._();

  @override
  final String column;

  @override
  final Object value;
}

/// Only rows where the column equals [value]; created by [TableColumn.eq].
@experimental
final class EqFilter extends ComparisonFilter {
  const EqFilter._(super.column, super.value) : super._();

  @override
  String get operator => 'eq';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.eq(column, value);
}

/// Only rows where the column does not equal [value]; created by
/// [TableColumn.neq].
@experimental
final class NeqFilter extends ComparisonFilter {
  const NeqFilter._(super.column, super.value) : super._();

  @override
  String get operator => 'neq';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.neq(column, value);
}

/// Only rows where the column is greater than [value]; created by
/// [TableColumn.gt].
@experimental
final class GtFilter extends ComparisonFilter {
  const GtFilter._(super.column, super.value) : super._();

  @override
  String get operator => 'gt';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.gt(column, value);
}

/// Only rows where the column is greater than or equal to [value]; created
/// by [TableColumn.gte].
@experimental
final class GteFilter extends ComparisonFilter {
  const GteFilter._(super.column, super.value) : super._();

  @override
  String get operator => 'gte';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.gte(column, value);
}

/// Only rows where the column is less than [value]; created by
/// [TableColumn.lt].
@experimental
final class LtFilter extends ComparisonFilter {
  const LtFilter._(super.column, super.value) : super._();

  @override
  String get operator => 'lt';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.lt(column, value);
}

/// Only rows where the column is less than or equal to [value]; created by
/// [TableColumn.lte].
@experimental
final class LteFilter extends ComparisonFilter {
  const LteFilter._(super.column, super.value) : super._();

  @override
  String get operator => 'lte';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.lte(column, value);
}

/// A filter matching rows whose column value equals one of [values]; created
/// by [TableColumn.inFilter].
///
/// Besides regular queries, this filter is supported by realtime streams,
/// together with [ComparisonFilter]s.
@experimental
final class InListFilter extends ColumnFilter {
  const InListFilter._(this.column, this.values) : super._();

  @override
  final String column;

  /// The values the column is compared against.
  final List<Object> values;

  @override
  String get operator => 'in';

  @override
  // The generic accessor intentionally aliases the semantic field.
  // ignore: match-getter-setter-field-names
  Object get value => values;

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.inFilter(column, values);
}

/// A filter matching rows whose column value is `null`; created by
/// [TableColumn.isNull].
@experimental
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
/// treating `null` as a comparable value; created by
/// [TableColumn.isDistinctFrom].
@experimental
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

/// A containment or overlap filter on a json, array, or range column.
@experimental
sealed class ContainmentFilter extends ColumnFilter {
  const ContainmentFilter._(this.column, this.value) : super._();

  @override
  final String column;

  @override
  final Object value;
}

/// Only rows whose value contains [value]; created by [TableColumn.contains].
@experimental
final class ContainsFilter extends ContainmentFilter {
  const ContainsFilter._(super.column, super.value) : super._();

  @override
  String get operator => 'cs';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.contains(column, value);
}

/// Only rows whose value is contained by [value]; created by
/// [TableColumn.containedBy].
@experimental
final class ContainedByFilter extends ContainmentFilter {
  const ContainedByFilter._(super.column, super.value) : super._();

  @override
  String get operator => 'cd';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.containedBy(column, value);
}

/// Only rows whose value overlaps with [value]; created by
/// [TableColumn.overlaps].
@experimental
final class OverlapsFilter extends ContainmentFilter {
  const OverlapsFilter._(super.column, super.value) : super._();

  @override
  String get operator => 'ov';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.overlaps(column, value);
}

/// A filter comparing a range column against the range literal [range].
@experimental
sealed class RangeFilter extends ColumnFilter {
  const RangeFilter._(this.column, this.range) : super._();

  @override
  final String column;

  /// The PostgREST range literal, for example `[2,25)`.
  final String range;

  @override
  // The generic accessor intentionally aliases the semantic field.
  // ignore: match-getter-setter-field-names
  Object get value => range;
}

/// Only rows whose range is strictly to the left of [range]; created by
/// [TableColumn.rangeLt].
@experimental
final class RangeLtFilter extends RangeFilter {
  const RangeLtFilter._(super.column, super.range) : super._();

  @override
  String get operator => 'sl';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.rangeLt(column, range);
}

/// Only rows whose range is strictly to the right of [range]; created by
/// [TableColumn.rangeGt].
@experimental
final class RangeGtFilter extends RangeFilter {
  const RangeGtFilter._(super.column, super.range) : super._();

  @override
  String get operator => 'sr';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.rangeGt(column, range);
}

/// Only rows whose range does not extend to the left of [range]; created by
/// [TableColumn.rangeGte].
@experimental
final class RangeGteFilter extends RangeFilter {
  const RangeGteFilter._(super.column, super.range) : super._();

  @override
  String get operator => 'nxl';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.rangeGte(column, range);
}

/// Only rows whose range does not extend to the right of [range]; created by
/// [TableColumn.rangeLte].
@experimental
final class RangeLteFilter extends RangeFilter {
  const RangeLteFilter._(super.column, super.range) : super._();

  @override
  String get operator => 'nxr';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.rangeLte(column, range);
}

/// Only rows whose range is adjacent to [range]; created by
/// [TableColumn.rangeAdjacent].
@experimental
final class RangeAdjacentFilter extends RangeFilter {
  const RangeAdjacentFilter._(super.column, super.range) : super._();

  @override
  String get operator => 'adj';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.rangeAdjacent(column, range);
}

/// A filter matching a text column against a single [pattern].
@experimental
sealed class PatternFilter extends ColumnFilter {
  const PatternFilter._(this.column, this.pattern) : super._();

  @override
  final String column;

  /// The pattern the column is matched against.
  final String pattern;

  @override
  // The generic accessor intentionally aliases the semantic field.
  // ignore: match-getter-setter-field-names
  Object get value => pattern;
}

/// Only rows matching [pattern] case-sensitively; created by
/// [TextTableColumnFilters.like].
@experimental
final class LikeFilter extends PatternFilter {
  const LikeFilter._(super.column, super.pattern) : super._();

  @override
  String get operator => 'like';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.like(column, pattern);
}

/// Only rows matching [pattern] case-insensitively; created by
/// [TextTableColumnFilters.ilike].
@experimental
final class IlikeFilter extends PatternFilter {
  const IlikeFilter._(super.column, super.pattern) : super._();

  @override
  String get operator => 'ilike';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.ilike(column, pattern);
}

/// Only rows matching the regular expression [pattern] case-sensitively;
/// created by [TextTableColumnFilters.matchRegex].
@experimental
final class MatchRegexFilter extends PatternFilter {
  const MatchRegexFilter._(super.column, super.pattern) : super._();

  @override
  String get operator => 'match';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.matchRegex(column, pattern);
}

/// Only rows matching the regular expression [pattern] case-insensitively;
/// created by [TextTableColumnFilters.imatchRegex].
@experimental
final class ImatchRegexFilter extends PatternFilter {
  const ImatchRegexFilter._(super.column, super.pattern) : super._();

  @override
  String get operator => 'imatch';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.imatchRegex(column, pattern);
}

/// A filter matching a text column against several [patterns] at once.
@experimental
sealed class PatternListFilter extends ColumnFilter {
  const PatternListFilter._(this.column, this.patterns) : super._();

  @override
  final String column;

  /// The patterns the column is matched against.
  final List<String> patterns;

  @override
  // The generic accessor intentionally aliases the semantic field.
  // ignore: match-getter-setter-field-names
  Object get value => patterns;
}

/// Only rows matching all of [patterns] case-sensitively; created by
/// [TextTableColumnFilters.likeAllOf].
@experimental
final class LikeAllOfFilter extends PatternListFilter {
  const LikeAllOfFilter._(super.column, super.patterns) : super._();

  @override
  String get operator => 'like(all)';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.likeAllOf(column, patterns);
}

/// Only rows matching any of [patterns] case-sensitively; created by
/// [TextTableColumnFilters.likeAnyOf].
@experimental
final class LikeAnyOfFilter extends PatternListFilter {
  const LikeAnyOfFilter._(super.column, super.patterns) : super._();

  @override
  String get operator => 'like(any)';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.likeAnyOf(column, patterns);
}

/// Only rows matching all of [patterns] case-insensitively; created by
/// [TextTableColumnFilters.ilikeAllOf].
@experimental
final class IlikeAllOfFilter extends PatternListFilter {
  const IlikeAllOfFilter._(super.column, super.patterns) : super._();

  @override
  String get operator => 'ilike(all)';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.ilikeAllOf(column, patterns);
}

/// Only rows matching any of [patterns] case-insensitively; created by
/// [TextTableColumnFilters.ilikeAnyOf].
@experimental
final class IlikeAnyOfFilter extends PatternListFilter {
  const IlikeAnyOfFilter._(super.column, super.patterns) : super._();

  @override
  String get operator => 'ilike(any)';

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.ilikeAnyOf(column, patterns);
}

/// A full text search filter on a text or tsvector column; created by
/// [TextTableColumnFilters.textSearch].
@experimental
final class TextSearchFilter extends ColumnFilter {
  const TextSearchFilter._(this.column, this.query, {this.config, this.type})
    : super._();

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
  // The generic accessor intentionally aliases the semantic field.
  // ignore: match-getter-setter-field-names
  Object get value => query;

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) => builder.textSearch(column, query, config: config, type: type);
}

/// The negation of another [ColumnFilter], created through
/// [ColumnFilter.not].
@experimental
final class NegatedFilter extends ColumnFilter {
  const NegatedFilter._(this.inner) : super._();

  /// The filter being negated.
  final ColumnFilter inner;

  @override
  String get column => inner.column;

  @override
  String get operator => 'not.${inner.operator}';

  @override
  Object? get value => inner.value;

  @override
  NegatedFilter not() =>
      throw StateError('The filter on "$column" is already negated.');

  @override
  PostgrestFilterBuilder<dynamic> _apply(
    PostgrestFilterBuilder<dynamic> builder,
  ) {
    // The untyped `not` stringifies map values with `Map.toString`, unlike
    // the json-encoding positive paths such as `contains`, so encode here.
    final innerValue = inner.value;
    return builder.not(
      column,
      inner.operator,
      innerValue is Map ? json.encode(innerValue) : innerValue,
    );
  }
}
