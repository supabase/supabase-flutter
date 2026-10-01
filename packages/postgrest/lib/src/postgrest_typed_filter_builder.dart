part of 'postgrest_typed_builder.dart';

/// The typed counterpart of [PostgrestFilterBuilder].
///
/// Filters are built from [PostgrestColumn]s and applied with [where]; the
/// value type and the table of each filter are checked at compile time.
@experimental
class PostgrestTypedFilterBuilder<Row, T>
    extends PostgrestTypedTransformBuilder<Row, T> {
  const PostgrestTypedFilterBuilder._(
    super.request,
    super.executor,
    super.convert,
    super.rowFromJson,
  ) : super._();

  PostgrestTypedFilterBuilder<Row, T> _filtered(
    PostgrestTableRequest request,
  ) => PostgrestTypedFilterBuilder._(
    request,
    _executor,
    _convert,
    _rowFromJson,
  );

  @override
  PostgrestTypedFilterBuilder<Row, T> retry({
    bool enabled = true,
    int? count,
  }) => _filtered(request._retry(enabled, count));

  @override
  PostgrestTypedFilterBuilder<Row, T> requestTimeout(Duration timeout) =>
      _filtered(request._requestTimeout(timeout));

  @override
  PostgrestTypedFilterBuilder<Row, T> abortSignal(Future<void> abortSignal) =>
      _filtered(request._abortSignal(abortSignal));

  @override
  PostgrestTypedFilterBuilder<Row, T> setHeader(String key, String value) =>
      _filtered(request._header(key, value));

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
    final current = request.filter;
    return _filtered(
      request.copyWith(filter: current == null ? filter : current & filter),
    );
  }
}
