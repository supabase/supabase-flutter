import 'package:supabase_typegen/supabase_typegen.dart';

/// A schema built from valid but pathological database names: identifiers
/// that shadow core and imported types, comments and values carrying every
/// line terminator and Dart string metacharacter, array element kinds with
/// dedicated conversions, and pgvector columns, which the fixture database
/// cannot load.
///
/// The golden generated from it, `hostile_schema.dart`, is checked in so the
/// package's own `dart analyze` run proves the generated code stays valid,
/// not merely parseable, for schemas like these.
const DatabaseDescription hostileSchema = DatabaseDescription(
  schemaNames: ['evil\nmultiline "schema" name', 'private', 'public'],
  tables: [
    TableDescription(
      schema: 'public',
      name: 'postgrest_table',
      comment: 'first\rsecond\u2028third \$interpolation "quoted"',
      primaryKey: ["quote'name tail", 'days'],
      columns: [
        ColumnDescription(
          name: "quote'name tail",
          postgresFormat: 'text',
          typeKind: ColumnTypeKind.text,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
          comment: 'says "hi" \\ and \$more',
        ),
        ColumnDescription(
          name: 'mood',
          postgresFormat: 'public.string',
          typeKind: ColumnTypeKind.enumType,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
          enumType: EnumDescription(
            schema: 'public',
            name: 'string',
            values: ["it's \$a\u2028trap", 'plain'],
          ),
        ),
        ColumnDescription(
          name: 'samples',
          postgresFormat: '_float8',
          typeKind: ColumnTypeKind.array,
          elementTypeKind: ColumnTypeKind.floating,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'days',
          postgresFormat: '_date',
          typeKind: ColumnTypeKind.array,
          elementTypeKind: ColumnTypeKind.date,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        // Named like the codec the generated conversions call.
        ColumnDescription(
          name: 'postgrest_bytea',
          postgresFormat: 'bytea',
          typeKind: ColumnTypeKind.binary,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'uint8_list',
          postgresFormat: 'bytea',
          typeKind: ColumnTypeKind.binary,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'blobs',
          postgresFormat: '_bytea',
          typeKind: ColumnTypeKind.array,
          elementTypeKind: ColumnTypeKind.binary,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        // Named like the codec the generated conversions call.
        ColumnDescription(
          name: 'postgrest_vector',
          postgresFormat: 'vector',
          typeKind: ColumnTypeKind.vector,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'half_embedding',
          postgresFormat: 'halfvec',
          typeKind: ColumnTypeKind.vector,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'embeddings',
          postgresFormat: '_vector',
          typeKind: ColumnTypeKind.array,
          elementTypeKind: ColumnTypeKind.vector,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
      ],
    ),
    TableDescription(
      schema: 'public',
      name: 'map',
      columns: [
        ColumnDescription(
          name: 'list',
          postgresFormat: 'int8',
          typeKind: ColumnTypeKind.integer,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'date_time',
          postgresFormat: 'timestamptz',
          typeKind: ColumnTypeKind.timestampWithTimeZone,
          isRequired: false,
          hasDefault: true,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'pages',
          postgresFormat: 'int4range',
          typeKind: ColumnTypeKind.range,
          boundTypeKind: ColumnTypeKind.integer,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'prices',
          postgresFormat: 'numrange',
          typeKind: ColumnTypeKind.range,
          boundTypeKind: ColumnTypeKind.numeric,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'season',
          postgresFormat: 'daterange',
          typeKind: ColumnTypeKind.range,
          boundTypeKind: ColumnTypeKind.date,
          isRequired: false,
          hasDefault: true,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'shift',
          postgresFormat: 'tsrange',
          typeKind: ColumnTypeKind.range,
          boundTypeKind: ColumnTypeKind.timestamp,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'during',
          postgresFormat: 'tstzrange',
          typeKind: ColumnTypeKind.range,
          boundTypeKind: ColumnTypeKind.timestampWithTimeZone,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'since',
          postgresFormat: 'date',
          typeKind: ColumnTypeKind.date,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'opens_at',
          postgresFormat: 'time',
          typeKind: ColumnTypeKind.time,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'closes_at',
          postgresFormat: 'timetz',
          typeKind: ColumnTypeKind.time,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'ttl',
          postgresFormat: 'interval',
          typeKind: ColumnTypeKind.interval,
          isRequired: false,
          hasDefault: true,
          isNullable: true,
        ),
      ],
    ),
    // A table outside public: its type names carry the schema, and the key
    // from public.map into it gets no relation member.
    TableDescription(
      schema: 'evil\nmultiline "schema" name',
      name: 'postgrest_column',
      columns: [
        ColumnDescription(
          name: 'id',
          postgresFormat: 'int8',
          typeKind: ColumnTypeKind.integer,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
      ],
    ),
    // A schema-qualified name long enough that the formatter has to split
    // the representation clause of every extension type generated for it.
    TableDescription(
      schema: 'private',
      name: 'achievement_item_progress_tbl',
      primaryKey: ['id'],
      columns: [
        ColumnDescription(
          name: 'id',
          postgresFormat: 'int8',
          typeKind: ColumnTypeKind.integer,
          isRequired: false,
          hasDefault: true,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'name',
          postgresFormat: 'text',
          typeKind: ColumnTypeKind.text,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
      ],
    ),
  ],
  relationships: [
    // A self reference: PostgREST cannot embed it, so no member is generated.
    RelationshipDescription(
      foreignKeyName: 'map_list_fkey',
      sourceSchema: 'public',
      sourceTable: 'map',
      sourceColumns: ['list'],
      targetSchema: 'public',
      targetTable: 'map',
      targetColumns: ['list'],
    ),
    // A key into another schema: PostgREST cannot embed across schemas, so no
    // member is generated.
    RelationshipDescription(
      foreignKeyName: 'map_list_postgrest_column_fkey',
      sourceSchema: 'public',
      sourceTable: 'map',
      sourceColumns: ['list'],
      targetSchema: 'evil\nmultiline "schema" name',
      targetTable: 'postgrest_column',
      targetColumns: ['id'],
    ),
    // Two keys to the same target: the plain table name is ambiguous.
    RelationshipDescription(
      foreignKeyName: 'postgrest_table_mood_fkey',
      sourceSchema: 'public',
      sourceTable: 'postgrest_table',
      sourceColumns: ['mood'],
      targetSchema: 'public',
      targetTable: 'map',
      targetColumns: ['list'],
    ),
    RelationshipDescription(
      foreignKeyName: 'postgrest_table_days_fkey',
      sourceSchema: 'public',
      sourceTable: 'postgrest_table',
      sourceColumns: ['days'],
      targetSchema: 'public',
      targetTable: 'map',
      targetColumns: ['list'],
      isOneToOne: true,
    ),
  ],
  enums: [
    EnumDescription(
      schema: 'public',
      name: 'string',
      values: ["it's \$a\u2028trap", 'plain'],
    ),
  ],
);
