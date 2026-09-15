import 'helpers.dart';

/// `PRIMARY_KEYS_SQL` of `@supabase/postgrest-typegen`.
String primaryKeysSql({required String schemaFilter}) =>
    '''

SELECT
  c.oid :: int8 AS table_id,
  n.nspname AS schema,
  c.relname AS table_name,
  a.attname AS name
FROM
  pg_index i
  JOIN pg_class c ON i.indrelid = c.oid
  JOIN pg_namespace n ON c.relnamespace = n.oid
  JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(i.indkey)
WHERE
  ${when(schemaFilter, 'n.nspname $schemaFilter AND')}
  i.indisprimary
  AND c.relkind IN ('r', 'p')
  AND NOT pg_is_other_temp_schema(n.oid)
  AND (
    pg_has_role(c.relowner, 'USAGE')
    OR has_table_privilege(
      c.oid,
      'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER'
    )
    OR has_any_column_privilege(c.oid, 'SELECT, INSERT, UPDATE, REFERENCES')
  )
ORDER BY
  c.oid,
  array_position(i.indkey, a.attnum)
''';
