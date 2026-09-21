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
    expect(request.queryParameters['order'], 'username.asc.nullslast');
    expect(request.queryParameters['limit'], '1');
    expect(request.headers['Prefer'], 'return=representation');
  });
}
