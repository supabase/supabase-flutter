import 'queryable.dart';
import 'relationships.dart';
import 'sort.dart';
import 'sql/columns_sql.dart';
import 'sql/foreign_tables_sql.dart';
import 'sql/functions_sql.dart';
import 'sql/helpers.dart';
import 'sql/materialized_views_sql.dart';
import 'sql/primary_keys_sql.dart';
import 'sql/schemas_sql.dart';
import 'sql/table_relationships_sql.dart';
import 'sql/tables_sql.dart';
import 'sql/types_sql.dart';
import 'sql/views_key_dependencies_sql.dart';
import 'sql/views_sql.dart';
import 'supabase_cli_io.dart';

/// The supabase/sdk revision of `@supabase/postgrest-typegen` whose
/// introspection this library ports, a commit or a `postgrest-typegen-v*`
/// tag. `tool/check_introspection_drift.ts` compares the SQL of the port
/// against it and `tool/regenerate_fixture.ts` expects a checkout of it.
const postgrestTypegenRevision = 'postgrest-typegen-v0.2.2';

/// The `version` field of the emitted `GeneratorMetadata` document.
const generatorMetadataVersion = 1;

/// Introspects the database [target] through `supabase db query` and returns
/// the `GeneratorMetadata` document in canonical order, equal to
/// `sortGeneratorMetadata(await introspect(pool))` of
/// `@supabase/postgrest-typegen` at [postgrestTypegenRevision] up to the
/// order of keys within a record.
///
/// [includedSchemas] and [excludedSchemas] restrict the schemas whose
/// relations, columns, keys and functions are listed; the system schemas are
/// always left out and types are always listed for every schema.
///
/// Throws a [SupabaseCliException] when the Supabase CLI is missing, not
/// logged in, or cannot reach the database.
Future<Map<String, dynamic>> introspectDatabase(
  DatabaseTarget target, {
  List<String> includedSchemas = const [],
  List<String> excludedSchemas = const [],
}) async => sortGeneratorMetadata(
  await introspect(
    SupabaseCliQueryable(target),
    includedSchemas: includedSchemas,
    excludedSchemas: excludedSchemas,
  ),
);

/// Introspects the database behind [database] into the `GeneratorMetadata`
/// document, in query order. Apply [sortGeneratorMetadata] before generating
/// from it.
///
/// Port of `introspect` of `@supabase/postgrest-typegen`: the same queries
/// with the same option combination, issued as one [Queryable.query] call, so
/// the result holds the same records as the TypeScript output for the same
/// database.
Future<Map<String, dynamic>> introspect(
  Queryable database, {
  List<String> includedSchemas = const [],
  List<String> excludedSchemas = const [],
}) async {
  final systemExcludingFilter = filterByList(
    include: includedSchemas,
    exclude: excludedSchemas,
    defaultExclude: defaultSystemSchemas,
  );
  final plainFilter = filterByList(
    include: includedSchemas,
    exclude: excludedSchemas,
  );

  final results = await database.query({
    'schemas': schemasSql(schemaFilter: systemExcludingFilter),
    'tables': tablesSql(schemaFilter: systemExcludingFilter),
    'foreignTables': foreignTablesSql(schemaFilter: plainFilter),
    'views': viewsSql(schemaFilter: systemExcludingFilter),
    'materializedViews': materializedViewsSql(schemaFilter: plainFilter),
    'columns': columnsSql(schemaFilter: systemExcludingFilter),
    'primaryKeys': primaryKeysSql(schemaFilter: systemExcludingFilter),
    'tableRelationships': tableRelationshipsSql(
      schemaFilter: systemExcludingFilter,
    ),
    'viewsKeyDependencies': viewsKeyDependenciesSql(
      schemaFilter: systemExcludingFilter,
    ),
    'functions': functionsSql(schemaFilter: systemExcludingFilter),
    'types': typesSql,
  });
  List<Map<String, dynamic>> rows(String name) => results[name]!;

  final tableRelationships = rows('tableRelationships');
  final relationships = [
    ...tableRelationships,
    ...expandViewRelationships(
      tableRelationships,
      rows('viewsKeyDependencies'),
    ),
  ];

  return {
    'version': generatorMetadataVersion,
    'schemas': rows('schemas'),
    'tables': rows('tables'),
    'foreignTables': rows('foreignTables'),
    'views': rows('views'),
    'materializedViews': rows('materializedViews'),
    'columns': rows('columns'),
    'primaryKeys': rows('primaryKeys'),
    'relationships': relationships,
    'functions': [
      for (final function in rows('functions'))
        if (!const {
          'trigger',
          'event_trigger',
        }.contains(function['return_type']))
          function,
    ],
    'types': rows('types'),
  };
}
