import 'package:postgres/postgres.dart';

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
import 'sql/tables_sql.dart';
import 'sql/types_sql.dart';
import 'sql/views_sql.dart';
import 'ssl_probe_io.dart';

/// The release of `@supabase/postgrest-typegen` whose introspection this
/// library ports. `tool/check_introspection_drift.ts` compares the SQL of the
/// port against this release.
const postgrestTypegenVersion = '0.2.0';

/// The `version` field of the emitted `GeneratorMetadata` document.
const generatorMetadataVersion = 1;

/// Connects to the Postgres database at [connectionUrl], introspects it and
/// returns the `GeneratorMetadata` document in canonical order, equal to
/// `sortGeneratorMetadata(await introspect(pool))` of
/// `@supabase/postgrest-typegen` [postgrestTypegenVersion].
///
/// [connectionUrl] is a `postgresql://` URL. Its `sslmode` parameter is
/// honoured the way `package:postgres` supports it: `disable`, `require`,
/// `verify-ca` and `verify-full`. Without one the connection behaves like
/// libpq's `prefer`: TLS is attempted first and a server that does not offer
/// it is connected to in plaintext.
///
/// [includedSchemas] and [excludedSchemas] restrict the schemas whose
/// relations, columns, keys and functions are listed; the system schemas are
/// always left out and types are always listed for every schema.
Future<Map<String, dynamic>> introspectDatabase(
  String connectionUrl, {
  List<String> includedSchemas = const [],
  List<String> excludedSchemas = const [],
}) async {
  final connection = await _connect(connectionUrl);
  try {
    return sortGeneratorMetadata(
      await introspect(
        SessionQueryable(connection),
        includedSchemas: includedSchemas,
        excludedSchemas: excludedSchemas,
      ),
    );
  } finally {
    await connection.close();
  }
}

Future<Connection> _connect(String connectionUrl) async {
  final uri = Uri.parse(connectionUrl);
  if (uri.queryParameters.containsKey('sslmode') || uri.host.isEmpty) {
    return Connection.openFromUrl(connectionUrl);
  }
  final port = uri.port != 0
      ? uri.port
      : (int.tryParse(uri.queryParameters['port'] ?? '') ?? 5432);
  final sslMode = (await serverSupportsSsl(uri.host, port))
      ? 'require'
      : 'disable';
  return Connection.openFromUrl(
    uri
        .replace(queryParameters: {...uri.queryParameters, 'sslmode': sslMode})
        .toString(),
  );
}

/// Introspects the database behind [database] into the `GeneratorMetadata`
/// document, in query order. Apply [sortGeneratorMetadata] before generating
/// from it.
///
/// Port of `introspect` of `@supabase/postgrest-typegen`: the same queries
/// with the same option combination, so the result is identical to the
/// TypeScript output for the same database.
Future<Map<String, dynamic>> introspect(
  Queryable database, {
  List<String> includedSchemas = const [],
  List<String> excludedSchemas = const [],
}) async {
  final included = includedSchemas.isEmpty ? null : includedSchemas;
  final excluded = excludedSchemas.isEmpty ? null : excludedSchemas;

  final systemExcludingFilter = filterByList(
    include: included,
    exclude: excluded,
    defaultExclude: defaultSystemSchemas,
  );
  final plainFilter = filterByList(include: included, exclude: excluded);

  final schemas = await database.query(
    schemasSql(nameFilter: systemExcludingFilter),
  );
  final tables = await database.query(
    tablesSql(schemaFilter: systemExcludingFilter),
  );
  final foreignTables = await database.query(
    foreignTablesSql(schemaFilter: plainFilter),
  );
  final views = await database.query(
    viewsSql(schemaFilter: systemExcludingFilter),
  );
  final materializedViews = await database.query(
    materializedViewsSql(schemaFilter: plainFilter),
  );
  final columns = await database.query(
    columnsSql(schemaFilter: systemExcludingFilter),
  );
  final primaryKeys = await database.query(
    primaryKeysSql(schemaFilter: systemExcludingFilter),
  );
  final relationships = await listRelationships(
    database,
    includedSchemas: included,
    excludedSchemas: excluded,
  );
  final functions = await database.query(
    functionsSql(schemaFilter: systemExcludingFilter),
  );
  final types = await database.query(
    typesSql(includeTableTypes: true, includeArrayTypes: true),
  );

  return {
    'version': generatorMetadataVersion,
    'schemas': [
      for (final schema in schemas)
        if (!excludedSchemas.contains(schema['name']) &&
            (includedSchemas.isEmpty ||
                includedSchemas.contains(schema['name'])))
          schema,
    ],
    'tables': tables,
    'foreignTables': foreignTables,
    'views': views,
    'materializedViews': materializedViews,
    'columns': columns,
    'primaryKeys': primaryKeys,
    'relationships': relationships,
    'functions': [
      for (final function in functions)
        if (!const {
          'trigger',
          'event_trigger',
        }.contains(function['return_type']))
          function,
    ],
    'types': types,
  };
}
