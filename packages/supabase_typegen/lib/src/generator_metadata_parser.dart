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

/// Range types, keyed to the kind of their bounds.
const _rangeBoundKinds = {
  'int4range': ColumnTypeKind.integer,
  'int8range': ColumnTypeKind.integer,
  'numrange': ColumnTypeKind.numeric,
  'daterange': ColumnTypeKind.date,
  'tsrange': ColumnTypeKind.timestamp,
  'tstzrange': ColumnTypeKind.timestampWithTimeZone,
};

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
  if (format == 'bytea') return ColumnTypeKind.binary;
  if (format == 'date') return ColumnTypeKind.date;
  if (format == 'timestamp') return ColumnTypeKind.timestamp;
  if (format == 'timestamptz') return ColumnTypeKind.timestampWithTimeZone;
  if (_rangeBoundKinds.containsKey(format)) return ColumnTypeKind.range;
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
/// `@supabase/postgrest-typegen`, into a [DatabaseDescription] of the
/// schemas named in [schemaNames], or of every schema the document lists when
/// none are given. Named schemas the document does not list are left out.
///
/// The document carries a `version` field, currently 1, and the
/// semantically sorted collections produced by `sortGeneratorMetadata`:
/// `tables`, `foreignTables`, `views`, `materializedViews`, `columns`,
/// `primaryKeys`, `relationships`, `functions` and `types`. Collections and
/// fields the generator does not need, such as `functions`, are ignored.
///
/// Tables and foreign tables are always insertable and updatable. Views use
/// the `is_insert_enabled` and `is_update_enabled` flags, falling back to
/// `is_updatable` for documents that predate the flags. Materialized views
/// are never writable.
///
/// Throws a [FormatException] when the document does not have the
/// `GeneratorMetadata` shape.
DatabaseDescription parseGeneratorMetadata(
  Map<String, dynamic> document, {
  List<String>? schemaNames,
}) {
  try {
    return _parseGeneratorMetadata(document, schemaNames: schemaNames);
  } on TypeError catch (error) {
    throw FormatException(
      'Not a GeneratorMetadata document: a record does not have the '
      'expected shape ($error).',
    );
  }
}

const _relationCollections = [
  'tables',
  'foreignTables',
  'views',
  'materializedViews',
];

DatabaseDescription _parseGeneratorMetadata(
  Map<String, dynamic> document, {
  required List<String>? schemaNames,
}) {
  if (document['tables'] is! List<dynamic> ||
      document['columns'] is! List<dynamic>) {
    throw const FormatException(
      'Not a GeneratorMetadata document: expected the introspection contract '
      'of @supabase/postgrest-typegen, with "tables" and "columns" lists.',
    );
  }

  final documentSchemas = _documentSchemas(document);
  final schemas = {
    for (final schema in schemaNames ?? documentSchemas)
      if (documentSchemas.isEmpty || documentSchemas.contains(schema)) schema,
  };

  final relations = [
    for (final table in _relationsOf(document, 'tables', schemas))
      (relation: table, isInsertable: true, isUpdatable: true),
    for (final foreignTable in _relationsOf(
      document,
      'foreignTables',
      schemas,
    ))
      (relation: foreignTable, isInsertable: true, isUpdatable: true),
    for (final view in _relationsOf(document, 'views', schemas))
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
      schemas,
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

  final foreignKeysByColumn = _foreignKeysByColumn(document, schemas);
  final primaryKeysByTable = _primaryKeysByTable(document, schemas);
  final enumTypes = _enumTypes(document);

  final tables = <TableDescription>[];
  final enumsByType = <(String, String), EnumDescription>{};

  for (final (:relation, :isInsertable, :isUpdatable) in relations) {
    final relationSchema = relation['schema'] as String;
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
      EnumDescription? enumDescription;
      if (isEnum) {
        final described = _enumDescription(
          isArray ? format.substring(1) : format,
          column['type_schema'] as String,
          enumValues,
          enumTypes,
        );
        // Every column of one enum shares the description registered first.
        enumDescription = enumsByType.putIfAbsent(
          (described.schema, described.name),
          () => described,
        );
        // Array elements stay in their wire representation, but the enum the
        // elements belong to is still emitted for manual conversion.
        if (!isArray) {
          postgresFormat = enumDescription.qualifiedName;
        }
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
          boundTypeKind: _rangeBoundKinds[format],
          enumValues: isEnum ? enumValues : null,
          enumType: enumDescription,
          isRequired: !isNullable && !hasDefault,
          hasDefault: hasDefault,
          isNullable: isNullable,
          isReadOnly:
              column['identity_generation'] == 'ALWAYS' ||
              column['is_generated'] as bool ||
              !(column['is_updatable'] as bool),
          comment: column['comment'] as String?,
          foreignKey: foreignKeysByColumn[(relationSchema, relationName, name)],
        ),
      );
    }

    tables.add(
      TableDescription(
        schema: relationSchema,
        name: relationName,
        comment: relation['comment'] as String?,
        columns: columns,
        primaryKey:
            primaryKeysByTable[(relationSchema, relationName)] ?? const [],
        isInsertable: isInsertable,
        isUpdatable: isUpdatable,
      ),
    );
  }

  tables.sort(
    (a, b) => a.schema == b.schema
        ? a.name.compareTo(b.name)
        : a.schema.compareTo(b.schema),
  );
  final enums = enumsByType.values.toList()
    ..sort(
      (a, b) => a.schema == b.schema
          ? a.name.compareTo(b.name)
          : a.schema.compareTo(b.schema),
    );

  return DatabaseDescription(
    metadataVersion: document['version'] as int? ?? 1,
    schemaNames: schemas.toList()..sort(),
    tables: tables,
    enums: enums,
    relationships: _relationships(document, {
      for (final table in tables) (table.schema, table.name),
    }),
  );
}

