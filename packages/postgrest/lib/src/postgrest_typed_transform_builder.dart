part of 'postgrest_typed_builder.dart';

/// The typed counterpart of [PostgrestTransformBuilder].
///
/// [Row] is the type a single row converts into and [T] is the type the
/// request resolves to when awaited.
@experimental
class PostgrestTypedTransformBuilder<Row, T> extends PostgrestTypedBuilder<T> {
  const PostgrestTypedTransformBuilder._(
    super._request,
    super.executor,
    super.convert,
    this._rowFromJson,
  ) : super._();

  final RowConverter<Row> _rowFromJson;

  @override
  PostgrestTypedTransformBuilder<Row, T> _with(PostgrestTableRequest changed) =>
      PostgrestTypedTransformBuilder._(
        changed,
        _executor,
        _convert,
        _rowFromJson,
      );

  PostgrestTypedTransformBuilder<Row, U> _shaped<U>(
    PostgrestResultShape shape,
    _ResultConverter<U> convert,
  ) => PostgrestTypedTransformBuilder._(
    _request.copyWith(shape: shape),
    _executor,
    convert,
    _rowFromJson,
  );

  @override
  PostgrestTypedTransformBuilder<Row, T> retry({
    bool enabled = true,
    int? count,
  }) => _with(_request._retry(enabled, count));

  @override
  PostgrestTypedTransformBuilder<Row, T> requestTimeout(Duration timeout) =>
      _with(_request._requestTimeout(timeout));

  @override
  PostgrestTypedTransformBuilder<Row, T> abortSignal(
    Future<void> abortSignal,
  ) => _with(_request._abortSignal(abortSignal));

  @override
  PostgrestTypedTransformBuilder<Row, T> setHeader(String key, String value) =>
      _with(_request._header(key, value));

  /// Performs horizontal filtering with SELECT, returning the affected rows
  /// typed as [Row].
  ///
  /// Used after a mutation:
  /// ```dart
  /// final List<Book> books = await client
  ///     .table(Books.table)
  ///     .insert(BookInsert(title: 'foo'))
  ///     .select();
  /// ```
  ///
  /// See [selectOnly] to return some columns only.
  PostgrestTypedTransformBuilder<Row, List<Row>> select() =>
      PostgrestTypedTransformBuilder._(
        _request.copyWith(
          columns: const [],
          shape: PostgrestResultShape.rows,
          returning: true,
        ),
        _executor,
        _rowsConverter(_rowFromJson),
        _rowFromJson,
      );

  /// Performs horizontal filtering with SELECT, returning [columns] of the
  /// affected rows as [PostgrestPartialRow]s.
  ///
  /// ```dart
  /// final rows = await client
  ///     .table(Books.table)
  ///     .insert(BookInsert(title: 'foo'))
  ///     .selectOnly([Books.id]);
  /// final int id = rows.single.read(Books.id);
  /// ```
  ///
  /// See [PostgrestTypedQueryBuilder.selectOnly] for [columns].
  PostgrestTypedTransformBuilder<Row, List<PostgrestPartialRow<Row>>>
  selectOnly(List<PostgrestSelectable<Row>> columns) =>
      PostgrestTypedTransformBuilder._(
        _request.copyWith(
          columns: _checkedSelections(columns, 'columns'),
          shape: PostgrestResultShape.rows,
          returning: true,
        ),
        _executor,
        _partialRowsConverter(columns),
        _rowFromJson,
      );

  /// Sorts the result by [ordering].
  ///
  /// The direction is spelled on the column, the same way an operator is, and
  /// only what was asked for is sent:
  ///
  /// ```dart
  /// .order(Books.title)                       // order=title
  /// .order(Books.priority.desc())             // order=priority.desc
  /// .order(Books.dueDate.asc().nullsFirst())  // order=due_date.asc.nullsfirst
  /// ```
  ///
  /// Repeated calls append, so the second key breaks ties in the first.
  PostgrestTypedTransformBuilder<Row, T> order(
    PostgrestOrdering<Row> ordering,
  ) => _with(_request.copyWith(orderings: [..._request.orderings, ordering]));

  /// Limits the result with the specified [count].
  PostgrestTypedTransformBuilder<Row, T> limit(
    int count, {
    String? referencedTable,
  }) => _with(
    referencedTable == null
        ? _request.copyWith(limit: count)
        : _request.copyWith(
            embeddedPages: [
              ..._request.embeddedPages,
              PostgrestEmbeddedPage(referencedTable, limit: count),
            ],
          ),
  );

