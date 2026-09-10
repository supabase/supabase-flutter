import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  late MockSupabaseHttpClient httpClient;
  late PostgrestClient client;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stub([], path: '/t');
    client = PostgrestClient('http://localhost:3000', httpClient: httpClient);
  });

  test('escapes double quotes and backslashes in list filter values', () async {
    await client.from('t').select().inFilter('name', [r'a"b\c']);

    // The `"` and `\` are backslash-escaped so the element stays a single,
    // well-formed quoted value rather than `in.("a"b\c")`.
    expect(
      httpClient.requests.last.queryParameters['name'],
      r'in.("a\"b\\c")',
    );
  });

  test(
    'escapes double quotes and backslashes in negated list filter values',
    () async {
      await client.from('t').select().notInFilter('name', [r'a"b\c']);

      expect(
        httpClient.requests.last.queryParameters['name'],
        r'not.in.("a\"b\\c")',
      );
    },
  );

  test('does not quote numeric negated list filter values', () async {
    await client.from('t').select().notInFilter('id', [1, 2, 3]);

    expect(httpClient.requests.last.queryParameters['id'], 'not.in.(1,2,3)');
  });
}
