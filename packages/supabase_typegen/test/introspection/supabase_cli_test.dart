import 'dart:convert';
import 'dart:io';

import 'package:supabase_typegen/introspection.dart';
import 'package:test/test.dart';

void main() {
  group('combineQueries', () {
    test('aggregates every query into one select', () {
      final sql = combineQueries({
        'schemas': 'select 1 as id',
        'tables': 'with t as (select 2 as id) select id from t',
      });

      expect(sql, '''
select
  (select coalesce(json_agg(t), '[]'::json) from (
select 1 as id
  ) t) as "schemas",
  (select coalesce(json_agg(t), '[]'::json) from (
with t as (select 2 as id) select id from t
  ) t) as "tables"''');
    });
  });

  group('describeFailure', () {
    test('explains a missing login', () {
      expect(
        describeFailure(
          'Access token not provided. Supply an access token by running '
          '`supabase login` or setting the SUPABASE_ACCESS_TOKEN environment '
          'variable.\nTry rerunning the command with --debug.',
        ),
        allOf(contains('not logged in'), contains('supabase login')),
      );
    });

    test('explains a missing link', () {
      expect(
        describeFailure('Cannot find project ref. Have you run supabase link?'),
        allOf(contains('supabase link'), contains('--project-ref')),
      );
    });

    test('passes other failures through without the progress line', () {
      expect(
        describeFailure(
          'Connecting to local database...\n'
          'failed to connect to postgres: ECONNREFUSED\n',
        ),
        'supabase db query failed:\n'
        'failed to connect to postgres: ECONNREFUSED',
      );
    });
  });

  group('SupabaseCliQueryable', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('supabase_cli_test_');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    File fakeCli(String script) {
      final file = File('${directory.path}/supabase')
        ..writeAsStringSync('#!/bin/sh\n$script\n');
      Process.runSync('chmod', ['+x', file.path]);
      return file;
    }

    test('reports a CLI that is not installed', () {
      const database = SupabaseCliQueryable(
        LocalDatabase(),
        executable: 'supabase-typegen-missing-binary',
      );

      expect(
        () => database.query({'schemas': 'select 1'}),
        throwsA(
          isA<SupabaseCliException>().having(
            (error) => error.message,
            'message',
            contains('not found on PATH'),
          ),
        ),
      );
    });

    test('reports a CLI that is not logged in', () {
      final cli = fakeCli(
        r'printf "\033[31mAccess token not provided. Supply an access token '
        r'by running `supabase login`\033[39m\n" >&2; exit 1',
      );
      final database = SupabaseCliQueryable(
        const LinkedProject(),
        executable: cli.path,
      );

      expect(
        () => database.query({'schemas': 'select 1'}),
        throwsA(
          isA<SupabaseCliException>().having(
            (error) => error.message,
            'message',
            contains('supabase login'),
          ),
        ),
      );
    });

    test('passes the target flags and reads the rows of each query', () async {
      final cli = fakeCli(
        'echo "\$@" > "${directory.path}/arguments"\n'
        'cat "\$9" > "${directory.path}/statement"\n'
        'echo \'{"rows":[{"schemas":[{"id":1,"name":"public"}],'
        '"tables":[]}],"warning":null}\'',
      );
      final database = SupabaseCliQueryable(
        const LinkedProject(projectRef: 'abcdefghijklmnopqrst'),
        executable: cli.path,
      );

      final rows = await database.query({
        'schemas': 'select 1 as id',
        'tables': 'select 2 as id',
      });

      expect(rows, {
        'schemas': [
          {'id': 1, 'name': 'public'},
        ],
        'tables': <Map<String, dynamic>>[],
      });
      final arguments = File(
        '${directory.path}/arguments',
      ).readAsStringSync().trim().split(' ');
      expect(arguments.sublist(0, 7), [
        'db',
        'query',
        '--linked',
        '--project-ref',
        'abcdefghijklmnopqrst',
        '--output',
        'json',
      ]);
      expect(arguments[7], '--file');
      expect(
        File('${directory.path}/statement').readAsStringSync(),
        contains('as "schemas"'),
      );
    });

    test('reads rows printed as a bare array by older CLI releases', () async {
      final cli = fakeCli(
        'echo \'[{"schemas":[{"id":1,"name":"public"}]}]\'',
      );
      final database = SupabaseCliQueryable(
        const LocalDatabase(),
        executable: cli.path,
      );

      expect(await database.query({'schemas': 'select 1 as id'}), {
        'schemas': [
          {'id': 1, 'name': 'public'},
        ],
      });
    });

    test('rejects an unexpected result shape', () {
      final cli = fakeCli('echo \'{"rows":[]}\'');
      final database = SupabaseCliQueryable(
        const LocalDatabase(),
        executable: cli.path,
      );

      expect(
        () => database.query({'schemas': 'select 1'}),
        throwsA(
          isA<SupabaseCliException>().having(
            (error) => error.message,
            'message',
            contains('unexpected result shape'),
          ),
        ),
      );
    });

    test('rejects output that is not JSON', () {
      final cli = fakeCli('echo "Connecting to local database..."');
      final database = SupabaseCliQueryable(
        const LocalDatabase(),
        executable: cli.path,
      );

      expect(
        () => database.query({'schemas': 'select 1'}),
        throwsA(
          isA<SupabaseCliException>().having(
            (error) => error.message,
            'message',
            contains('did not return JSON'),
          ),
        ),
      );
    });

    test('renders the target flags', () {
      expect(const LocalDatabase().arguments, ['--local']);
      expect(const LinkedProject().arguments, ['--linked']);
      expect(const DatabaseUrl('postgresql://x').arguments, [
        '--db-url',
        'postgresql://x',
      ]);
      expect(jsonEncode(const LinkedProject(projectRef: 'r').arguments), '''
["--linked","--project-ref","r"]''');
    });
  });
}
