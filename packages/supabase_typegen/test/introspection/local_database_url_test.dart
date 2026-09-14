import 'package:supabase_typegen/introspection.dart';
import 'package:test/test.dart';

void main() {
  group('databaseUrlFromStatusEnv', () {
    test('extracts the quoted DB_URL line', () {
      const output = '''
ANON_KEY="eyJ..."
API_URL="http://127.0.0.1:54321"
DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
GRAPHQL_URL="http://127.0.0.1:54321/graphql/v1"
''';

      expect(
        databaseUrlFromStatusEnv(output),
        'postgresql://postgres:postgres@127.0.0.1:54322/postgres',
      );
    });

    test('accepts an unquoted value', () {
      expect(
        databaseUrlFromStatusEnv(
          'DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres\n',
        ),
        'postgresql://postgres:postgres@127.0.0.1:54322/postgres',
      );
    });

    test('returns null when the line is missing', () {
      expect(
        databaseUrlFromStatusEnv('API_URL="http://127.0.0.1:54321"'),
        isNull,
      );
      expect(databaseUrlFromStatusEnv(''), isNull);
    });
  });
}
