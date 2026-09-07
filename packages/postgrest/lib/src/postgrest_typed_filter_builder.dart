part of 'postgrest_typed_builder.dart';

/// The typed counterpart of [PostgrestFilterBuilder].
///
/// Filters are built from [PostgrestColumn]s and applied with [where]; the
/// value type and the table of each filter are checked at compile time.
@experimental
class PostgrestTypedFilterBuilder<Row, T>
    extends PostgrestTypedTransformBuilder<Row, T> {
  const PostgrestTypedFilterBuilder._(
    PostgrestFilterBuilder<dynamic> super.rawBuilder,
    super.table,
    super.convert,
  ) : super._();

  PostgrestFilterBuilder<dynamic> get _filterBuilder =>
      _rawBuilder as PostgrestFilterBuilder<dynamic>;

  /// Only rows satisfying [filter].
  ///
  /// Operators are methods on a column, composed with `&`, `|` and
  /// [PostgrestFilter.not]:
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
  /// A filter is a value, so it can be assembled conditionally:
  ///
  /// ```dart
  /// var filter = Books.isDone.eq(false);
  /// if (priority != null) filter = filter & Books.priority.gte(priority);
  /// client.table(Books.table).select().where(filter);
  /// ```
  ///
  /// Repeated [where] calls combine with logical AND.
  PostgrestTypedFilterBuilder<Row, T> where(PostgrestFilter<Row> filter) {
    var builder = _filterBuilder;
    for (final parameter in filter.queryParameters) {
      builder = builder.appendSearchParameter(parameter.key, parameter.value);
    }
    return PostgrestTypedFilterBuilder._(builder, _table, _convert);
  }

  /// Only rows satisfying at least one of the [filters].
  ///
  /// ```dart
  /// client
  ///     .table(Books.table)
  ///     .select()
  ///     .whereAny([Books.id.eq(1), Books.title.eq('foo')]);
  /// ```
  PostgrestTypedFilterBuilder<Row, T> whereAny(List<ColumnFilter> filters) {
    if (filters.isEmpty) {
      throw ArgumentError.value(
        filters,
        'filters',
        'whereAny needs at least one filter',
      );
    }
    final fragments = [for (final filter in filters) _orFragment(filter)];
    return PostgrestTypedFilterBuilder._(
      _filterBuilder.or(fragments.join(',')),
      _table,
      _convert,
    );
  }

  static String _orFragment(ColumnFilter filter) {
    final unwrapped = filter is NegatedFilter ? filter.inner : filter;
    final value = filter.value;
    final String rendered;
    if (value is List) {
      final elements = value.map(_quoteOrElement).join(',');
      rendered = unwrapped is InListFilter ? '($elements)' : '{$elements}';
    } else {
      rendered = _quoteOrElement(value);
    }
    return '${filter.column}.${filter.operator}.$rendered';
  }

  /// Quotes values inside an `or` fragment so that reserved characters like
  /// commas and parentheses cannot break the logic tree.
  static String _quoteOrElement(Object? value) {
    if (value == null || value is num || value is bool) {
      return '$value';
    }
    // Maps are encoded as json, matching the positive containment paths.
    final rendered = value is Map ? json.encode(value) : '$value';
    final escaped = rendered.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
  }
}
