part of 'postgrest_typed_builder.dart';

/// {@template postgrest_typed_query_builder}
/// The typed counterpart of [PostgrestQueryBuilder], returned by
/// [PostgrestClient.table].
///
/// Query results are converted into [Row] through
/// [PostgrestTable.rowFromJson], so no raw `Map<String, dynamic>` is exposed,
/// and writes only accept the table's [Insert] and [Update] types.
/// {@endtemplate}
@experimental
class PostgrestTypedQueryBuilder<Row, Insert, Update> {
  /// {@macro postgrest_typed_query_builder}
  const PostgrestTypedQueryBuilder(
    PostgrestQueryBuilder queryBuilder,
    this.table,
  ) : _queryBuilder = queryBuilder;

  final PostgrestQueryBuilder _queryBuilder;

  /// The table this builder queries.
  final PostgrestTable<Row, Insert, Update> table;

  /// Perform a SELECT query on the table or view.
  ///
  /// Without [columns] every column is selected:
  ///
  /// ```dart
  /// final List<Book> books = await client.table(Books.table).select();
  /// ```
  ///
  /// With [columns], only those are, and each has to belong to this table:
  ///
  /// ```dart
  /// final List<Book> books = await client
  ///     .table(Books.table)
  ///     .select([Books.id, Books.title]);
  /// ```
  ///
  /// Rows are still converted into [Row], whose getters for the columns left
  /// out have nothing to read.
  PostgrestTypedFilterBuilder<Row, List<Row>> select([
    List<PostgrestColumnExpression<Row, Object>>? columns,
  ]) => PostgrestTypedFilterBuilder._(
    PostgrestFilterBuilder(
      _queryBuilder
          .select(_selectList(columns))
          .withConverter((rows) => _rowsFromJson(table.rowFromJson, rows)),
    ),
    table.rowFromJson,
  );

  /// Perform an INSERT of a single [row] into the table or view.
  ///
  /// By default no data is returned. Use a trailing [select] to return the
  /// inserted row typed as [Row].
  ///
  /// ```dart
  /// final Book book = await client
  ///     .table(Books.table)
  ///     .insert(BookInsert(title: 'foo'))
  ///     .select()
  ///     .single();
  /// ```
  ///
  /// See [insertAll] to insert several rows in one request and
  /// [PostgrestQueryBuilder.insert] for [defaultToNull].
  PostgrestTypedTransformBuilder<Row, void> insert(
    Insert row, {
    bool defaultToNull = true,
  }) => PostgrestTypedTransformBuilder._(
    _queryBuilder.insert(row as Object, defaultToNull: defaultToNull),
    table.rowFromJson,
  );

  /// Perform an INSERT of every row in [rows] into the table or view.
  ///
  /// ```dart
  /// await client.table(Books.table).insertAll([
  ///   BookInsert(title: 'foo'),
  ///   BookInsert(title: 'bar'),
  /// ]);
  /// ```
  ///
  /// [rows] needs at least one row.
  ///
  /// See [insert] and [PostgrestQueryBuilder.insert] for [defaultToNull].
  PostgrestTypedTransformBuilder<Row, void> insertAll(
    List<Insert> rows, {
    bool defaultToNull = true,
  }) => PostgrestTypedTransformBuilder._(
    _queryBuilder.insert(_nonEmpty(rows), defaultToNull: defaultToNull),
    table.rowFromJson,
  );

  /// Perform an UPSERT of a single [row] on the table or view.
  ///
  /// By default no data is returned. Use a trailing [select] to return the
  /// upserted row typed as [Row].
  ///
  /// [onConflict] names the columns of the unique constraint to merge on;
  /// left out, the primary key is the target.
  ///
  /// ```dart
  /// await client.table(Users.table).upsert(
  ///   UserInsert(email: 'a@example.com', name: 'Ada'),
  ///   onConflict: [Users.email],
  /// );
  /// ```
  ///
  /// See [upsertAll] to upsert several rows in one request and
  /// [PostgrestQueryBuilder.upsert] for [ignoreDuplicates] and
  /// [defaultToNull].
  PostgrestTypedTransformBuilder<Row, void> upsert(
    Insert row, {
    List<PostgrestColumn<Row, Object>>? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) => _upsert(
    row as Object,
    onConflict: onConflict,
    ignoreDuplicates: ignoreDuplicates,
    defaultToNull: defaultToNull,
  );

  /// Perform an UPSERT of every row in [rows] on the table or view.
  ///
  /// ```dart
  /// await client.table(Users.table).upsertAll(
  ///   [
  ///     UserInsert(email: 'a@example.com', name: 'Ada'),
  ///     UserInsert(email: 'b@example.com', name: 'Bob'),
  ///   ],
  ///   onConflict: [Users.email],
  /// );
  /// ```
  ///
  /// [rows] needs at least one row.
  ///
  /// See [upsert] for [onConflict] and [PostgrestQueryBuilder.upsert] for
  /// [ignoreDuplicates] and [defaultToNull].
  PostgrestTypedTransformBuilder<Row, void> upsertAll(
    List<Insert> rows, {
    List<PostgrestColumn<Row, Object>>? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) => _upsert(
    _nonEmpty(rows),
    onConflict: onConflict,
    ignoreDuplicates: ignoreDuplicates,
    defaultToNull: defaultToNull,
  );

  List<Insert> _nonEmpty(List<Insert> rows) {
    if (rows.isEmpty) {
      throw ArgumentError.value(rows, 'rows', 'rows needs at least one row');
    }
    return rows;
  }

  PostgrestTypedTransformBuilder<Row, void> _upsert(
    Object values, {
    required List<PostgrestColumn<Row, Object>>? onConflict,
    required bool ignoreDuplicates,
    required bool defaultToNull,
  }) {
    if (onConflict != null && onConflict.isEmpty) {
      throw ArgumentError.value(
        onConflict,
        'onConflict',
        'onConflict needs at least one column',
      );
    }
    return PostgrestTypedTransformBuilder._(
      _queryBuilder.upsert(
        values,
        onConflict: onConflict?.map((column) => column.name).join(','),
        ignoreDuplicates: ignoreDuplicates,
        defaultToNull: defaultToNull,
      ),
      table.rowFromJson,
    );
  }

  /// Perform an UPDATE on the table or view.
  ///
  /// By default no data is returned. Use a trailing [select] to return the
  /// updated rows typed as [Row].
  ///
  /// ```dart
  /// await client
  ///     .table(Books.table)
  ///     .update(BookUpdate(title: 'bar'))
  ///     .where(Books.id.eq(1));
  /// ```
  PostgrestTypedFilterBuilder<Row, void> update(Update values) =>
      PostgrestTypedFilterBuilder._(
        _queryBuilder.update(values as Object),
        table.rowFromJson,
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
      PostgrestTypedFilterBuilder._(_queryBuilder.delete(), table.rowFromJson);

  /// Only performs a count query on the table or view.
  ///
  /// ```dart
  /// final int count = await client.table(Books.table).count();
  /// ```
  PostgrestTypedFilterBuilder<Row, int> count([
    CountOption option = CountOption.exact,
  ]) => PostgrestTypedFilterBuilder._(
    _queryBuilder.count(option),
    table.rowFromJson,
  );
}
