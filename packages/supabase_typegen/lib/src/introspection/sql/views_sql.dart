import 'helpers.dart';

/// `VIEWS_SQL` of `@supabase/postgrest-typegen`.
String viewsSql({
  String schemaFilter = '',
  String idsFilter = '',
  String viewIdentifierFilter = '',
  int? limit,
  int? offset,
}) =>
    '''

SELECT
  c.oid :: int8 AS id,
  n.nspname AS schema,
  c.relname AS name,
  -- See definition of information_schema.views
  (pg_relation_is_updatable(c.oid, false) & 20) = 20 AS is_updatable,
  obj_description(c.oid) AS comment
FROM
  pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE
  ${when(schemaFilter, 'n.nspname $schemaFilter AND')}
  ${when(idsFilter, 'c.oid $idsFilter AND')}
  ${when(viewIdentifierFilter, "(n.nspname || '.' || c.relname) $viewIdentifierFilter AND")}
  c.relkind = 'v'
${limitOffset(limit, offset)}''';
