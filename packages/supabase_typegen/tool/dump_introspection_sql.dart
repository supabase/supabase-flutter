import 'dart:convert';

import 'package:supabase_typegen/introspection.dart';
import 'package:supabase_typegen/src/introspection/sql/columns_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/foreign_tables_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/functions_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/helpers.dart';
import 'package:supabase_typegen/src/introspection/sql/materialized_views_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/primary_keys_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/schemas_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/table_relationships_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/tables_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/types_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/views_key_dependencies_sql.dart';
import 'package:supabase_typegen/src/introspection/sql/views_sql.dart';

/// Prints, as JSON, the SQL the Dart port renders for the schema filters
/// `tool/check_introspection_drift.ts` compares against the TypeScript
/// builders, keyed by scenario and query name.
void main() {
  const scenarios =
      <String, ({List<String>? included, List<String>? excluded})>{
        'unfiltered': (included: null, excluded: null),
        'included': (included: ['public', "it's"], excluded: null),
        'excluded': (included: null, excluded: ['graphql', 'extensions']),
      };

  print(
    jsonEncode({
      'version': postgrestTypegenVersion,
      'queries': {
        for (final MapEntry(key: scenario, value: filter) in scenarios.entries)
          scenario: _queries(
            included: filter.included,
            excluded: filter.excluded,
          ),
      },
    }),
  );
}

Map<String, String> _queries({
  required List<String>? included,
  required List<String>? excluded,
}) {
  final systemExcludingFilter = filterByList(
    include: included,
    exclude: excluded,
    defaultExclude: defaultSystemSchemas,
  );
  final plainFilter = filterByList(include: included, exclude: excluded);
  return {
    'schemas': schemasSql(nameFilter: systemExcludingFilter),
    'tables': tablesSql(schemaFilter: systemExcludingFilter),
    'foreign_tables': foreignTablesSql(schemaFilter: plainFilter),
    'views': viewsSql(schemaFilter: systemExcludingFilter),
    'materialized_views': materializedViewsSql(schemaFilter: plainFilter),
    'columns': columnsSql(schemaFilter: systemExcludingFilter),
    'primary_keys': primaryKeysSql(schemaFilter: systemExcludingFilter),
    'table_relationships': tableRelationshipsSql(
      schemaFilter: systemExcludingFilter,
    ),
    'views_key_dependencies': viewsKeyDependenciesSql(
      schemaFilter: systemExcludingFilter,
    ),
    'functions': functionsSql(schemaFilter: systemExcludingFilter),
    'types': typesSql(includeTableTypes: true, includeArrayTypes: true),
  };
}
