part of 'postgrest_typed_builder.dart';

/// The typed counterpart of [PostgrestTransformBuilder].
///
/// [Row] is the type a single row converts into and [T] is the type the
/// request resolves to when awaited.
@experimental
class PostgrestTypedTransformBuilder<Row, T> extends PostgrestTypedBuilder<T> {
  const PostgrestTypedTransformBuilder._(
    super.request,
    super.executor,
    super.convert,
    this._rowFromJson,
  ) : super._();

  final RowConverter<Row> _rowFromJson;

  PostgrestTypedTransformBuilder<Row, T> _with(PostgrestTableRequest request) =>
      PostgrestTypedTransformBuilder._(
        request,
        _executor,
        _convert,
        _rowFromJson,
      );

  PostgrestTypedTransformBuilder<Row, U> _shaped<U>(
    PostgrestResultShape shape,
    _ResultConverter<U> convert,
  ) => PostgrestTypedTransformBuilder._(
    request.copyWith(shape: shape),
    _executor,
    convert,
    _rowFromJson,
  );

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
  /// See [PostgrestTypedQueryBuilder.select] for [columns].
  PostgrestTypedTransformBuilder<Row, List<Row>> select([
    List<PostgrestColumnExpression<Row, Object>>? columns,
  ]) => PostgrestTypedTransformBuilder._(
    request.copyWith(
      columns: _checkedColumns(columns),
      shape: PostgrestResultShape.rows,
      returning: true,
    ),
    _executor,
    _rowsConverter(_rowFromJson),
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
  ) => _with(request.copyWith(orderings: [...request.orderings, ordering]));

  /// Limits the result with the specified [count].
  PostgrestTypedTransformBuilder<Row, T> limit(
    int count, {
    String? referencedTable,
  }) => _with(
    referencedTable == null
        ? request.copyWith(limit: count)
        : request.copyWith(
            embeddedPages: [
              ...request.embeddedPages,
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
        ? request.copyWith(offset: from, limit: to - from + 1)
        : request.copyWith(
            embeddedPages: [
              ...request.embeddedPages,
              PostgrestEmbeddedPage(
                referencedTable,
                limit: to - from + 1,
                offset: from,
              ),
            ],
          ),
  );

  /// Retrieves only one row from the result as [Row].
  ///
  /// The result must be exactly one row, otherwise this will result in an
  /// error.
  ///
  /// ```dart
  /// final Book book = await client
  ///     .table(Books.table)
  ///     .select()
  ///     .where(Books.id.eq(1))
  ///     .single();
  /// ```
  PostgrestTypedTransformBuilder<Row, Row> single() => _shaped(
    PostgrestResultShape.single,
    (result) => _rowFromJson(result.data! as PostgrestMap),
  );

  /// Retrieves at most one row from the result as [Row], or `null` when the
  /// result is empty.
  PostgrestTypedTransformBuilder<Row, Row?> maybeSingle() => _shaped(
    PostgrestResultShape.maybeSingle,
    (result) {
      final row = result.data;
      return row == null ? null : _rowFromJson(row as PostgrestMap);
    },
  );

  /// Omits `null`-valued properties from the response objects.
  ///
  /// This uses the `nulls=stripped` variant of the `Accept` header and
  /// requires PostgREST 11.2 or higher.
  PostgrestTypedTransformBuilder<Row, T> stripNulls() =>
      _with(request.copyWith(stripNulls: true));

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
      _with(request.copyWith(dryRun: true));

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
      _with(request.copyWith(maxAffected: value));

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
    request.copyWith(shape: PostgrestResultShape.head),
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
        request.copyWith(shape: PostgrestResultShape.geojson),
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
    request.copyWith(
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
    request.copyWith(countOption: option),
    _executor,
    (result) => PostgrestResponse(
      data: _convert(result),
      count: result.count!,
    ),
  );
}
