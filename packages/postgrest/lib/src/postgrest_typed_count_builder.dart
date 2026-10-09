part of 'postgrest_typed_builder.dart';

/// A count of the rows of a table, returned by
/// [PostgrestTypedQueryBuilder.count].
///
/// The rows to count are narrowed with [where]. A count returns no rows, so
/// there is nothing to order, limit or reshape.
///
/// ```dart
/// final int open = await client
///     .table(Books.table)
///     .count()
///     .where(Books.isDone.eq(false));
/// ```
@experimental
final class PostgrestTypedCountBuilder<Row> extends PostgrestTypedBuilder<int> {
  const PostgrestTypedCountBuilder._(
    super.request,
    super.executor,
    super.convert,
  ) : super._();

  @override
  PostgrestTypedCountBuilder<Row> _with(PostgrestTableRequest changed) =>
      PostgrestTypedCountBuilder._(changed, _executor, _convert);

  @override
  PostgrestTypedCountBuilder<Row> retry({bool enabled = true, int? count}) =>
      _with(request._retry(enabled, count));

  @override
  PostgrestTypedCountBuilder<Row> requestTimeout(Duration timeout) =>
      _with(request._requestTimeout(timeout));

  @override
  PostgrestTypedCountBuilder<Row> abortSignal(Future<void> abortSignal) =>
      _with(request._abortSignal(abortSignal));

  @override
  PostgrestTypedCountBuilder<Row> setHeader(String key, String value) =>
      _with(request._header(key, value));

  /// Only counts rows satisfying [filter].
  ///
  /// See [PostgrestTypedFilterBuilder.where] for composing filters. Repeated
  /// [where] calls combine with logical AND.
  PostgrestTypedCountBuilder<Row> where(PostgrestFilter<Row> filter) {
    final current = request.filter;
    return _with(
      request.copyWith(filter: current == null ? filter : current & filter),
    );
  }
}
