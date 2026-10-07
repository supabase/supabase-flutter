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

  test('escapes a comma in a likeAllOf pattern', () async {
    await client.from('t').select().likeAllOf('name', ['a,b']);

    // Unquoted, the comma would split the array literal into the two patterns
    // `a` and `b`, which no row matches under `all`.
    expect(
      httpClient.requests.last.queryParameters['name'],
      'like(all).{"a,b"}',
    );
  });

  test('escapes a backslash in a likeAnyOf pattern', () async {
    await client.from('t').select().likeAnyOf('name', [r'50\%']);

    // The array literal consumes the backslash, so unescaped this reaches LIKE
    // as `50%` and the pattern matches any string starting with 50 rather than
    // the literal `50%`.
    expect(
      httpClient.requests.last.queryParameters['name'],
      r'like(any).{"50\\%"}',
    );
  });

  test('escapes a double quote in an ilikeAllOf pattern', () async {
    await client.from('t').select().ilikeAllOf('name', [r'a"b']);

    expect(
      httpClient.requests.last.queryParameters['name'],
      r'ilike(all).{"a\"b"}',
    );
  });

  test('escapes a closing brace in an ilikeAnyOf pattern', () async {
    await client.from('t').select().ilikeAnyOf('name', ['a}b']);

    expect(
      httpClient.requests.last.queryParameters['name'],
      'ilike(any).{"a}b"}',
    );
  });

  test(
    'matches the array literal the not() spelling already produces',
    () async {
      await client.from('t').select().likeAllOf('name', ['a,b']);
      final direct = httpClient.requests.last.queryParameters['name'];

      await client.from('t').select().not('name', 'like(all)', ['a,b']);
      final negated = httpClient.requests.last.queryParameters['name'];

      expect(negated, 'not.$direct');
    },
  );

  group('rpc with get', () {
    setUp(() => httpClient.stub(null, path: '/rpc/f'));

    test('encodes array elements as a Postgres array literal', () async {
      await client.rpc<void>(
        'f',
        params: {
          'tags': [
            'Paris, France',
            'Oslo',
            'NULL',
            '',
            'a"b',
            null,
            ['x', 'y'],
          ],
        },
        get: true,
      );

      expect(
        httpClient.requests.last.queryParameters['tags'],
        r'{"Paris, France",Oslo,"NULL","","a\"b",NULL,{x,y}}',
      );
    });

    test('encodes a map as JSON', () async {
      await client.rpc<void>(
        'f',
        params: {
          'object': {'a': 1},
        },
        get: true,
      );

      expect(httpClient.requests.last.queryParameters['object'], '{"a":1}');
    });

    test('sends numeric arrays unquoted', () async {
      await client.rpc<void>(
        'f',
        params: {
          'numbers': [37, 420, 64],
        },
        get: true,
      );

      expect(
        httpClient.requests.last.queryParameters['numbers'],
        '{37,420,64}',
      );
    });
  });
}
