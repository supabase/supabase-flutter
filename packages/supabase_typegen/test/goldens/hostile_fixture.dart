import 'package:supabase_typegen/supabase_typegen.dart';

/// A schema built from valid but pathological database names: identifiers
/// that shadow core and imported types, comments and values carrying every
/// line terminator and Dart string metacharacter, array element kinds with
/// dedicated conversions, pgvector columns, which the fixture database
/// cannot load, and functions named like the members their generated
/// methods sit next to.
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
      computedFields: [
        // A reserved word, suffixed like a column of that name.
        ComputedFieldDescription(
          name: 'class',
          postgresFormat: 'text',
          typeKind: ColumnTypeKind.text,
        ),
        // Named like the table definition member of the namespace class.
        ComputedFieldDescription(
          name: 'table',
          postgresFormat: 'bool',
          typeKind: ColumnTypeKind.boolean,
        ),
        // Spelled differently from the first column but camel-cased the
        // same, so the member is kept apart from the column constant.
        ComputedFieldDescription(
          name: 'quote_name_tail',
          postgresFormat: 'int8',
          typeKind: ColumnTypeKind.integer,
        ),
        // An array of a shadowing enum, decoded through the shared helper.
        ComputedFieldDescription(
          name: 'moods_by_weight',
          postgresFormat: '_string',
          typeKind: ColumnTypeKind.array,
          elementTypeKind: ColumnTypeKind.enumType,
          enumType: EnumDescription(
            schema: 'public',
            name: 'string',
            values: ["it's \$a trap", 'plain'],
          ),
        ),
        ComputedFieldDescription(
          name: 'thumbnail',
          postgresFormat: 'bytea',
          typeKind: ColumnTypeKind.binary,
        ),
      ],
      computedRelationships: [
        // To-one, next to the two hinted foreign keys into the same table.
        ComputedRelationshipDescription(
          name: 'map',
          targetSchema: 'public',
          targetTable: 'map',
          isToMany: false,
        ),
        // Into another generated schema, which a foreign key could not
        // embed.
        ComputedRelationshipDescription(
          name: 'postgrest_column',
          targetSchema: 'evil\nmultiline "schema" name',
          targetTable: 'postgrest_column',
          isToMany: true,
        ),
      ],
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
          name: 'postgres_bytea',
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
          name: 'postgres_vector',
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
        ColumnDescription(
          name: 'moods',
          postgresFormat: '_string',
          typeKind: ColumnTypeKind.array,
          elementTypeKind: ColumnTypeKind.enumType,
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
          name: 'spans',
          postgresFormat: '_int4range',
          typeKind: ColumnTypeKind.array,
          elementTypeKind: ColumnTypeKind.range,
          boundTypeKind: ColumnTypeKind.integer,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'stamps',
          postgresFormat: '_timestamptz',
          typeKind: ColumnTypeKind.array,
          elementTypeKind: ColumnTypeKind.timestampWithTimeZone,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'shifts',
          postgresFormat: '_tsrange',
          typeKind: ColumnTypeKind.array,
          elementTypeKind: ColumnTypeKind.range,
          boundTypeKind: ColumnTypeKind.timestamp,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
      ],
    ),
    TableDescription(
      schema: 'public',
      name: 'map',
      // Self-referential computed relationships, which are how PostgREST
      // embeds a table into itself.
      computedRelationships: [
        ComputedRelationshipDescription(
          name: 'parent',
          targetSchema: 'public',
          targetTable: 'map',
          isToMany: false,
        ),
        ComputedRelationshipDescription(
          name: 'children',
          targetSchema: 'public',
          targetTable: 'map',
          isToMany: true,
        ),
      ],
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
        // Sent as JSON strings, so they cannot be read as decoded numbers.
        ColumnDescription(
          name: 'relation',
          postgresFormat: 'oid',
          typeKind: ColumnTypeKind.integerString,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'relations',
          postgresFormat: '_oid',
          typeKind: ColumnTypeKind.array,
          elementTypeKind: ColumnTypeKind.integerString,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'transaction',
          postgresFormat: 'xid8',
          typeKind: ColumnTypeKind.bigInteger,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'key_columns',
          postgresFormat: 'int2vector',
          typeKind: ColumnTypeKind.integerVector,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'argument_types',
          postgresFormat: 'oidvector',
          typeKind: ColumnTypeKind.integerVector,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'host',
          postgresFormat: 'inet',
          typeKind: ColumnTypeKind.networkAddress,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'allowed_networks',
          postgresFormat: '_cidr',
          typeKind: ColumnTypeKind.array,
          elementTypeKind: ColumnTypeKind.networkAddress,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'location',
          postgresFormat: 'point',
          typeKind: ColumnTypeKind.point,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'axis',
          postgresFormat: 'line',
          typeKind: ColumnTypeKind.line,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'edge',
          postgresFormat: 'lseg',
          typeKind: ColumnTypeKind.lineSegment,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'bounds',
          postgresFormat: 'box',
          typeKind: ColumnTypeKind.box,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'route',
          postgresFormat: 'path',
          typeKind: ColumnTypeKind.path,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'outline',
          postgresFormat: 'polygon',
          typeKind: ColumnTypeKind.polygon,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'reach',
          postgresFormat: 'circle',
          typeKind: ColumnTypeKind.circle,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'availability',
          postgresFormat: 'datemultirange',
          typeKind: ColumnTypeKind.multirange,
          boundTypeKind: ColumnTypeKind.date,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'blackouts',
          postgresFormat: '_int4multirange',
          typeKind: ColumnTypeKind.array,
          elementTypeKind: ColumnTypeKind.multirange,
          boundTypeKind: ColumnTypeKind.integer,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'shifts',
          postgresFormat: 'tsmultirange',
          typeKind: ColumnTypeKind.multirange,
          boundTypeKind: ColumnTypeKind.timestamp,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'position',
          postgresFormat: 'pg_lsn',
          typeKind: ColumnTypeKind.logSequenceNumber,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'hardware',
          postgresFormat: 'macaddr',
          typeKind: ColumnTypeKind.macAddress,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
        ColumnDescription(
          name: 'hardware_history',
          postgresFormat: '_macaddr8',
          typeKind: ColumnTypeKind.array,
          elementTypeKind: ColumnTypeKind.macAddress,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
      ],
    ),
    TableDescription(
      schema: 'public',
      name: 'core_type_names',
      computedFields: [
        ComputedFieldDescription(
          name: 'bool',
          postgresFormat: 'float8',
          typeKind: ColumnTypeKind.floating,
        ),
      ],
      computedRelationships: [
        ComputedRelationshipDescription(
          name: 'double',
          targetSchema: 'public',
          targetTable: 'map',
          isToMany: false,
        ),
      ],
      columns: [
        ColumnDescription(
          name: 'num',
          postgresFormat: 'int4',
          typeKind: ColumnTypeKind.integer,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'int',
          postgresFormat: 'numeric',
          typeKind: ColumnTypeKind.numeric,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'active',
          postgresFormat: 'bool',
          typeKind: ColumnTypeKind.boolean,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
      ],
    ),
    TableDescription(
      schema: 'public',
      name: 'orders',
      columns: [
        ColumnDescription(
          name: 'status',
          postgresFormat: 'статус',
          typeKind: ColumnTypeKind.enumType,
          enumType: EnumDescription(
            schema: 'public',
            name: 'статус',
            values: ['новый', 'готов'],
          ),
          isRequired: true,
          hasDefault: false,
          isNullable: false,
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
    // Joined to profile by keys in both directions, and loaded by the
    // embedding integration test from the local stack.
    TableDescription(
      schema: 'public',
      name: 'team',
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
        ColumnDescription(
          name: 'owner_id',
          postgresFormat: 'int8',
          typeKind: ColumnTypeKind.integer,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
      ],
    ),
    // Its key into team is a column named like the table it references.
    TableDescription(
      schema: 'public',
      name: 'profile',
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
        ColumnDescription(
          name: 'team',
          postgresFormat: 'int8',
          typeKind: ColumnTypeKind.integer,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
      ],
    ),
    // A single key into profile, through a column named like the table, and
    // a key into team next to the junction table between the two.
    TableDescription(
      schema: 'public',
      name: 'badge',
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
        ColumnDescription(
          name: 'profile',
          postgresFormat: 'int8',
          typeKind: ColumnTypeKind.integer,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'team',
          postgresFormat: 'int8',
          typeKind: ColumnTypeKind.integer,
          isRequired: false,
          hasDefault: false,
          isNullable: true,
        ),
      ],
    ),
    // A junction table between team and badge, whose primary key covers both
    // keys.
    TableDescription(
      schema: 'public',
      name: 'team_badge',
      primaryKey: ['team_id', 'badge_id'],
      columns: [
        ColumnDescription(
          name: 'team_id',
          postgresFormat: 'int8',
          typeKind: ColumnTypeKind.integer,
          isRequired: true,
          hasDefault: false,
          isNullable: false,
        ),
        ColumnDescription(
          name: 'badge_id',
          postgresFormat: 'int8',
          typeKind: ColumnTypeKind.integer,
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
    // Keys in opposite directions between two tables: the plain table name
    // is ambiguous either way, and the embed key of the first is a column.
    RelationshipDescription(
      foreignKeyName: 'profile_team_fkey',
      sourceSchema: 'public',
      sourceTable: 'profile',
      sourceColumns: ['team'],
      targetSchema: 'public',
      targetTable: 'team',
      targetColumns: ['id'],
    ),
    RelationshipDescription(
      foreignKeyName: 'team_owner_id_fkey',
      sourceSchema: 'public',
      sourceTable: 'team',
      sourceColumns: ['owner_id'],
      targetSchema: 'public',
      targetTable: 'profile',
      targetColumns: ['id'],
    ),
    // The only key between the two tables, but its embed key is a column.
    RelationshipDescription(
      foreignKeyName: 'badge_profile_fkey',
      sourceSchema: 'public',
      sourceTable: 'badge',
      sourceColumns: ['profile'],
      targetSchema: 'public',
      targetTable: 'profile',
      targetColumns: ['id'],
    ),
    // A single key, but the junction table makes a second relationship
    // between badge and team.
    RelationshipDescription(
      foreignKeyName: 'badge_team_fkey',
      sourceSchema: 'public',
      sourceTable: 'badge',
      sourceColumns: ['team'],
      targetSchema: 'public',
      targetTable: 'team',
      targetColumns: ['id'],
    ),
    RelationshipDescription(
      foreignKeyName: 'team_badge_team_id_fkey',
      sourceSchema: 'public',
      sourceTable: 'team_badge',
      sourceColumns: ['team_id'],
      targetSchema: 'public',
      targetTable: 'team',
      targetColumns: ['id'],
    ),
    RelationshipDescription(
      foreignKeyName: 'team_badge_badge_id_fkey',
      sourceSchema: 'public',
      sourceTable: 'team_badge',
      sourceColumns: ['badge_id'],
      targetSchema: 'public',
      targetTable: 'badge',
      targetColumns: ['id'],
    ),
  ],
  functions: [
    // Named like the method a call of `client.rpc` goes through.
    FunctionDescription(
      schema: 'public',
      name: 'call',
      overloads: [
        FunctionOverloadDescription(
          arguments: [],
          result: FunctionValueResult(
            ValueTypeDescription(
              postgresFormat: 'int8',
              typeKind: ColumnTypeKind.integer,
            ),
            isSetReturning: false,
          ),
        ),
      ],
    ),
    // Named like the generated method body's callee, with parameters named
    // like it and like the codecs the body refers to.
    FunctionDescription(
      schema: 'public',
      name: 'rows',
      overloads: [
        FunctionOverloadDescription(
          arguments: [
            FunctionArgumentDescription(
              name: 'postgres_bytea',
              type: ValueTypeDescription(
                postgresFormat: 'bytea',
                typeKind: ColumnTypeKind.binary,
              ),
              hasDefault: true,
            ),
            FunctionArgumentDescription(
              name: 'rows',
              type: ValueTypeDescription(
                postgresFormat: 'int4range',
                typeKind: ColumnTypeKind.range,
                boundTypeKind: ColumnTypeKind.integer,
              ),
              hasDefault: false,
            ),
            FunctionArgumentDescription(
              name: 'value',
              type: ValueTypeDescription(
                postgresFormat: 'public.string',
                typeKind: ColumnTypeKind.enumType,
                enumType: EnumDescription(
                  schema: 'public',
                  name: 'string',
                  values: ["it's \$a\u2028trap", 'plain'],
                ),
              ),
              hasDefault: false,
            ),
          ],
          result: FunctionValueResult(
            ValueTypeDescription(
              postgresFormat: 'vector',
              typeKind: ColumnTypeKind.vector,
            ),
            isSetReturning: true,
          ),
        ),
      ],
    ),
    // A reserved word returning rows of its own shape, one column of a
    // shadowing enum.
    FunctionDescription(
      schema: 'public',
      name: 'class',
      overloads: [
        FunctionOverloadDescription(
          arguments: [],
          result: FunctionColumnsResult([
            ColumnDescription(
              name: 'string',
              postgresFormat: 'public.string',
              typeKind: ColumnTypeKind.enumType,
              enumType: EnumDescription(
                schema: 'public',
                name: 'string',
                values: ["it's \$a\u2028trap", 'plain'],
              ),
              isRequired: false,
              hasDefault: false,
              isNullable: true,
              isReadOnly: true,
            ),
          ]),
        ),
      ],
    ),
    // Returning rows of its own shape, named like a core type and a
    // generated table at once, and taking a row of that table.
    FunctionDescription(
      schema: 'public',
      name: 'map',
      overloads: [
        FunctionOverloadDescription(
          arguments: [
            FunctionArgumentDescription(
              name: 'map',
              type: ValueTypeDescription(
                postgresFormat: 'map',
                typeKind: ColumnTypeKind.unknown,
              ),
              hasDefault: false,
              rowOf: ('public', 'map'),
            ),
          ],
          result: FunctionColumnsResult([
            ColumnDescription(
              name: 'list',
              postgresFormat: '_float8',
              typeKind: ColumnTypeKind.array,
              elementTypeKind: ColumnTypeKind.floating,
              isRequired: false,
              hasDefault: false,
              isNullable: true,
              isReadOnly: true,
            ),
          ]),
        ),
      ],
    ),
    // Named like the schema-prefixed name of `private.restock`.
    FunctionDescription(
      schema: 'public',
      name: 'private_restock',
      overloads: [
        FunctionOverloadDescription(arguments: [], result: FunctionNoResult()),
      ],
    ),
    FunctionDescription(
      schema: 'private',
      name: 'restock',
      overloads: [
        FunctionOverloadDescription(arguments: [], result: FunctionNoResult()),
        // An overload spelling its arguments out, with a row of a table of
        // another schema and an unknown type.
        FunctionOverloadDescription(
          arguments: [
            FunctionArgumentDescription(
              name: 'item',
              type: ValueTypeDescription(
                postgresFormat: 'achievement_item_progress_tbl',
                typeKind: ColumnTypeKind.unknown,
              ),
              hasDefault: false,
              rowOf: ('private', 'achievement_item_progress_tbl'),
            ),
            FunctionArgumentDescription(
              name: 'note',
              type: ValueTypeDescription(
                postgresFormat: 'tsquery_custom',
                typeKind: ColumnTypeKind.unknown,
              ),
              hasDefault: true,
            ),
          ],
          result: FunctionTableRowsResult(
            schema: 'public',
            table: 'orders',
            isSetReturning: false,
          ),
        ),
      ],
    ),
    // A schema name with line terminators and quotes, in a method name, a
    // string literal and the note of an overload the generated code cannot
    // call.
    FunctionDescription(
      schema: 'evil\nmultiline "schema" name',
      name: 'it\'s',
      overloads: [
        FunctionOverloadDescription(
          arguments: [
            FunctionArgumentDescription(
              name: '',
              type: ValueTypeDescription(
                postgresFormat: 'text',
                typeKind: ColumnTypeKind.text,
              ),
              hasDefault: false,
            ),
          ],
          result: FunctionNoResult(),
        ),
        FunctionOverloadDescription(
          arguments: [
            FunctionArgumentDescription(
              name: 'at',
              type: ValueTypeDescription(
                postgresFormat: 'timestamp',
                typeKind: ColumnTypeKind.timestamp,
              ),
              hasDefault: false,
            ),
          ],
          result: FunctionTableRowsResult(
            schema: 'evil\nmultiline "schema" name',
            table: 'postgrest_column',
            isSetReturning: true,
          ),
        ),
      ],
    ),
  ],
  enums: [
    EnumDescription(
      schema: 'public',
      name: 'string',
      values: ["it's \$a\u2028trap", 'plain'],
    ),
    // Named like the core type the xid8 column of `map` decodes into.
    EnumDescription(
      schema: 'public',
      name: 'big_int',
      values: ['small', 'large'],
    ),
    EnumDescription(
      schema: 'public',
      name: 'статус',
      values: ['новый', 'готов'],
    ),
  ],
);
