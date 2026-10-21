part of 'postgrest_typed_builder.dart';

/// A stored `NOT NULL` `int2vector` or `oidvector` column of the table whose
/// rows are [Row].
///
/// Compared with a `List<int>` operand, sent as the space-separated literal
/// these types read, `1 2`, instead of the array literal a [PostgrestColumn]
/// of a list type sends, which they reject.
@experimental
final class PostgrestIntegerVectorColumn<Row>
    extends PostgrestColumn<Row, List<int>> {
  /// Creates a reference to the integer vector column called [name] in the
  /// database.
  const PostgrestIntegerVectorColumn(super.name)
    : super(fromJson: _decodeIntegerVector);
}

/// A stored `int2vector` or `oidvector` column the database allows to be
/// `NULL`, see [PostgrestIntegerVectorColumn].
@experimental
final class PostgrestNullableIntegerVectorColumn<Row>
    extends PostgrestNullableColumn<Row, List<int>> {
  /// Creates a reference to the nullable integer vector column called [name]
  /// in the database.
  const PostgrestNullableIntegerVectorColumn(super.name)
    : super(fromJson: _decodeIntegerVector);
}

/// Reads the JSON array PostgREST carries an integer vector as, whose
/// elements are numbers for an `int2vector` and strings for an `oidvector`.
List<int> _decodeIntegerVector(Object json) => [
  for (final element in json as List<dynamic>)
    switch (element) {
      final int value => value,
      _ => int.parse(element as String),
    },
];
