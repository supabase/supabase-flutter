import '../pg_format.dart';
import 'helpers.dart';

/// `VIEWS_KEY_DEPENDENCIES_SQL` of `@supabase/postgrest-typegen`.
String viewsKeyDependenciesSql({required String schemaFilter}) =>
    '''

-- Adapted from
-- https://github.com/PostgREST/postgrest/blob/f9f0f79fa914ac00c11fbf7f4c558e14821e67e2/src/PostgREST/SchemaCache.hs#L820
with recursive
pks_fks as (
  -- pk + fk referencing col
  select
    contype::text as contype,
    conname,
    array_length(conkey, 1) as ncol,
    conrelid as resorigtbl,
    col as resorigcol,
    ord
  from pg_constraint
  left join lateral unnest(conkey) with ordinality as _(col, ord) on true
  where contype IN ('p', 'f')
  union
  -- fk referenced col
  select
    concat(contype, '_ref') as contype,
    conname,
    array_length(confkey, 1) as ncol,
    confrelid,
    col,
    ord
  from pg_constraint
  left join lateral unnest(confkey) with ordinality as _(col, ord) on true
  where contype='f'
  ${when(schemaFilter, 'and connamespace::regnamespace::text $schemaFilter')}
),
views as (
  select
    c.oid       as view_id,
    n.nspname   as view_schema,
    c.relname   as view_name,
    r.ev_action as view_definition
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  join pg_rewrite r on r.ev_class = c.oid
  where c.relkind in ('v', 'm') 
    ${when(schemaFilter, 'and n.nspname $schemaFilter')}
),
transform_json as (
  select
    view_id, view_schema, view_name,
${nodeTreeToJson('view_definition::text')}::json as view_definition
  from views
),
target_entries as(
  select
    view_id, view_schema, view_name,
    json_array_elements(view_definition->0->'targetList') as entry
  from transform_json
),
results as(
  select
    view_id, view_schema, view_name,
    (entry->>'resno')::int as view_column,
    (entry->>'resorigtbl')::oid as resorigtbl,
    (entry->>'resorigcol')::int as resorigcol
  from target_entries
),
-- CYCLE detection according to PG docs: https://www.postgresql.org/docs/current/queries-with.html#QUERIES-WITH-CYCLE
-- Can be replaced with CYCLE clause once PG v13 is EOL.
recursion(view_id, view_schema, view_name, view_column, resorigtbl, resorigcol, is_cycle, path) as(
  select
    r.*,
    false,
    ARRAY[resorigtbl]
  from results r
  where ${schemaFilter.isEmpty ? 'true' : 'view_schema $schemaFilter'}
  union all
  select
    view.view_id,
    view.view_schema,
    view.view_name,
    view.view_column,
    tab.resorigtbl,
    tab.resorigcol,
    tab.resorigtbl = ANY(path),
    path || tab.resorigtbl
  from recursion view
  join results tab on view.resorigtbl=tab.view_id and view.resorigcol=tab.view_column
  where not is_cycle
),
repeated_references as(
  select
    view_id,
    view_schema,
    view_name,
    resorigtbl,
    resorigcol,
    array_agg(attname) as view_columns
  from recursion
  join pg_attribute vcol on vcol.attrelid = view_id and vcol.attnum = view_column
  group by
    view_id,
    view_schema,
    view_name,
    resorigtbl,
    resorigcol
)
select
  sch.nspname as table_schema,
  tbl.relname as table_name,
  rep.view_schema,
  rep.view_name,
  pks_fks.conname as constraint_name,
  pks_fks.contype as constraint_type,
  jsonb_agg(
    jsonb_build_object('table_column', col.attname, 'view_columns', view_columns) order by pks_fks.ord
  ) as column_dependencies
from repeated_references rep
join pks_fks using (resorigtbl, resorigcol)
join pg_class tbl on tbl.oid = rep.resorigtbl
join pg_attribute col on col.attrelid = tbl.oid and col.attnum = rep.resorigcol
join pg_namespace sch on sch.oid = tbl.relnamespace
group by sch.nspname, tbl.relname,  rep.view_schema, rep.view_name, pks_fks.conname, pks_fks.contype, pks_fks.ncol
-- make sure we only return key for which all columns are referenced in the view - no partial PKs or FKs
having ncol = array_length(array_agg(row(col.attname, view_columns) order by pks_fks.ord), 1)
''';

/// One text rewrite of the `pg_node_tree` to JSON conversion: a `replace`,
/// or a global `regexp_replace` when [isRegex] is set.
typedef NodeTreeRewrite = ({String pattern, String replacement, bool isRegex});

/// The rewrites, innermost first, that turn the `pg_node_tree` text of a view
/// definition into JSON exposing only `targetList`, `resno`, `resorigtbl`
/// and `resorigcol`, as `NODE_TREE_TO_JSON_REWRITES` of
/// `@supabase/postgrest-typegen` lists them; the order matters.
const List<NodeTreeRewrite> nodeTreeToJsonRewrites = [
  (pattern: '<>', replacement: '()', isRegex: false),
  (pattern: ',', replacement: '', isRegex: false),
  (pattern: r'\{', replacement: '', isRegex: false),
  (pattern: r'\}', replacement: '', isRegex: false),
  (pattern: ' :targetList ', replacement: ',"targetList":', isRegex: false),
  (pattern: ' :resno ', replacement: ',"resno":', isRegex: false),
  (pattern: ' :resorigtbl ', replacement: ',"resorigtbl":', isRegex: false),
  (pattern: ' :resorigcol ', replacement: ',"resorigcol":', isRegex: false),
  (pattern: '{', replacement: '{ :', isRegex: false),
  (pattern: '((', replacement: '{((', isRegex: false),
  (pattern: '({', replacement: '{({', isRegex: false),
  (pattern: ' :[^}{,]+', replacement: ',"":', isRegex: true),
  (pattern: ',"":}', replacement: '}', isRegex: false),
  (pattern: ',"":,', replacement: ',', isRegex: false),
  (pattern: '{(', replacement: '(', isRegex: false),
  (pattern: '{,', replacement: '{', isRegex: false),
  (pattern: '(', replacement: '[', isRegex: false),
  (pattern: ')', replacement: ']', isRegex: false),
  (pattern: ' ', replacement: ',', isRegex: false),
];

/// Renders [nodeTreeToJsonRewrites] applied to [expression] as nested SQL
/// calls, the opening calls stacked and each step's arguments on the line
/// that closes it, exactly as `nodeTreeToJson` of the TypeScript package.
String nodeTreeToJson(String expression) {
  final buffer = StringBuffer();
  for (final rewrite in nodeTreeToJsonRewrites.reversed) {
    buffer.writeln('    ${rewrite.isRegex ? 'regexp_replace' : 'replace'}(');
  }
  buffer.writeln('      $expression,');
  for (final (index, rewrite) in nodeTreeToJsonRewrites.indexed) {
    final flags = rewrite.isRegex ? ", 'g'" : '';
    final closing = index == nodeTreeToJsonRewrites.length - 1 ? ')' : '),';
    buffer.writeln(
      '      ${literal(rewrite.pattern)}, '
      '${literal(rewrite.replacement)}$flags$closing',
    );
  }
  return buffer.toString().trimRight();
}
