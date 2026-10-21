// The Postgres value types of supabase_common are experimental with this API.
// ignore_for_file: experimental_member_use

part of 'postgrest_typed_builder.dart';

/// A stored `NOT NULL` pgvector `vector` or `halfvec` column of the table
/// whose rows are [Row].
///
/// Compared with a `List<double>` operand, sent as the vector literal
/// `[0.1,0.2]` instead of the array literal a [PostgrestColumn] of a list
/// type sends.
@experimental
final class PostgrestVectorColumn<Row>
    extends PostgrestColumn<Row, List<double>> {
  /// Creates a reference to the vector column called [name] in the database.
  const PostgrestVectorColumn(super.name) : super(fromJson: _decodeVector);
}

/// Reads the vector literal PostgREST carries a vector as.
List<double> _decodeVector(Object json) =>
    postgresVector.decode(json as String);

/// A stored pgvector `vector` or `halfvec` column the database allows to be
/// `NULL`, see [PostgrestVectorColumn].
@experimental
final class PostgrestNullableVectorColumn<Row>
    extends PostgrestNullableColumn<Row, List<double>> {
  /// Creates a reference to the nullable vector column called [name] in the
  /// database.
  const PostgrestNullableVectorColumn(super.name)
    : super(fromJson: _decodeVector);
}
