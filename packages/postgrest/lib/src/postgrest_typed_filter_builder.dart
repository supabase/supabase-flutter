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
}
