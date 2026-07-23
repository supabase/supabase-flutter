import 'schema_description.dart';

final _foreignKeyPattern = RegExp("<fk table='([^']+)' column='([^']+)'/>");

/// Parses the OpenAPI (Swagger 2.0) document that PostgREST serves at the
/// API root into a [SchemaDescription].
///
/// PostgREST encodes primary keys and foreign keys as `<pk/>` and
/// `<fk table='...' column='...'/>` markers inside column descriptions, and
/// lists `NOT NULL` columns without a database default under `required`.
SchemaDescription parseOpenApiDocument(
  Map<String, dynamic> document, {
  String schemaName = 'public',
}) {
  final definitions =
      document['definitions'] as Map<String, dynamic>? ?? const {};

  final tables = <TableDescription>[];
  final enumsByQualifiedName = <String, EnumDescription>{};

  for (final MapEntry(key: tableName, value: definition)
      in definitions.entries) {
    definition as Map<String, dynamic>;
    final required = {
      ...?(definition['required'] as List<dynamic>?)?.cast<String>(),
    };
    final properties =
        definition['properties'] as Map<String, dynamic>? ?? const {};

    final columns = <ColumnDescription>[];
    for (final MapEntry(key: columnName, value: property)
        in properties.entries) {
      property as Map<String, dynamic>;
      final description = property['description'] as String?;
      final format = property['format'] as String? ?? '';
      final enumValues = (property['enum'] as List<dynamic>?)?.cast<String>();

      if (enumValues != null) {
        enumsByQualifiedName.putIfAbsent(
          format,
          () => EnumDescription(qualifiedName: format, values: enumValues),
        );
      }

      final foreignKeyMatch = description == null
          ? null
          : _foreignKeyPattern.firstMatch(description);

      columns.add(
        ColumnDescription(
          name: columnName,
          postgresFormat: format,
          jsonType: property['type'] as String? ?? '',
          arrayElementJsonType:
              (property['items'] as Map<String, dynamic>?)?['type'] as String?,
          enumValues: enumValues,
          isRequired: required.contains(columnName),
          isPrimaryKey: description?.contains('<pk/>') ?? false,
          hasDefault: property.containsKey('default'),
          comment: _cleanComment(description),
          foreignKey: foreignKeyMatch == null
              ? null
              : ForeignKeyDescription(
                  table: foreignKeyMatch.group(1)!,
                  column: foreignKeyMatch.group(2)!,
                ),
        ),
      );
    }

    tables.add(
      TableDescription(
        name: tableName,
        comment: _cleanComment(definition['description'] as String?),
        columns: columns,
      ),
    );
  }

  tables.sort((a, b) => a.name.compareTo(b.name));
  final enums = enumsByQualifiedName.values.toList()
    ..sort((a, b) => a.qualifiedName.compareTo(b.qualifiedName));

  return SchemaDescription(
    schemaName: schemaName,
    tables: tables,
    enums: enums,
  );
}

/// Strips the PostgREST key markers from a column or table description,
/// keeping only the human written comment.
String? _cleanComment(String? description) {
  if (description == null) return null;
  final cleaned = description
      .replaceAll(_foreignKeyPattern, '')
      .replaceAll('<pk/>', '')
      .replaceAll(RegExp(r'Note:\s*'), '')
      .replaceAll(
        RegExp(r'This is a (Primary|Foreign) Key( to `[^`]+`)?\.'),
        '',
      )
      .trim();
  return cleaned.isEmpty ? null : cleaned;
}
