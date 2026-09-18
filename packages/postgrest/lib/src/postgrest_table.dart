part of 'postgrest_typed_builder.dart';

/// Converts a single decoded PostgREST row into [Row].
@experimental
typedef RowConverter<Row> = Row Function(Map<String, dynamic> json);

/// Describes a database table (or view) together with the Dart types its rows
/// are read as and written with.
///
/// Passing a [PostgrestTable] to [PostgrestClient.table] gives fully typed
/// query results, so no raw `Map<String, dynamic>` needs to be handled, and
/// only accepts [Insert] and [Update] values on the write methods:
///
/// ```dart
/// extension type Book(Map<String, dynamic> json) implements Object {
///   int get id => json['id'] as int;
///   String get title => json['title'] as String;
/// }
///
/// extension type BookInsert._(Map<String, dynamic> json) implements Object {
///   BookInsert({required String title}) : this._({'title': title});
/// }
///
/// extension type BookUpdate._(Map<String, dynamic> json) implements Object {
///   BookUpdate({String? title}) : this._({'title': ?title});
/// }
///
/// class Books {
///   static const table = PostgrestTable<Book, BookInsert, BookUpdate>(
///     'books',
///     Book.new,
///     primaryKey: [id],
///   );
///   static const id = PostgrestColumn<Book, int>('id');
///   static const title = PostgrestColumn<Book, String>('title');
/// }
///
/// final List<Book> books = await client
///     .table(Books.table)
///     .select()
///     .where(Books.title.like('%Dart%'))
///     .order(Books.id.desc());
///
/// await client.table(Books.table).insert(BookInsert(title: 'Dart'));
/// ```
///
/// [Insert] and [Update] are sent as the request body, so a value has to be
/// the JSON object to send, in practice an extension type over the
/// `Map<String, dynamic>` as above. Both have to be spelled out, since nothing
/// in the constructor arguments can infer them. A read-only relation, such as a
/// materialized view, uses `Never` for the write types it does not support,
/// which makes the corresponding methods uncallable.
///
/// Extension types over the decoded JSON map (as above) are the recommended
/// row representation since they carry no conversion cost and tolerate
/// partial selects, but any converter works, for example `Book.fromJson` on a
/// regular data class. `package:supabase_typegen` generates all three types
/// and the table definition, including [primaryKey] and [relations], from the
/// database schema.
@experimental
// ignore: avoid-unused-generics
class PostgrestTable<Row, Insert, Update> {
  const PostgrestTable(
    this.name,
    this.rowFromJson, {
    required this.primaryKey,
    this.relations = const [],
  });

  /// Name of the table in the database.
  final String name;

  /// Converts a decoded row into [Row].
  final RowConverter<Row> rowFromJson;

  /// The columns that identify a row, in key order.
  ///
  /// Empty for a view or a table without a primary key, where nothing on
  /// the client can tell two rows apart.
  final List<PostgrestColumn<Row, Object>> primaryKey;

  /// The foreign keys this table holds and the ones pointing at it, each as
  /// the relation an embedded select addresses it by.
  final List<PostgrestRelation<Row, Object?>> relations;
}
