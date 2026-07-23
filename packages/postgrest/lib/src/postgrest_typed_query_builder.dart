part of 'postgrest_typed_builder.dart';

/// {@template postgrest_typed_query_builder}
/// The typed counterpart of [PostgrestQueryBuilder], returned by
/// [PostgrestClient.table].
///
/// Query results are converted into [Row] through
/// [PostgrestTable.rowFromJson], so no raw `Map<String, dynamic>` is exposed.
/// {@endtemplate}
@experimental
class PostgrestTypedQueryBuilder<Row> {
  /// {@macro postgrest_typed_query_builder}
  const PostgrestTypedQueryBuilder(
    PostgrestQueryBuilder<dynamic> queryBuilder,
    this.table,
  ) : _queryBuilder = queryBuilder;

  final PostgrestQueryBuilder<dynamic> _queryBuilder;

  /// The table this builder queries.
  final PostgrestTable<Row> table;

  /// Perform a SELECT query on the table or view.
  ///
  /// ```dart
  /// final List<Book> books = await client.table(Books.table).select();
  /// ```
  PostgrestTypedFilterBuilder<Row, List<Row>> select([String columns = '*']) =>
      PostgrestTypedFilterBuilder._(
        _queryBuilder.select(columns),
        table,
        (data) => _rowsFromJson(table, data),
      );

  /// Perform an INSERT into the table or view.
  ///
  /// By default no data is returned. Use a trailing [select] to return the
  /// inserted rows typed as [Row].
  ///
  /// See [PostgrestQueryBuilder.insert] for [values] and [defaultToNull].
  ///
  /// ```dart
  /// final Book book = await client
  ///     .table(Books.table)
  ///     .insert({'title': 'foo'})
  ///     .select()
  ///     .single();
  /// ```
  PostgrestTypedFilterBuilder<Row, void> insert(
    Object values, {
    bool defaultToNull = true,
  }) => PostgrestTypedFilterBuilder._(
    _queryBuilder.insert(values, defaultToNull: defaultToNull),
    table,
    _toVoid,
  );

  /// Perform an UPSERT on the table or view.
  ///
  /// By default no data is returned. Use a trailing [select] to return the
  /// upserted rows typed as [Row].
  ///
  /// See [PostgrestQueryBuilder.upsert] for [values], [onConflict],
  /// [ignoreDuplicates] and [defaultToNull].
  PostgrestTypedFilterBuilder<Row, void> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) => PostgrestTypedFilterBuilder._(
    _queryBuilder.upsert(
      values,
      onConflict: onConflict,
      ignoreDuplicates: ignoreDuplicates,
      defaultToNull: defaultToNull,
    ),
    table,
    _toVoid,
  );

  /// Perform an UPDATE on the table or view.
  ///
  /// By default no data is returned. Use a trailing [select] to return the
  /// updated rows typed as [Row].
  ///
  /// ```dart
  /// await client
  ///     .table(Books.table)
  ///     .update({'title': 'bar'})
  ///     .where(Books.id.eq(1));
  /// ```
  PostgrestTypedFilterBuilder<Row, void> update(Map<String, dynamic> values) =>
      PostgrestTypedFilterBuilder._(
        _queryBuilder.update(values),
        table,
        _toVoid,
      );

  /// Perform a DELETE on the table or view.
  ///
  /// By default no data is returned. Use a trailing [select] to return the
  /// deleted rows typed as [Row].
  ///
  /// ```dart
  /// await client.table(Books.table).delete().where(Books.id.eq(1));
  /// ```
  PostgrestTypedFilterBuilder<Row, void> delete() =>
      PostgrestTypedFilterBuilder._(_queryBuilder.delete(), table, _toVoid);

  /// Only performs a count query on the table or view.
  ///
  /// ```dart
  /// final int count = await client.table(Books.table).count();
  /// ```
  PostgrestTypedFilterBuilder<Row, int> count([
    CountOption option = CountOption.exact,
  ]) => PostgrestTypedFilterBuilder._(
    _queryBuilder.count(option),
    table,
    (data) => data as int,
  );
}
