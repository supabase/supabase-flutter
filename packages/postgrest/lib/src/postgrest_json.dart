part of 'postgrest_typed_builder.dart';

/// A decoded `json` or `jsonb` value: a [Map], a [List], a [String], a [num],
/// a [bool], or `null` inside a container.
///
/// The value type of a [PostgrestJsonColumn] and of a JSON path read with
/// [PostgrestColumnExpression.jsonObject]. It is an [Object] at runtime, so a
/// value read from a [PostgrestPartialRow] is used directly, and an operand is
/// wrapped to say it is JSON:
///
/// ```dart
/// .where(Items.data.eq(PostgrestJson([1, 2]))) // data=eq.[1,2]
/// ```
///
/// An operand is sent as JSON only when the expression is a
/// [PostgrestJsonColumn], a [PostgrestNullableJsonColumn] or a JSON path; a
/// [PostgrestColumn] declared with this type sends a [List] as a Postgres
/// array literal.
@experimental
extension type const PostgrestJson(Object _value) implements Object {}

/// A stored `NOT NULL` `json` or `jsonb` column of the table whose rows are
/// [Row].
///
/// Every operand is encoded as JSON, so `eq(PostgrestJson([1, 2]))` sends
/// `[1,2]` instead of the array literal a [PostgrestColumn] of a list type
/// sends. Plain `json` has no comparison or containment operators in
/// Postgres, so filter a `jsonb` column, or a scalar read from a `json`
/// column with [jsonText].
///
/// Read from a [PostgrestPartialRow] as `PostgrestJson?`, since a `NOT NULL`
/// column can still hold the JSON `null`.
@experimental
final class PostgrestJsonColumn<Row>
    extends PostgrestStoredColumn<Row, PostgrestJson>
    implements PostgrestReadable<Row, PostgrestJson?> {
  /// Creates a reference to the JSON column called [name] in the database.
  const PostgrestJsonColumn(String name) : super._(name, null);

  @override
  bool get _encodesJson => true;

  @override
  PostgrestJson? _read(Object? json, _NestedSelection nested) =>
      json == null ? null : _decode(json);

  @override
  bool get _selectedByStar => true;
}

/// A stored `json` or `jsonb` column the database allows to be `NULL`, see
/// [PostgrestJsonColumn].
@experimental
final class PostgrestNullableJsonColumn<Row>
    extends PostgrestNullableColumn<Row, PostgrestJson> {
  /// Creates a reference to the nullable JSON column called [name] in the
  /// database.
  const PostgrestNullableJsonColumn(super.name);

  @override
  bool get _encodesJson => true;
}

/// A computed field returning `json` or `jsonb`, whose operands are encoded
/// as JSON like those of a [PostgrestJsonColumn].
@experimental
final class PostgrestJsonComputedField<Row>
    extends PostgrestComputedField<Row, PostgrestJson> {
  /// Creates a reference to the computed field backed by the function called
  /// [name] in the database.
  const PostgrestJsonComputedField(super.name);

  @override
  bool get _encodesJson => true;
}
