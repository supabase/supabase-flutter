import 'helpers.dart';

/// `MATERIALIZED_VIEWS_SQL` of `@supabase/postgrest-typegen`.
String materializedViewsSql({
  String schemaFilter = '',
  String idsFilter = '',
  String materializedViewIdentifierFilter = '',
  int? limit,
  int? offset,
}) =>
    '''

select
  c.oid::int8 as id,
  n.nspname as schema,
  c.relname as name,
  c.relispopulated as is_populated,
  obj_description(c.oid) as comment
from
  pg_class c
  join pg_namespace n on n.oid = c.relnamespace
where
  ${when(schemaFilter, 'n.nspname $schemaFilter AND')}
  ${when(idsFilter, 'c.oid $idsFilter AND')}
  ${when(materializedViewIdentifierFilter, "(n.nspname || '.' || c.relname) $materializedViewIdentifierFilter AND")}
  c.relkind = 'm'
${limitOffset(limit, offset)}''';
