import 'package:supabase_typegen/src/introspection/sql/columns_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/functions_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/helpers.dart';
import 'package:supabase_typegen/src/introspection/sql/schemas_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/table_relationships_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/types_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/views_key_dependencies_sql.dart';
import 'package:test/test.dart';

void main() {
  group('filterByList', () {
    test('produces a NOT IN clause for the default system schemas', () {
      expect(
        filterByList(defaultExclude: defaultSystemSchemas),
        "NOT IN ('information_schema','pg_catalog','pg_toast')",
      );
    });

    test('produces an IN clause for included schemas', () {
      expect(
        filterByList(
          include: ['public', 'api'],
          defaultExclude: defaultSystemSchemas,
        ),
        "IN ('public','api')",
      );
    });

    test('prepends the default exclusions to the excluded schemas', () {
      expect(
        filterByList(
          exclude: ['graphql'],
          defaultExclude: defaultSystemSchemas,
        ),
        "NOT IN ('information_schema','pg_catalog','pg_toast','graphql')",
      );
    });

    test('quotes schema names', () {
      expect(filterByList(include: ["it's"]), "IN ('it''s')");
    });

    test('returns the empty string when there is nothing to filter', () {
      expect(filterByList(), '');
      expect(filterByList(include: [], exclude: []), '');
    });
  });

  final schemaFilter = filterByList(defaultExclude: defaultSystemSchemas);

  group('SQL builders', () {
    test('render the schemas query of the generator path', () {
      expect(schemasSql(schemaFilter: schemaFilter), '''

-- Adapted from information_schema.schemata
select
  n.oid::int8 as id,
  n.nspname as name,
  u.rolname as owner
from
  pg_namespace n,
  pg_roles u
where
  n.nspowner = u.oid
  and n.nspname NOT IN ('information_schema','pg_catalog','pg_toast')
  and not pg_catalog.starts_with(n.nspname, 'pg_')
  and (
    pg_has_role(n.nspowner, 'USAGE')
    or has_schema_privilege(n.oid, 'CREATE, USAGE')
  )
  and not pg_catalog.starts_with(n.nspname, 'pg_temp_')
  and not pg_catalog.starts_with(n.nspname, 'pg_toast_temp_')
''');
    });

    test('leave the filter line blank when no filter is set', () {
      final sql = columnsSql(schemaFilter: '');
      expect(sql, isNot(contains('nc.nspname NOT IN')));
      expect(sql, contains('WHERE\n  \n  NOT pg_is_other_temp_schema'));
    });

    test('interpolate the schema filter into every clause', () {
      expect(
        columnsSql(schemaFilter: schemaFilter),
        contains(
          'nc.nspname NOT IN '
          "('information_schema','pg_catalog','pg_toast') AND",
        ),
      );
      expect(
        tableRelationshipsSql(schemaFilter: schemaFilter),
        allOf(
          contains(
            'and connamespace::regnamespace::text NOT IN '
            "('information_schema','pg_catalog','pg_toast')",
          ),
          contains(
            'WHERE traint.connamespace::regnamespace::text NOT IN '
            "('information_schema','pg_catalog','pg_toast')",
          ),
          contains(
            'and ns1.nspname NOT IN '
            "('information_schema','pg_catalog','pg_toast')",
          ),
        ),
      );
      expect(
        viewsKeyDependenciesSql(schemaFilter: schemaFilter),
        contains(
          'where view_schema NOT IN '
          "('information_schema','pg_catalog','pg_toast')",
        ),
      );
    });

    test('fall back to true where an unfiltered clause needs a predicate', () {
      expect(
        tableRelationshipsSql(schemaFilter: ''),
        contains('WHERE true\n'),
      );
      expect(
        viewsKeyDependenciesSql(schemaFilter: ''),
        contains('where true\n'),
      );
    });

    test('only join pg_namespace in the functions query when filtering', () {
      expect(
        functionsSql(schemaFilter: schemaFilter),
        contains('join pg_namespace n on p.pronamespace = n.oid'),
      );
      expect(
        functionsSql(schemaFilter: ''),
        isNot(contains('join pg_namespace n on p.pronamespace = n.oid')),
      );
    });

    test('list every type including table row types and array types', () {
      expect(typesSql, contains("c.relkind in ('c', 'r', 'v', 'm', 'p', 'f')"));
      expect(typesSql, isNot(contains('and not exists')));
      expect(typesSql, isNot(contains('and n.nspname')));
    });

    test('render the view definition rewrites as nested calls', () {
      final sql = viewsKeyDependenciesSql(schemaFilter: '');
      expect(sql, contains('    regexp_replace(\n'));
      expect(
        sql,
        contains("      view_definition::text,\n      '<>', '()'),\n"),
      );
      expect(sql, contains("      ' :[^}{,]+', ',\"\":', 'g'),\n"));
      expect(sql, contains("      ' ', ',')::json as view_definition\n"));
      expect(nodeTreeToJsonRewrites, hasLength(19));
      expect(nodeTreeToJson('x'), contains(r"E'\\{', ''"));
    });
  });
}