  /// Limits the result to rows within the specified range, inclusive.
  PostgrestTypedTransformBuilder<Row, T> range(
    int from,
    int to, {
    String? referencedTable,
  }) => _with(
    referencedTable == null
        ? _request.copyWith(offset: from, limit: to - from + 1)
        : _request.copyWith(
            embeddedPages: [
              ..._request.embeddedPages,
              PostgrestEmbeddedPage(
                referencedTable,
                limit: to - from + 1,
                offset: from,
              ),
            ],
          ),
  );

  /// Omits `null`-valued properties from the response objects.
  ///
  /// This uses the `nulls=stripped` variant of the `Accept` header and
  /// requires PostgREST 11.2 or higher. It applies to row and [single]
  /// responses, in either call order.
  PostgrestTypedTransformBuilder<Row, T> stripNulls() =>
      _with(_request.copyWith(stripNulls: true));

  /// Runs the query but rolls back the transaction, so no changes are
  /// persisted.
  ///
  /// The data that would have resulted from the query is still returned,
  /// which is useful for previewing the effect of a mutation.
  ///
  /// ```dart
  /// await client.table(Books.table).insert(BookInsert(title: 'foo')).dryRun();
  /// ```
  PostgrestTypedTransformBuilder<Row, T> dryRun() =>
      _with(_request.copyWith(dryRun: true));

  /// Sets the maximum number of rows that can be affected by the query.
  ///
  /// Only available with PATCH and DELETE operations. Requires PostgREST v13 or
  /// higher. When the limit is exceeded, the query will fail with an error.
  ///
  /// ```dart
  /// await client
  ///     .table(Books.table)
  ///     .delete()
  ///     .where(Books.isDone.eq(true))
  ///     .maxAffected(10);
  /// ```
  PostgrestTypedTransformBuilder<Row, T> maxAffected(int value) =>
      _with(_request.copyWith(maxAffected: value));

  /// Retrieves the response as CSV.
  ///
  /// This will skip object parsing.
  ///
  /// ```dart
  /// final String csv = await client.table(Books.table).select().csv();
  /// ```
  PostgrestTypedTransformBuilder<Row, String> csv() =>
      _shaped(PostgrestResultShape.csv, (result) => result.data! as String);

  /// Performs a head request.
  ///
  /// This will not return any data.
  ///
  /// ```dart
  /// await client.table(Books.table).select().head();
  /// ```
  PostgrestTypedBuilder<void> head() => PostgrestTypedBuilder._(
    _request.copyWith(shape: PostgrestResultShape.head),
    _executor,
    _noResult,
  );

  /// Enables support for GeoJSON for use with PostGIS data types.
  ///
  /// Used when you need the complete response to be in GeoJSON format. You
  /// will need to enable the PostGIS extension for this to work.
  ///
  /// https://supabase.com/docs/guides/database/extensions/postgis
  PostgrestTypedBuilder<Map<String, dynamic>> geojson() =>
      PostgrestTypedBuilder._(
        _request.copyWith(shape: PostgrestResultShape.geojson),
        _executor,
        (result) => result.data! as Map<String, dynamic>,
      );

  /// Obtains the EXPLAIN plan for this request.
  ///
  /// Before using this method, you need to enable `explain()` on your
  /// Supabase instance by following the guide below. Note that `explain()`
  /// should only be enabled on a development environment.
  ///
  /// https://supabase.com/docs/guides/api/rest/debugging-performance#enabling-explain
  ///
  /// See [PostgrestTransformBuilder.explain] for the options.
  PostgrestTypedBuilder<String> explain({
    bool analyze = false,
    bool verbose = false,
    bool settings = false,
    bool buffers = false,
    bool wal = false,
    ExplainFormat format = ExplainFormat.text,
  }) => PostgrestTypedBuilder._(
    _request.copyWith(
      shape: PostgrestResultShape.explain,
      explainOptions: PostgrestExplainOptions(
        analyze: analyze,
        verbose: verbose,
        settings: settings,
        buffers: buffers,
        wal: wal,
        format: format,
      ),
    ),
    _executor,
    (result) => result.data! as String,
  );

  /// Performs additionally to the query a count query.
  ///
  /// This changes the awaited type to a [PostgrestResponse] carrying both the
  /// typed data and the count.
  ///
  /// ```dart
  /// final response =
  ///     await client.table(Books.table).select().count(CountOption.exact);
  /// final List<Book> books = response.data;
  /// final int count = response.count;
  /// ```
  PostgrestTypedBuilder<PostgrestResponse<T>> count([
    CountOption option = CountOption.exact,
  ]) => PostgrestTypedBuilder._(
    _request.copyWith(countOption: option),
    _executor,
    (result) => PostgrestResponse(
      data: _convert(result),
      count: result.count!,
    ),
  );
}
