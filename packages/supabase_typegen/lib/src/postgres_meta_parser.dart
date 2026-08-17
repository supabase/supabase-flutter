import 'schema_description.dart';

/// The metadata document version this parser understands.
const supportedPostgresMetaVersion = 1;

const _integerFormats = {'int2', 'int4', 'int8'};
const _floatingFormats = {'float4', 'float8'};
const _textFormats = {
  'text',
  'citext',
  'varchar',
  'bpchar',
  'char',
  'uuid',
  'time',
  'timetz',
  'interval',
  'bytea',
};
const _jsonFormats = {'json', 'jsonb'};

/// Derives the [ColumnTypeKind] from the postgres-meta [format] of a column,
/// for example `int8`, `timestamptz` or `_text` for a `text[]` array. This is
/// the single place where type names are compared as strings; everything
/// downstream works with the enum.
ColumnTypeKind _typeKind(String format, {required bool isEnum}) {
  if (format.startsWith('_')) return ColumnTypeKind.array;
  if (isEnum) return ColumnTypeKind.enumType;
  if (_integerFormats.contains(format)) return ColumnTypeKind.integer;
  if (_floatingFormats.contains(format)) return ColumnTypeKind.floating;
  if (format == 'numeric') return ColumnTypeKind.numeric;
  if (format == 'bool') return ColumnTypeKind.boolean;
  if (format == 'date') return ColumnTypeKind.date;
  if (format == 'timestamp') return ColumnTypeKind.timestamp;
  if (format == 'timestamptz') return ColumnTypeKind.timestampWithTimeZone;
  if (_textFormats.contains(format)) return ColumnTypeKind.text;
  if (_jsonFormats.contains(format)) return ColumnTypeKind.json;
  return ColumnTypeKind.unknown;
}

/// The kind of the elements of an array column, where enum elements are
/// carried as their wire strings.
ColumnTypeKind _elementTypeKind(String elementFormat, {required bool isEnum}) {
  final kind = _typeKind(elementFormat, isEnum: isEnum);
  return kind == ColumnTypeKind.enumType ? ColumnTypeKind.text : kind;
}

/// Parses the generator metadata document that postgres-meta emits from its
/// `json` generator (`supabase gen types --lang json`, the
/// `/generators/json` endpoint, or `PG_META_GENERATE_TYPES=json`) into a
/// [SchemaDescription] for [schemaName].
///
/// Throws a [FormatException] when the document does not carry the supported
/// `version`.
SchemaDescription parsePostgresMetaDocument(
  Map<String, dynamic> document, {
  String schemaName = 'public',
}) {
  final version = document['version'];
  if (version != supportedPostgresMetaVersion) {
    throw FormatException(
      'Unsupported postgres-meta document version $version; this version of '
      'supabase_typegen supports version $supportedPostgresMetaVersion.',
    );
  }

  final relations = [
    for (final key in ['tables', 'foreignTables', 'views', 'materializedViews'])
      ...?(document[key] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
  ].where((relation) => relation['schema'] == schemaName);

  final columnsByRelationId = <int, List<Map<String, dynamic>>>{};
  for (final column
      in (document['columns'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()) {
    columnsByRelationId
        .putIfAbsent(column['table_id'] as int, () => [])
        .add(column);
  }
  for (final columns in columnsByRelationId.values) {
    columns.sort(
      (a, b) => (a['ordinal_position'] as int).compareTo(
        b['ordinal_position'] as int,
      ),
    );
  }

  final foreignKeysByColumn = _foreignKeysByColumn(document, schemaName);
  final enumTypes = _enumTypes(document, schemaName);

  final tables = <TableDescription>[];
  final enumsByQualifiedName = <String, EnumDescription>{};

  for (final relation in relations) {
    final relationName = relation['name'] as String;
    final primaryKeyNames = {
      for (final primaryKey
          in (relation['primary_keys'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>())
        primaryKey['name'] as String,
    };

    final columns = <ColumnDescription>[];
    for (final column
        in columnsByRelationId[relation['id'] as int] ?? const []) {
      final name = column['name'] as String;
      final format = column['format'] as String;
      final enumValues = (column['enums'] as List<dynamic>? ?? const [])
          .cast<String>();
      final isEnum = enumValues.isNotEmpty;
      final typeKind = _typeKind(format, isEnum: isEnum);
      final isArray = typeKind == ColumnTypeKind.array;

      var postgresFormat = format;
      if (isEnum && !isArray) {
        final enumDescription = _enumDescription(format, enumValues, enumTypes);
        postgresFormat = enumDescription.qualifiedName;
        enumsByQualifiedName.putIfAbsent(
          enumDescription.qualifiedName,
          () => enumDescription,
        );
      }

      final hasDefault =
          column['default_value'] != null ||
          column['is_identity'] as bool ||
          column['is_generated'] as bool;
      final isNullable = column['is_nullable'] as bool;

      columns.add(
        ColumnDescription(
          name: name,
          postgresFormat: postgresFormat,
          typeKind: typeKind,
          elementTypeKind: isArray
              ? _elementTypeKind(format.substring(1), isEnum: isEnum)
              : null,
          enumValues: isEnum ? enumValues : null,
          isRequired: !isNullable && !hasDefault,
          isPrimaryKey: primaryKeyNames.contains(name),
          hasDefault: hasDefault,
          isNullable: isNullable,
          isReadOnly:
              column['identity_generation'] == 'ALWAYS' ||
              column['is_generated'] as bool,
          comment: column['comment'] as String?,
          foreignKey: foreignKeysByColumn[(relationName, name)],
        ),
      );
    }

    tables.add(
      TableDescription(
        name: relationName,
        comment: relation['comment'] as String?,
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

/// Maps `(table, column)` pairs of [schemaName] to their foreign key targets,
/// pairing the source and referenced columns of each relationship by index.
Map<(String, String), ForeignKeyDescription> _foreignKeysByColumn(
  Map<String, dynamic> document,
  String schemaName,
) {
  final foreignKeys = <(String, String), ForeignKeyDescription>{};
  for (final relationship
      in (document['relationships'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()) {
    if (relationship['schema'] != schemaName) continue;
    final table = relationship['relation'] as String;
    final columns = (relationship['columns'] as List<dynamic>).cast<String>();
    final referencedColumns =
        (relationship['referenced_columns'] as List<dynamic>).cast<String>();
    for (var i = 0; i < columns.length; i++) {
      foreignKeys.putIfAbsent(
        (table, columns[i]),
        () => ForeignKeyDescription(
          table: relationship['referenced_relation'] as String,
          column: referencedColumns[i],
        ),
      );
    }
  }
  return foreignKeys;
}

/// Maps enum type names to `(schema, values)`, preferring types of
/// [schemaName] when the same name exists in several schemas.
Map<String, (String, List<String>)> _enumTypes(
  Map<String, dynamic> document,
  String schemaName,
) {
  final enumTypes = <String, (String, List<String>)>{};
  for (final type
      in (document['types'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()) {
    final values = (type['enums'] as List<dynamic>? ?? const []).cast<String>();
    if (values.isEmpty) continue;
    final name = type['name'] as String;
    final schema = type['schema'] as String;
    if (schema == schemaName || !enumTypes.containsKey(name)) {
      enumTypes[name] = (schema, values);
    }
  }
  return enumTypes;
}

EnumDescription _enumDescription(
  String format,
  List<String> columnEnumValues,
  Map<String, (String, List<String>)> enumTypes,
) {
  final type = enumTypes[format];
  return EnumDescription(
    qualifiedName: type == null ? format : '${type.$1}.$format',
    values: type == null ? columnEnumValues : type.$2,
  );
}