/// The schemas the document describes: its `schemas` collection, or the
/// schemas of its relations for documents that carry none.
Set<String> _documentSchemas(Map<String, dynamic> document) {
  final listed = (document['schemas'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()
      .map((schema) => schema['name'] as String);
  if (listed.isNotEmpty) return listed.toSet();
  return {
    for (final collection in _relationCollections)
      for (final relation
          in (document[collection] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>())
        relation['schema'] as String,
  };
}

/// The relations of one document collection, such as `views`, that belong to
/// one of [schemas].
Iterable<Map<String, dynamic>> _relationsOf(
  Map<String, dynamic> document,
  String collection,
  Set<String> schemas,
) => (document[collection] as List<dynamic>? ?? const [])
    .cast<Map<String, dynamic>>()
    .where((relation) => schemas.contains(relation['schema']));

/// The foreign keys whose both ends are among the generated [relations],
/// whatever their schemas; a key into a schema that is not generated has no
/// row type to point at and is left out.
List<RelationshipDescription> _relationships(
  Map<String, dynamic> document,
  Set<(String, String)> relations,
) => [
  for (final relationship
      in (document['relationships'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>())
    if (relations.contains((
          relationship['schema'] as String,
          relationship['relation'] as String,
        )) &&
        relations.contains((
          relationship['referenced_schema'] as String,
          relationship['referenced_relation'] as String,
        )))
      RelationshipDescription(
        foreignKeyName: relationship['foreign_key_name'] as String,
        sourceSchema: relationship['schema'] as String,
        sourceTable: relationship['relation'] as String,
        sourceColumns: (relationship['columns'] as List<dynamic>).cast(),
        targetSchema: relationship['referenced_schema'] as String,
        targetTable: relationship['referenced_relation'] as String,
        targetColumns: (relationship['referenced_columns'] as List<dynamic>)
            .cast(),
        isOneToOne: relationship['is_one_to_one'] as bool? ?? false,
      ),
];

/// Maps each `(schema, table)` of [schemas] to the names of its primary key
/// columns, in the order the document lists them, which is key order.
Map<(String, String), List<String>> _primaryKeysByTable(
  Map<String, dynamic> document,
  Set<String> schemas,
) {
  final primaryKeys = <(String, String), List<String>>{};
  for (final primaryKey
      in (document['primaryKeys'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()) {
    final schema = primaryKey['schema'] as String;
    if (!schemas.contains(schema)) continue;
    primaryKeys
        .putIfAbsent((schema, primaryKey['table_name'] as String), () => [])
        .add(primaryKey['name'] as String);
  }
  return primaryKeys;
}

/// Maps `(schema, table, column)` triples of [schemas] to their foreign key
/// targets, pairing the source and referenced columns of each relationship by
/// index.
///
/// The document also lists a relationship for every view that exposes the
/// referenced key column, so the target of a column is the referenced table
/// itself, and one of those views only when the table is not in the document.
Map<(String, String, String), ForeignKeyDescription> _foreignKeysByColumn(
  Map<String, dynamic> document,
  Set<String> schemas,
) {
  final tables = {
    for (final collection in const ['tables', 'foreignTables'])
      for (final table
          in (document[collection] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>())
        (table['schema'] as String, table['name'] as String),
  };
  final relationships =
      (document['relationships'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) {
          final aIsTable = tables.contains((
            a['referenced_schema'] as String,
            a['referenced_relation'] as String,
          ));
          final bIsTable = tables.contains((
            b['referenced_schema'] as String,
            b['referenced_relation'] as String,
          ));
          if (aIsTable == bIsTable) return 0;
          return aIsTable ? -1 : 1;
        });

  final foreignKeys = <(String, String, String), ForeignKeyDescription>{};
  for (final relationship in relationships) {
    final schema = relationship['schema'] as String;
    if (!schemas.contains(schema)) continue;
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
        (schema, table, columns[i]),
        () => ForeignKeyDescription(
          schema: relationship['referenced_schema'] as String,
          table: relationship['referenced_relation'] as String,
          column: referencedColumns[i],
        ),
      );
    }
  }
  return foreignKeys;
}

/// Maps `(schema, name)` pairs of enum types to their values in declaration
/// order.
Map<(String, String), List<String>> _enumTypes(Map<String, dynamic> document) {
  final enumTypes = <(String, String), List<String>>{};
  for (final type
      in (document['types'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()) {
    final values = (type['enums'] as List<dynamic>? ?? const []).cast<String>();
    if (values.isEmpty) continue;
    enumTypes[(type['schema'] as String, type['name'] as String)] = values;
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
  Map<(String, String), List<String>> enumTypes,
) => EnumDescription(
  schema: typeSchema,
  name: format,
  values: enumTypes[(typeSchema, format)] ?? columnEnumValues,
);
