part of 'postgrest_typed_builder.dart';

/// An `update` or `delete` that does not say yet which rows it acts on.
///
/// Returned by [PostgrestTypedQueryBuilder.update] and
/// [PostgrestTypedQueryBuilder.delete]. It cannot be awaited: a filter has
/// to be added with [where], or every row chosen on purpose with [all],
/// before the request can run. This keeps a forgotten filter, which would
/// write every row in the table, from compiling.
@experimental
final class PostgrestTypedUnscopedBuilder<Row> {
  const PostgrestTypedUnscopedBuilder._(
    this._request,
    this._executor,
    this._rowFromJson,
  );

  final PostgrestTableRequest _request;
  final PostgrestTableExecutor _executor;
  final RowConverter<Row> _rowFromJson;

  /// Only rows satisfying [filter].
  ///
  /// ```dart
  /// await client
  ///     .table(Books.table)
  ///     .update(BookUpdate(title: 'bar'))
  ///     .where(Books.id.eq(1));
  /// ```
  ///
  /// See [PostgrestTypedFilterBuilder.where] for composing filters. Further
  /// [where] calls on the returned builder combine with logical AND.
  PostgrestTypedFilterBuilder<Row, void> where(PostgrestFilter<Row> filter) =>
      all().where(filter);

  /// Every row in the table.
  ///
  /// ```dart
  /// await client.table(Books.table).delete().all();
  /// ```
  ///
  /// A filter can still be added afterwards, and
  /// [PostgrestTypedTransformBuilder.maxAffected] bounds how many rows the
  /// request may touch.
  PostgrestTypedFilterBuilder<Row, void> all() => PostgrestTypedFilterBuilder._(
    _request,
    _executor,
    _noResult,
    _rowFromJson,
  );
}
