import 'package:meta/meta.dart';
import 'package:supabase/supabase.dart';

/// The typed counterpart of [SupabaseQueryBuilder], returned by
/// [SupabaseClient.table].
///
/// In addition to the typed query methods inherited from
/// [PostgrestTypedQueryBuilder], this builder exposes a typed realtime
/// [stream].
@experimental
class SupabaseTypedQueryBuilder<Row, Insert, Update>
    extends PostgrestTypedQueryBuilder<Row, Insert, Update> {
  // The query builder is also kept as a field to expose [stream], so it
  // cannot become a super parameter.
  // ignore: use_super_parameters
  const SupabaseTypedQueryBuilder(
    SupabaseQueryBuilder queryBuilder,
    PostgrestTable<Row, Insert, Update> table, {
    required PostgrestTableExecutor executor,
    String? schema,
  }) : _queryBuilder = queryBuilder,
       super(table, executor: executor, schema: schema);

  final SupabaseQueryBuilder _queryBuilder;

  /// Returns real-time data from the table as a `Stream` of `List<Row>`.
  ///
  /// The typed counterpart of [SupabaseQueryBuilder.stream]; rows are
  /// converted through [PostgrestTable.rowFromJson] and [primaryKey] is
  /// expressed with [PostgrestStoredColumn]s.
  ///
  /// ```dart
  /// supabase
  ///     .table(Books.table)
  ///     .stream(primaryKey: [Books.id])
  ///     .listen((List<Book> books) {
  ///   // ...
  /// });
  /// ```
  SupabaseTypedStreamFilterBuilder<Row, Row> stream({
    required List<PostgrestStoredColumn<Row, Object>> primaryKey,
    bool private = false,
  }) {
    return SupabaseTypedStreamFilterBuilder(
      _queryBuilder.stream(
        primaryKey: [for (final column in primaryKey) column.name],
        private: private,
      ),
      table.rowFromJson,
    );
  }

  /// Returns real-time data from the table as a `Stream` of
  /// `List<PostgrestPartialRow<Row>>` holding [columns] only.
  ///
  /// The typed counterpart of [SupabaseQueryBuilder.stream] with `select`:
  /// the initial snapshot and every change payload carry [columns] and
  /// [primaryKey] instead of the full row, and the rows are read through the
  /// same column tokens, so a column left out cannot be read by mistake.
  ///
  /// ```dart
  /// supabase
  ///     .table(Books.table)
  ///     .streamOnly(primaryKey: [Books.id], columns: [Books.title])
  ///     .listen((List<PostgrestPartialRow<Book>> books) {
  ///   for (final book in books) {
  ///     print(book.read(Books.title));
  ///   }
  /// });
  /// ```
  ///
  /// [columns] needs at least one entry; use [stream] for every column.
  SupabaseTypedStreamFilterBuilder<Row, PostgrestPartialRow<Row>> streamOnly({
    required List<PostgrestStoredColumn<Row, Object>> primaryKey,
    required List<PostgrestStoredColumn<Row, Object>> columns,
    bool private = false,
  }) {
    if (columns.isEmpty) {
      throw ArgumentError.value(
        columns,
        'columns',
        'streamOnly needs at least one column',
      );
    }
    final selections = <PostgrestStoredColumn<Row, Object>>[
      ...columns,
      for (final column in primaryKey)
        if (!columns.any((selected) => selected.name == column.name)) column,
    ];
    return SupabaseTypedStreamFilterBuilder(
      _queryBuilder.stream(
        primaryKey: [for (final column in primaryKey) column.name],
        private: private,
        select: [for (final column in columns) column.name],
      ),
      // ignore: invalid_use_of_internal_member
      (json) => PostgrestPartialRow.fromSelections(json, selections),
    );
  }
}
