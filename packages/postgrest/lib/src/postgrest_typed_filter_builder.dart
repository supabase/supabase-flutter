part of 'postgrest_typed_builder.dart';

/// The typed counterpart of [PostgrestFilterBuilder].
///
/// Filters are built from [TableColumn]s and applied with [where], which
/// checks the value type of each filter against its column at compile time.
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
  /// Chain multiple [where] calls to combine filters with logical AND.
  ///
  /// ```dart
  /// final List<Book> books = await client
  ///     .table(Books.table)
  ///     .select()
  ///     .where(Books.id.gt(10))
  ///     .where(Books.title.like('%Dart%'));
  /// ```
  PostgrestTypedFilterBuilder<Row, T> where(ColumnFilter filter) =>
      PostgrestTypedFilterBuilder._(
        filter._apply(_filterBuilder),
        _table,
        _convert,
      );

  /// Only rows satisfying at least one of the [filters].
  ///
  /// ```dart
  /// client
  ///     .table(Books.table)
  ///     .select()
  ///     .whereAny([Books.id.eq(1), Books.title.eq('foo')]);
  /// ```
  PostgrestTypedFilterBuilder<Row, T> whereAny(List<ColumnFilter> filters) {
    final fragments = [for (final filter in filters) _orFragment(filter)];
    return PostgrestTypedFilterBuilder._(
      _filterBuilder.or(fragments.join(',')),
      _table,
      _convert,
    );
  }

  static String _orFragment(ColumnFilter filter) {
    final unwrapped = filter is _NegatedColumnFilter ? filter._inner : filter;
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
    final escaped = '$value'.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
  }
}
