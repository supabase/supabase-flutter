import 'schema_description.dart';

const _integerFormats = {'int2', 'int4', 'int8', 'oid'};
const _floatingFormats = {'float4', 'float8'};

/// Types that PostgREST serializes as JSON strings.
const _textFormats = {
  'text',
  'citext',
  'varchar',
  'bpchar',
  'char',
  'name',
  'uuid',
  'time',
  'timetz',
  'interval',
  'bytea',
  'inet',
  'cidr',
  'macaddr',
  'macaddr8',
  'money',
  'xml',
  'bit',
  'varbit',
  'tsvector',
  'tsquery',
};
const _jsonFormats = {'json', 'jsonb'};

/// Derives the [ColumnTypeKind] from the metadata [format] of a column,
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

/// Parses a `GeneratorMetadata` document, the introspection contract of
/// `@supabase/postgrest-typegen`, into a [SchemaDescription] for
/// [schemaName].
///
/// The document carries a `version` field, currently 1, and the
/// semantically sorted collections produced by `sortGeneratorMetadata`:
/// `tables`, `foreignTables`, `views`, `materializedViews`, `columns`,
/// `primaryKeys`, `relationships`, `functions` and `types`. Collections and
/// fields the generator does not need, such as `primaryKeys`, are ignored.
///
/// Tables and foreign tables are always insertable and updatable. Views use
/// the `is_insert_enabled` and `is_update_enabled` flags, falling back to
/// `is_updatable` for documents that predate the flags. Materialized views
/// are never writable.
///
/// Throws a [FormatException] when the document does not have the
/// `GeneratorMetadata` shape.
SchemaDescription parseGeneratorMetadata(
  Map<String, dynamic> document, {
  String schemaName = 'public',
}) {
  try {
    return _parseGeneratorMetadata(document, schemaName: schemaName);
  } on TypeError catch (error) {
    throw FormatException(
      'Not a GeneratorMetadata document: a record does not have the '
      'expected shape ($error).',
    );
  }
}

SchemaDescription _parseGeneratorMetadata(
  Map<String, dynamic> document, {
  required String schemaName,
}) {
  if (document['tables'] is! List<dynamic> ||
      document['columns'] is! List<dynamic>) {
    throw const FormatException(
      'Not a GeneratorMetadata document: expected the introspection contract '
      'of @supabase/postgrest-typegen, with "tables" and "columns" lists.',
    );
  }

  final relations = [
    for (final table in _relationsOf(document, 'tables', schemaName))
      (relation: table, isInsertable: true, isUpdatable: true),
    for (final foreignTable in _relationsOf(
      document,
      'foreignTables',
      schemaName,
    ))
      (relation: foreignTable, isInsertable: true, isUpdatable: true),
    for (final view in _relationsOf(document, 'views', schemaName))
      (
        relation: view,
        isInsertable:
            (view['is_insert_enabled'] ?? view['is_updatable']) as bool,
        isUpdatable:
            (view['is_update_enabled'] ?? view['is_updatable']) as bool,
      ),
    for (final materializedView in _relationsOf(
      document,
      'materializedViews',
      schemaName,
    ))
      (relation: materializedView, isInsertable: false, isUpdatable: false),
  ];

  // Document order is kept: `sortGeneratorMetadata` orders columns by name
  // within a table, the canonical order every postgrest-typegen generator
  // emits.
  final columnsByRelationId = <int, List<Map<String, dynamic>>>{};
  for (final column
      in (document['columns'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()) {
    columnsByRelationId
        .putIfAbsent(column['table_id'] as int, () => [])
        .add(column);
  }

  final foreignKeysByColumn = _foreignKeysByColumn(document, schemaName);
  final enumTypes = _enumTypes(document);

  final tables = <TableDescription>[];
  final enumsByQualifiedName = <String, EnumDescription>{};

  for (final (:relation, :isInsertable, :isUpdatable) in relations) {
    final relationName = relation['name'] as String;

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
      if (isEnum) {
        final enumDescription = _enumDescription(
          isArray ? format.substring(1) : format,
          column['type_schema'] as String,
          enumValues,
          enumTypes,
        );
        // Array elements stay in their wire representation, but the enum the
        // elements belong to is still emitted for manual conversion.
        if (!isArray) {
          postgresFormat = enumDescription.qualifiedName;
        }
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
          hasDefault: hasDefault,
          isNullable: isNullable,
          isReadOnly:
              column['identity_generation'] == 'ALWAYS' ||
              column['is_generated'] as bool ||
              !(column['is_updatable'] as bool),
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
        isInsertable: isInsertable,
        isUpdatable: isUpdatable,
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

/// The relations of one document collection, such as `views`, that belong to
/// [schemaName].
Iterable<Map<String, dynamic>> _relationsOf(
  Map<String, dynamic> document,
  String collection,
  String schemaName,
) => (document[collection] as List<dynamic>? ?? const [])
    .cast<Map<String, dynamic>>()
    .where((relation) => relation['schema'] == schemaName);

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
    if (columns.length != referencedColumns.length) {
      throw FormatException(
        'Not a GeneratorMetadata document: the relationship '
        '"${relationship['foreign_key_name']}" pairs ${columns.length} '
        'columns with ${referencedColumns.length} referenced columns.',
      );
    }
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

/// Maps schema-qualified enum type names, for example `public.mood`, to
/// their values in declaration order.
Map<String, List<String>> _enumTypes(Map<String, dynamic> document) {
  final enumTypes = <String, List<String>>{};
  for (final type
      in (document['types'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()) {
    final values = (type['enums'] as List<dynamic>? ?? const []).cast<String>();
    if (values.isEmpty) continue;
    enumTypes['${type['schema']}.${type['name']}'] = values;
  }
  return enumTypes;
}

/// Resolves the enum type of a column exactly, by the column's `type_schema`
/// and type name. Falls back to the values carried on the column itself when
/// the type is missing from the document's `types` list.
EnumDescription _enumDescription(
  String format,
  String typeSchema,
  List<String> columnEnumValues,
  Map<String, List<String>> enumTypes,
) {
  final qualifiedName = '$typeSchema.$format';
  return EnumDescription(
    qualifiedName: qualifiedName,
    values: enumTypes[qualifiedName] ?? columnEnumValues,
  );
}
