import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:supabase_typegen/introspection.dart';
import 'package:test/test.dart';

/// Connection URL of a fresh `postgres:15` database, the way
/// `tool/regenerate_fixture.ts` starts one, with `sslmode=disable` since the
/// Supabase CLI requires TLS otherwise. The test seeds it with
/// `test/fixtures/seed.sql` on first use.
final _databaseUrl =
    Platform.environment['SUPABASE_TYPEGEN_PARITY_DATABASE_URL'] ?? '';

final _whitespace = RegExp(r'\s+');
final _headerVersion = RegExp(r'supabase_typegen \S+ from');

/// `dart run` compiles the binary from source on every invocation.
const _compileTimeout = Timeout(Duration(minutes: 3));

void main() {
  if (_databaseUrl.isEmpty) {
    test(
      'parity with @supabase/postgrest-typegen',
      () {},
      skip:
          'Set SUPABASE_TYPEGEN_PARITY_DATABASE_URL to a fresh postgres:15 '
          'database to run the parity tests; see the README.',
    );
    return;
  }

  late Map<String, dynamic> fixture;

  setUpAll(() async {
    fixture =
        jsonDecode(
              File(
                'test/fixtures/generator_metadata.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    await _seedIfEmpty(_databaseUrl);
  });

  test('the introspection equals the postgrest-typegen fixture', () async {
    final document = await introspectDatabase(DatabaseUrl(_databaseUrl));

    _expectSameDocument(document, fixture);
  });

  test('naming both schemas yields the same document', () async {
    final document = await introspectDatabase(
      DatabaseUrl(_databaseUrl),
      includedSchemas: ['inventory', 'public'],
    );

    _expectSameDocument(document, fixture);
  });

  test('restricting the schemas to public yields its records only', () async {
    final document = await introspectDatabase(
      DatabaseUrl(_databaseUrl),
      includedSchemas: ['public'],
    );

    _expectSameDocument(document, _restrictedToPublic(fixture));
  });

  test('--dump-metadata writes a document with the fixture records', () async {
    final result = await _runBinary([
      '--db-url',
      _databaseUrl,
      '--schema',
      'inventory,public',
      '--dump-metadata',
    ]);

    expect(result.exitCode, 0, reason: result.stderr as String);
    _expectSameDocument(
      jsonDecode(result.stdout as String) as Map<String, dynamic>,
      fixture,
    );
  }, timeout: _compileTimeout);

  test('the binary generates public alone without a configuration', () async {
    // The repository holds a supabase/config.toml above the package, so the
    // lookup is pointed at an empty directory to stand in for a project
    // without one; the default schema set is then public, the way
    // `supabase gen types` behaves.
    final workingDirectory = Directory.systemTemp.createTempSync(
      'supabase_typegen_no_config',
    );
    addTearDown(() => workingDirectory.deleteSync(recursive: true));
    final result = await _runBinary(
      [
        '--db-url',
        _databaseUrl,
        '--output',
        '-',
      ],
      environment: {'SUPABASE_WORKDIR': workingDirectory.path},
    );

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(result.stdout, contains('// Source schemas: public'));
    expect(result.stdout, contains('class Books {'));
    expect(result.stdout, isNot(contains('class InventoryStock {')));
    expect(
      result.stderr,
      contains(
        'Generated stdout with 6 tables and 1 enums from schema "public".',
      ),
    );
  }, timeout: _compileTimeout);

  test('the binary follows api.schemas of the repository configuration '
      'found above the package', () async {
    // supabase/config.toml at the repository root exposes public,
    // graphql_public and personal; the fixture database only has public and
    // inventory, so public alone is generated and, since nothing was named
    // on the command line, nothing is reported as missing.
    final result = await _runBinary([
      '--db-url',
      _databaseUrl,
      '--output',
      '-',
    ]);

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(result.stdout, contains('// Source schemas: public'));
    expect(result.stderr, isNot(contains('has no schema')));
  }, timeout: _compileTimeout);

  test('the binary follows api.schemas of supabase/config.toml', () async {
    final workingDirectory = Directory.systemTemp.createTempSync(
      'supabase_typegen_config',
    );
    addTearDown(() => workingDirectory.deleteSync(recursive: true));
    File('${workingDirectory.path}/supabase/config.toml')
      ..createSync(recursive: true)
      ..writeAsStringSync('[api]\nschemas = ["public", "inventory"]\n');

    final result = await _runBinary(
      [
        '--db-url',
        _databaseUrl,
        '--output',
        '-',
      ],
      environment: {'SUPABASE_WORKDIR': workingDirectory.path},
    );
    final golden = File('test/goldens/supabase_schema.dart').readAsStringSync();

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(_normalize(result.stdout as String), _normalize(golden));
  }, timeout: _compileTimeout);

  test('the binary warns about a named schema the database lacks', () async {
    final result = await _runBinary([
      '--db-url',
      _databaseUrl,
      '--schema',
      'public,missing',
      '--output',
      '-',
    ]);

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(result.stdout, contains('// Source schemas: public'));
    expect(result.stderr, contains('The database has no schema "missing".'));
  }, timeout: _compileTimeout);

  test('the binary generates the golden code from the database', () async {
    final result = await _runBinary([
      '--db-url',
      _databaseUrl,
      '--schema',
      'inventory,public',
      '--output',
      '-',
    ]);
    final golden = File('test/goldens/supabase_schema.dart').readAsStringSync();

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(_normalize(result.stdout as String), _normalize(golden));
    expect(
      result.stderr,
      contains(
        'Generated stdout with 8 tables and 2 enums from schemas '
        '"inventory", "public".',
      ),
    );
  }, timeout: _compileTimeout);

  test('--schema takes repeated and comma separated names alike', () async {
    final repeated = await _runBinary([
      '--db-url',
      _databaseUrl,
      '--schema',
      'inventory',
      '--schema',
      'public',
      '--output',
      '-',
    ]);
    final commaSeparated = await _runBinary([
      '--db-url',
      _databaseUrl,
      '--schema',
      'inventory,public',
      '--output',
      '-',
    ]);
    final golden = File('test/goldens/supabase_schema.dart').readAsStringSync();

    expect(repeated.exitCode, 0, reason: repeated.stderr as String);
    expect(commaSeparated.exitCode, 0, reason: commaSeparated.stderr as String);
    expect(_normalize(repeated.stdout as String), _normalize(golden));
    expect(_normalize(commaSeparated.stdout as String), _normalize(golden));
  }, timeout: _compileTimeout);

  test('the binary restricts the generated schemas to --schema', () async {
    final result = await _runBinary([
      '--db-url',
      _databaseUrl,
      '--schema',
      'inventory',
      '--output',
      '-',
    ]);

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(result.stdout, contains('// Source schemas: inventory'));
    expect(result.stdout, contains('class InventoryStock {'));
    expect(result.stdout, isNot(contains('class Authors {')));
    expect(
      result.stderr,
      contains(
        'Generated stdout with 2 tables and 1 enums from schema "inventory".',
      ),
    );
  }, timeout: _compileTimeout);
}

/// The fixture as the introspection of `public` alone reports it: the
/// records of the schema-bearing collections that belong to `public`, with
/// `types` untouched since types are listed for every schema.
Map<String, dynamic> _restrictedToPublic(Map<String, dynamic> fixture) => {
  for (final MapEntry(:key, :value) in fixture.entries)
    key: value is List<dynamic> && key != 'types'
        ? [
            for (final record in value.cast<Map<String, dynamic>>())
              if ((record['schema'] ?? record['name']) == 'public' &&
                  (record['referenced_schema'] ?? 'public') == 'public')
                record,
          ]
        : value,
};

String _normalize(String code) => code
    .replaceAll(_whitespace, ' ')
    .replaceFirst(_headerVersion, 'supabase_typegen <version> from')
    .trim();

Future<ProcessResult> _runBinary(
  List<String> arguments, {
  Map<String, String>? environment,
}) => Process.run(
  Platform.resolvedExecutable,
  ['run', 'bin/supabase_typegen.dart', ...arguments],
  environment: environment,
);

/// Compares collection by collection so a mismatch names the record that
/// differs instead of dumping two documents. Records are maps, so the order
/// of their keys does not matter; the order of records within a collection
/// does, since the document is sorted.
void _expectSameDocument(
  Map<String, dynamic> document,
  Map<String, dynamic> fixture,
) {
  expect(document.keys, fixture.keys);
  for (final collection in fixture.keys) {
    final actual = document[collection];
    final expected = fixture[collection];
    if (expected is! List<dynamic>) {
      expect(actual, expected, reason: collection);
      continue;
    }
    expect(
      (actual as List<dynamic>).length,
      expected.length,
      reason: '$collection has a different number of records',
    );
    for (var i = 0; i < expected.length; i++) {
      expect(
        actual[i],
        expected[i],
        reason:
            '$collection[$i] differs. The fixture was generated on a fresh '
            'postgres:15 database, so the object ids only match when the '
            'database under test was seeded fresh as well.',
      );
    }
  }
}

Future<void> _seedIfEmpty(String databaseUrl) async {
  final connection = await Connection.openFromUrl(
    databaseUrl.contains('sslmode=')
        ? databaseUrl
        : '$databaseUrl${databaseUrl.contains('?') ? '&' : '?'}sslmode=disable',
  );
  try {
    final existing = await connection.execute(
      "select to_regclass('public.books') is not null",
    );
    if (existing.first.first == true) return;
    await connection.execute(
      Sql(File('test/fixtures/seed.sql').readAsStringSync()),
      queryMode: QueryMode.simple,
    );
  } finally {
    await connection.close();
  }
}
