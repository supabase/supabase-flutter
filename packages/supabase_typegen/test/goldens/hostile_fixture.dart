import 'package:supabase_typegen/supabase_typegen.dart';

/// A schema built from valid but pathological database names: identifiers
/// that shadow core and imported types, comments and values carrying every
/// line terminator and Dart string metacharacter, and array element kinds
/// with dedicated conversions.
///
/// The golden generated from it, `hostile_schema.dart`, is checked in so the
/// package's own `dart analyze` run proves the generated code stays valid,
/// not merely parseable, for schemas like these.
const SchemaDescription hostileSchema = SchemaDescription(
  schemaName: 'evil\nmultiline "schema" name',
  tables: [
    TableDescription(
      name: 'postgrest_table',
      comment: 'first\rsecond\u2028third \$interpolation "quoted"',
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
      ],
    ),
    TableDescription(
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
      ],
    ),
  ],
  enums: [
    EnumDescription(
      qualifiedName: 'public.string',
      values: ["it's \$a\u2028trap", 'plain'],
    ),
  ],
);
