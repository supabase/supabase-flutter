part of 'postgrest_typed_builder.dart';

/// Converts a single decoded PostgREST row into [Row].
@experimental
typedef RowConverter<Row> = Row Function(Map<String, dynamic> json);

/// Describes a database table (or view) together with the Dart type its rows
/// are converted into.
///
/// Passing a [PostgrestTable] to [PostgrestClient.table] gives fully typed
/// query results, so no raw `Map<String, dynamic>` needs to be handled:
///
/// ```dart
/// extension type Book(Map<String, dynamic> json) {
///   int get id => json['id'] as int;
///   String get title => json['title'] as String;
/// }
///
/// class Books {
///   static const table = PostgrestTable('books', Book.new);
///   static const id = PostgrestColumn<Book, int>('id');
///   static const title = PostgrestColumn<Book, String>('title');
/// }
///
/// final List<Book> books = await client
///     .table(Books.table)
///     .select()
///     .where(Books.title.like('%Dart%'))
///     .order(Books.id.desc());
/// ```
///
/// Extension types over the decoded JSON map (as above) are the recommended
/// row representation since they carry no conversion cost and tolerate
/// partial selects, but any converter works, for example `Book.fromJson` on a
/// regular data class.
@experimental
class PostgrestTable<Row> {
  const PostgrestTable(this.name, this.rowFromJson);

  /// Name of the table in the database.
  final String name;

  /// Converts a decoded row into [Row].
  final RowConverter<Row> rowFromJson;
}
