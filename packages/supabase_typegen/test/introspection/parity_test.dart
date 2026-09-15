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

  test('restricting the schemas to public yields the same document', () async {
    final document = await introspectDatabase(
      DatabaseUrl(_databaseUrl),
      includedSchemas: ['public'],
    );

    _expectSameDocument(document, fixture);
  });

  test('--dump-metadata writes a document with the fixture records', () async {
    final result = await _runBinary([
      '--db-url',
      _databaseUrl,
      '--dump-metadata',
    ]);

    expect(result.exitCode, 0, reason: result.stderr as String);
    _expectSameDocument(
      jsonDecode(result.stdout as String) as Map<String, dynamic>,
      fixture,
    );
  }, timeout: _compileTimeout);

  test('the binary generates the golden code from the database', () async {
    final result = await _runBinary([
      '--db-url',
      _databaseUrl,
      '--output',
      '-',
    ]);
    final golden = File('test/goldens/supabase_schema.dart').readAsStringSync();

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(_normalize(result.stdout as String), _normalize(golden));
    expect(
      result.stderr,
      contains(
        'Generated stdout with 6 tables and 1 enums from schema "public".',
      ),
    );
  }, timeout: _compileTimeout);
}

String _normalize(String code) => code.replaceAll(_whitespace, ' ').trim();

Future<ProcessResult> _runBinary(List<String> arguments) => Process.run(
  Platform.resolvedExecutable,
  ['run', 'bin/supabase_typegen.dart', ...arguments],
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
