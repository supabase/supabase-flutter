part of 'postgrest_typed_builder.dart';

/// The typed counterpart of [PostgrestTransformBuilder].
///
/// [Row] is the type a single row converts into and [T] is the type the
/// request resolves to when awaited.
@experimental
class PostgrestTypedTransformBuilder<Row, T> extends PostgrestTypedBuilder<T> {
  const PostgrestTypedTransformBuilder._(this._transformBuilder, this._table)
    : super._(_transformBuilder);

  final PostgrestTransformBuilder<T> _transformBuilder;
  final PostgrestTable<Row> _table;

  /// Performs horizontal filtering with SELECT, returning the affected rows
  /// typed as [Row].
  ///
  /// Used after a mutation:
  /// ```dart
  /// final List<Book> books =
  ///     await client.table(Books.table).insert({'title': 'foo'}).select();
  /// ```
  ///
  /// See [PostgrestTypedQueryBuilder.select] for [columns].
  PostgrestTypedTransformBuilder<Row, List<Row>> select([
    List<PostgrestColumnExpression<Row, Object>>? columns,
  ]) => PostgrestTypedTransformBuilder._(
    PostgrestTransformBuilder(
      _transformBuilder
          .select(_selectList(columns))
          .withConverter((rows) => _rowsFromJson(_table, rows)),
    ),
    _table,
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
  ) => PostgrestTypedTransformBuilder._(
    _transformBuilder.appendOrderKey(ordering.orderKey),
    _table,
  );

  /// Limits the result with the specified [count].
  PostgrestTypedTransformBuilder<Row, T> limit(
    int count, {
    String? referencedTable,
  }) => PostgrestTypedTransformBuilder._(
    _transformBuilder.limit(count, referencedTable: referencedTable),
    _table,
  );

  /// Limits the result to rows within the specified range, inclusive.
  PostgrestTypedTransformBuilder<Row, T> range(
    int from,
    int to, {
    String? referencedTable,
  }) => PostgrestTypedTransformBuilder._(
    _transformBuilder.range(from, to, referencedTable: referencedTable),
    _table,
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
  PostgrestTypedTransformBuilder<Row, Row> single() =>
      PostgrestTypedTransformBuilder._(
        PostgrestTransformBuilder(
          _transformBuilder.single().withConverter(_table.rowFromJson),
        ),
        _table,
      );

  /// Retrieves at most one row from the result as [Row], or `null` when the
  /// result is empty.
  PostgrestTypedTransformBuilder<Row, Row?> maybeSingle() =>
      PostgrestTypedTransformBuilder._(
        PostgrestTransformBuilder(
          _transformBuilder.maybeSingle().withConverter(
            (row) => row == null ? null : _table.rowFromJson(row),
          ),
        ),
        _table,
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
  ]) => PostgrestTypedBuilder._(_transformBuilder.count(option));
}
