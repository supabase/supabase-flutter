import 'helpers.dart';

/// `FOREIGN_TABLES_SQL` of `@supabase/postgrest-typegen`.
String foreignTablesSql({
  String schemaFilter = '',
  String idsFilter = '',
  String tableIdentifierFilter = '',
  int? limit,
  int? offset,
}) =>
    '''

SELECT
  c.oid :: int8 AS id,
  n.nspname AS schema,
  c.relname AS name,
  obj_description(c.oid) AS comment
FROM
  pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE
  ${when(schemaFilter, 'n.nspname $schemaFilter AND')}
  ${when(idsFilter, 'c.oid $idsFilter AND')}
  ${when(tableIdentifierFilter, "(n.nspname || '.' || c.relname) $tableIdentifierFilter AND")}
  c.relkind = 'f'
${limitOffset(limit, offset)}''';
