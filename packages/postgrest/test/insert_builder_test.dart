import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

/// An insert has no existing rows to filter, it only returns the rows it
/// creates, so `insert()` and `upsert()` do not expose the filter methods.
void main() {
  late MockSupabaseHttpClient httpClient;
  late PostgrestClient postgrest;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stub(null);
    postgrest = PostgrestClient(
      'http://localhost/rest/v1',
      httpClient: httpClient,
    );
  });

  tearDown(() async {
    await postgrest.dispose();
  });

  test('insert() returns a builder without filters', () {
    final builder = postgrest.from('users').insert({'username': 'foo'});

    expect(builder, isA<PostgrestTransformBuilder<void>>());
    expect(builder, isNot(isA<PostgrestFilterBuilder<void>>()));
  });

  test('upsert() returns a builder without filters', () {
    final builder = postgrest.from('users').upsert({'username': 'foo'});

    expect(builder, isA<PostgrestTransformBuilder<void>>());
    expect(builder, isNot(isA<PostgrestFilterBuilder<void>>()));
  });

  test('update() and delete() keep their filters', () {
    expect(
      postgrest.from('users').update({'status': 'OFFLINE'}),
      isA<PostgrestFilterBuilder<void>>(),
    );
    expect(
      postgrest.from('users').delete(),
      isA<PostgrestFilterBuilder<void>>(),
    );
  });

  test('insert() still shapes the rows it returns', () async {
    httpClient.stub([]);

    await postgrest
        .from('users')
        .insert([
          {'username': 'foo'},
          {'username': 'bar'},
        ])
        .select('username')
        .order('username')
        .limit(1);

    final request = httpClient.requests.last;
    expect(request.method, HttpMethod.post.value);
    expect(request.queryParameters['select'], 'username');
    expect(request.queryParameters['order'], 'username.asc');
    expect(request.queryParameters['limit'], '1');
    expect(request.headers['Prefer'], 'return=representation');
  });

  for (final (name, write) in [
    (
      'insert()',
      (PostgrestQueryBuilder table, List<Object?> rows) => table.insert(rows),
    ),
    (
      'upsert()',
      (PostgrestQueryBuilder table, List<Object?> rows) => table.upsert(rows),
    ),
  ]) {
    test('$name sends rows given as Map<dynamic, dynamic> and '
        'Map<String, Object?>', () async {
      await write(postgrest.from('users'), [
        <dynamic, dynamic>{'username': 'foo'},
        <String, Object?>{'username': 'bar', 'status': 'ONLINE'},
      ]);

      final request = httpClient.requests.last;
      expect(
        request.body,
        '[{"username":"foo"},{"username":"bar","status":"ONLINE"}]',
      );
      expect(request.queryParameters['columns'], '"username","status"');
    });

    test('$name of a row with a non-String key throws', () {
      expect(
        () => write(postgrest.from('users'), [
          <dynamic, dynamic>{1: 'foo'},
        ]),
        throwsArgumentError,
      );
    });
  }
}
