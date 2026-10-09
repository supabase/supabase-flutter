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
  PostgrestTypedQueryBuilder(
    this.table, {
    required PostgrestClient client,
    String? schema,
  }) : _executor = PostgrestHttpTableExecutor(client),
       _schema = schema,
       _options = null;

  const PostgrestTypedQueryBuilder._(
    this.table,
    this._executor,
    this._schema,
    this._options,
  );

  final PostgrestTableExecutor _executor;
  final String? _schema;
  final PostgrestRequestOptions? _options;

  /// The table this builder queries.
  final PostgrestTable<Row, Insert, Update> table;

  PostgrestTableRequest _request(PostgrestTableOperation operation) =>
      PostgrestTableRequest(
        table: table,
        operation: operation,
        schema: _schema,
        options: _options,
      );

  PostgrestTypedQueryBuilder<Row, Insert, Update> _with(
    PostgrestRequestOptions options,
  ) => PostgrestTypedQueryBuilder._(table, _executor, _schema, options);

  PostgrestRequestOptions get _currentOptions =>
      _options ?? PostgrestRequestOptions();

  /// Overrides the retry behavior of the requests built by this builder.
  ///
  /// See [PostgrestBuilder.retry] for [enabled] and [count].
  PostgrestTypedQueryBuilder<Row, Insert, Update> retry({
    bool enabled = true,
    int? count,
  }) => _with(_currentOptions._retry(enabled, count));

  /// Bounds how long a single attempt of the requests built by this builder
  /// may take.
  ///
  /// See [PostgrestBuilder.requestTimeout].
  PostgrestTypedQueryBuilder<Row, Insert, Update> requestTimeout(
    Duration timeout,
  ) => _with(_currentOptions._requestTimeout(timeout));

  /// Cancels the requests built by this builder when [abortSignal]
  /// completes.
  ///
  /// See [PostgrestTypedBuilder.abortSignal].
  PostgrestTypedQueryBuilder<Row, Insert, Update> abortSignal(
    Future<void> abortSignal,
  ) => _with(_currentOptions._abortSignal(abortSignal));

  /// Sets a header on the requests built by this builder.
  PostgrestTypedQueryBuilder<Row, Insert, Update> setHeader(
    String key,
    String value,
  ) => _with(_currentOptions._header(key, value));

  PostgrestTypedUnscopedBuilder<Row> _mutation(
    PostgrestTableRequest request,
  ) => PostgrestTypedUnscopedBuilder._(
    request.copyWith(shape: PostgrestResultShape.none),
    _executor,
    table.rowFromJson,
  );

  PostgrestTypedTransformBuilder<Row, void> _insertion(
    PostgrestTableRequest request,
  ) => PostgrestTypedTransformBuilder._(
    request.copyWith(shape: PostgrestResultShape.none),
    _executor,
    _noResult,
    table.rowFromJson,
  );

  /// Perform a SELECT query on the table or view, reading every column.
  ///
  /// ```dart
  /// final List<Book> books = await client.table(Books.table).select();
  /// ```
  ///
  /// Rows are converted into [Row] through [PostgrestTable.rowFromJson].
  /// See [selectOnly] to read some columns, an embedded relation or an
  /// aggregate instead.
  PostgrestTypedFilterBuilder<Row, List<Row>> select() =>
      PostgrestTypedFilterBuilder._(
        _request(PostgrestTableOperation.select),
        _executor,
        _rowsConverter(table.rowFromJson),
        table.rowFromJson,
      );

  /// Perform a SELECT query on the table or view, reading [columns] only.
  ///
  /// Each entry has to belong to this table, and the rows come back as
  /// [PostgrestPartialRow]s that are read through the same entries, so a
  /// column left out cannot be read by mistake:
  ///
  /// ```dart
  /// final books = await client
  ///     .table(Books.table)
  ///     .selectOnly([Books.id, Books.title]);
  /// final String title = books.first.read(Books.title);
  /// ```
  ///
  /// An embedded relation is selected column by column,
  /// `Books.author(Authors.name)`, or as a whole, `Books.author.select()`.
  /// Entries of one relation are sent as a single embed whatever their
  /// order in [columns], so `author(id)` and `author(name)` become
  /// `author(id,name)`, and the embedded rows are read through the relation:
  ///
  /// ```dart
  /// final books = await client
  ///     .table(Books.table)
  ///     .selectOnly([
  ///       Books.id,
  ///       Books.author.select([Authors.id, Authors.name]),
  ///     ]);
  /// final String? author = books.first.read(Books.author)?.read(Authors.name);
  /// ```
  ///
  /// [columns] needs at least one entry; use [select] for every column.
  PostgrestTypedFilterBuilder<Row, List<PostgrestPartialRow<Row>>> selectOnly(
    List<PostgrestSelectable<Row>> columns,
  ) => PostgrestTypedFilterBuilder._(
    _request(
      PostgrestTableOperation.select,
    ).copyWith(columns: _checkedSelections(columns, 'columns')),
    _executor,
    _partialRowsConverter(columns),
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
  }) => _insertion(
    _request(PostgrestTableOperation.insert).copyWith(
      payload: row as Object,
      defaultToNull: defaultToNull,
    ),
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
  }) => _insertion(
    _request(PostgrestTableOperation.insert).copyWith(
      payload: _nonEmpty(rows),
      defaultToNull: defaultToNull,
    ),
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
    List<PostgrestStoredColumn<Row, Object>>? onConflict,
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
    List<PostgrestStoredColumn<Row, Object>>? onConflict,
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
    required List<PostgrestStoredColumn<Row, Object>>? onConflict,
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
    return _insertion(
      _request(PostgrestTableOperation.upsert).copyWith(
        payload: values,
        onConflict: onConflict,
        ignoreDuplicates: ignoreDuplicates,
        defaultToNull: defaultToNull,
      ),
    );
  }

  /// Perform an UPDATE on the table or view.
  ///
  /// The rows to update are chosen with [PostgrestTypedUnscopedBuilder.where],
  /// or every row with [PostgrestTypedUnscopedBuilder.all]; nothing is sent
  /// before one of them is called.
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
  PostgrestTypedUnscopedBuilder<Row> update(Update values) => _mutation(
    _request(
      PostgrestTableOperation.update,
    ).copyWith(payload: values as Object),
  );

  /// Perform a DELETE on the table or view.
  ///
  /// The rows to delete are chosen with [PostgrestTypedUnscopedBuilder.where],
  /// or every row with [PostgrestTypedUnscopedBuilder.all]; nothing is sent
  /// before one of them is called.
  ///
  /// By default no data is returned. Use a trailing [select] to return the
  /// deleted rows typed as [Row].
  ///
  /// ```dart
  /// await client.table(Books.table).delete().where(Books.id.eq(1));
  /// ```
  PostgrestTypedUnscopedBuilder<Row> delete() =>
      _mutation(_request(PostgrestTableOperation.delete));

  /// Only performs a count query on the table or view.
  ///
  /// ```dart
  /// final int count = await client.table(Books.table).count();
  /// ```
  PostgrestTypedFilterBuilder<Row, int> count([
    CountOption option = CountOption.exact,
  ]) => PostgrestTypedFilterBuilder._(
    _request(PostgrestTableOperation.count).copyWith(
      countOption: option,
      shape: PostgrestResultShape.none,
    ),
    _executor,
    (result) => result.count!,
    table.rowFromJson,
  );
}
