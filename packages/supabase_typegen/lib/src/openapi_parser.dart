import 'schema_description.dart';

final _foreignKeyPattern = RegExp("<fk table='([^']+)' column='([^']+)'/>");

const _integerFormats = {
  'smallint',
  'integer',
  'bigint',
  'int2',
  'int4',
  'int8',
};
const _floatingFormats = {'real', 'double precision', 'float4', 'float8'};
const _numericFormats = {'numeric', 'decimal'};
const _timestampFormats = {'timestamp', 'timestamp without time zone'};
const _timestampWithTimeZoneFormats = {
  'timestamp with time zone',
  'timestamptz',
};
const _jsonFormats = {'json', 'jsonb'};

/// Derives the [ColumnTypeKind] from the Postgres [format] and JSON schema
/// [jsonType] of a column. This is the single place where type names are
/// compared as strings; everything downstream works with the enum.
ColumnTypeKind _typeKind({
  required String format,
  required String? jsonType,
  required bool isEnum,
}) {
  if (format.endsWith('[]') || jsonType == 'array') {
    return ColumnTypeKind.array;
  }
  if (isEnum) return ColumnTypeKind.enumType;
  if (_integerFormats.contains(format)) return ColumnTypeKind.integer;
  if (_floatingFormats.contains(format)) return ColumnTypeKind.floating;
  if (_numericFormats.contains(format)) return ColumnTypeKind.numeric;
  if (format == 'boolean') return ColumnTypeKind.boolean;
  if (format == 'date') return ColumnTypeKind.date;
  if (_timestampFormats.contains(format)) return ColumnTypeKind.timestamp;
  if (_timestampWithTimeZoneFormats.contains(format)) {
    return ColumnTypeKind.timestampWithTimeZone;
  }
  if (_jsonFormats.contains(format)) return ColumnTypeKind.json;
  return switch (jsonType) {
    'integer' => ColumnTypeKind.integer,
    'number' => ColumnTypeKind.numeric,
    'boolean' => ColumnTypeKind.boolean,
    'string' => ColumnTypeKind.text,
    _ => ColumnTypeKind.unknown,
  };
}

ColumnTypeKind? _elementTypeKind(String? itemsJsonType) => itemsJsonType == null
    ? null
    : switch (itemsJsonType) {
        'integer' => ColumnTypeKind.integer,
        'number' => ColumnTypeKind.numeric,
        'boolean' => ColumnTypeKind.boolean,
        'string' => ColumnTypeKind.text,
        _ => ColumnTypeKind.unknown,
      };

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
    if (definition is! Map<String, dynamic>) continue;
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
      final typeKind = _typeKind(
        format: format,
        jsonType: property['type'] as String?,
        isEnum: enumValues != null,
      );

      if (enumValues != null && typeKind == ColumnTypeKind.enumType) {
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
          typeKind: typeKind,
          elementTypeKind: _elementTypeKind(
            (property['items'] as Map<String, dynamic>?)?['type'] as String?,
          ),
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
      .replaceAll(
        RegExp(r'Note:\s*This is a (Primary|Foreign) Key( to `[^`]+`)?\.'),
        '',
      )
      .trim();
  return cleaned.isEmpty ? null : cleaned;
}
