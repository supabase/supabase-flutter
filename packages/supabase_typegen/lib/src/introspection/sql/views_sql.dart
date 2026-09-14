import 'helpers.dart';

/// `VIEWS_SQL` of `@supabase/postgrest-typegen`.
String viewsSql({required String schemaFilter}) =>
    '''

SELECT
  c.oid :: int8 AS id,
  n.nspname AS schema,
  c.relname AS name,
  -- See definition of information_schema.views
  (pg_relation_is_updatable(c.oid, false) & 20) = 20 AS is_updatable,
  -- Passing include_triggers => true also counts views made writable by
  -- INSTEAD OF triggers (and INSTEAD rules), which PostgREST can write
  -- through even when the view is not auto-updatable. Bit 8 is INSERT,
  -- bit 4 is UPDATE (see information_schema.views).
  (pg_relation_is_updatable(c.oid, true) & 8) = 8 AS is_insert_enabled,
  (pg_relation_is_updatable(c.oid, true) & 4) = 4 AS is_update_enabled,
  obj_description(c.oid) AS comment
FROM
  pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE
  ${when(schemaFilter, 'n.nspname $schemaFilter AND')}
  c.relkind = 'v'
''';
