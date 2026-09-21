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
  /// expressed with [PostgrestColumn]s.
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
    required List<PostgrestColumn<Row, Object>> primaryKey,
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
}
