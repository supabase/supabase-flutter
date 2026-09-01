import 'package:meta/meta.dart';
import 'package:supabase/supabase.dart';

/// The typed counterpart of [SupabaseQueryBuilder], returned by
/// [SupabaseClient.table].
///
/// In addition to the typed query methods inherited from
/// [PostgrestTypedQueryBuilder], this builder exposes a typed realtime
/// [stream].
@experimental
class SupabaseTypedQueryBuilder<Row> extends PostgrestTypedQueryBuilder<Row> {
  // The query builder is also kept as a field to expose [stream], so it
  // cannot become a super parameter.
  // ignore: use_super_parameters
  const SupabaseTypedQueryBuilder(
    SupabaseQueryBuilder queryBuilder,
    PostgrestTable<Row> table,
  ) : _queryBuilder = queryBuilder,
      super(queryBuilder, table);

  final SupabaseQueryBuilder _queryBuilder;

  /// Returns real-time data from the table as a `Stream` of `List<Row>`.
  ///
  /// The typed counterpart of [SupabaseQueryBuilder.stream]; rows are
  /// converted through [PostgrestTable.rowFromJson] and [primaryKey] is
  /// expressed with [TableColumn]s.
  ///
  /// ```dart
  /// supabase
  ///     .table(Books.table)
  ///     .stream(primaryKey: [Books.id])
  ///     .listen((List<Book> books) {
  ///   // ...
  /// });
  /// ```
  SupabaseTypedStreamFilterBuilder<Row> stream({
    required List<TableColumn<Object>> primaryKey,
    bool private = false,
  }) {
    return SupabaseTypedStreamFilterBuilder(
      _queryBuilder.stream(
        primaryKey: [for (final column in primaryKey) column.name],
        private: private,
      ),
      table,
    );
  }
}
