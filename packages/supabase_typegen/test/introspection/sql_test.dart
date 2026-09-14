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
      expect(schemasSql(nameFilter: schemaFilter), '''

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

    test('leave the filter lines blank when no filter is set', () {
      final sql = columnsSql();
      expect(sql, isNot(contains('nc.nspname NOT IN')));
      expect(
        sql,
        contains('WHERE\n  \n  \n  \n  \n  \n  NOT pg_is_other_temp_schema'),
      );
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
      expect(tableRelationshipsSql(), contains('WHERE true\n'));
      expect(viewsKeyDependenciesSql(), contains('where true\n'));
    });

    test('only join pg_namespace in the functions query when filtering', () {
      expect(
        functionsSql(schemaFilter: schemaFilter),
        contains('join pg_namespace n on p.pronamespace = n.oid'),
      );
      expect(
        functionsSql(),
        isNot(contains('join pg_namespace n on p.pronamespace = n.oid')),
      );
    });

    test('render the types query with table and array types included', () {
      final sql = typesSql(includeTableTypes: true, includeArrayTypes: true);
      expect(sql, contains("c.relkind in ('c', 'r', 'v', 'm', 'p')"));
      expect(sql, isNot(contains('and not exists')));
      expect(
        typesSql(),
        allOf(contains("c.relkind = 'c'"), contains('and not exists')),
      );
    });
  });
}
