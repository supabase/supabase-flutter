import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  test('testSupabaseClient constructs without further configuration', () async {
    final supabase = testSupabaseClient();
    addTearDown(supabase.dispose);

    expect(supabase.auth.currentSession, isNull);
  });

  test('a signed-out request carries a publishable key', () async {
    final httpClient = MockSupabaseHttpClient()
      ..stubTable('todos', rows: [])
      ..stubEdgeFunction('hello');
    final supabase = testSupabaseClient(httpClient: httpClient);
    addTearDown(supabase.dispose);

    await supabase.from('todos').select();
    await supabase.functions.invoke('hello');

    final [rest, function] = httpClient.requests;
    final key = rest.headers['apikey'];
    expect(key, startsWith('sb_publishable_'));
    expect(rest.headers['Authorization'], 'Bearer $key');
    expect(function.headers['apikey'], key);
    expect(function.headers['Authorization'], isNull);
  });

  test('a custom publishable key is passed through', () async {
    final httpClient = MockSupabaseHttpClient()..stubTable('todos', rows: []);
    final supabase = testSupabaseClient(
      httpClient: httpClient,
      publishableKey: 'sb_publishable_custom',
    );
    addTearDown(supabase.dispose);

    await supabase.from('todos').select();

    expect(
      httpClient.requests.single.headers['apikey'],
      'sb_publishable_custom',
    );
  });

  test('a realtime transport is wired into the client', () async {
    final urls = <String>[];
    final supabase = testSupabaseClient(
      realtimeTransport: (url, headers) {
        urls.add(url);
        throw StateError('no socket in this test');
      },
    );
    addTearDown(supabase.dispose);

    supabase.channel('room').subscribe();
    await pumpEventQueue();

    expect(urls.single, startsWith('ws://localhost:54321/realtime/v1'));
  });

  group('signInTestUser', () {
    late MockSupabaseHttpClient httpClient;
    late SupabaseClient supabase;

    setUp(() {
      httpClient = MockSupabaseHttpClient();
      supabase = testSupabaseClient(httpClient: httpClient);
      addTearDown(supabase.dispose);
    });

    test('signs the client in without network traffic', () async {
      final session = await signInTestUser(supabase.auth);

      expect(httpClient.requests, isEmpty);
      expect(supabase.auth.currentSession, isNotNull);
      expect(supabase.auth.currentUser?.id, session.user.id);
    });

    test('carries the user id, email and claims into the token', () async {
      final session = await signInTestUser(
        supabase.auth,
        userId: 'user-1',
        email: 'someone@example.com',
        claims: {
          'app_metadata': {'plan': 'pro'},
        },
      );

      final claims = decodeTestJwtClaims(session.accessToken);
      expect(claims['sub'], 'user-1');
      expect(claims['email'], 'someone@example.com');
      expect(claims['app_metadata'], {'plan': 'pro'});
      expect(supabase.auth.currentUser?.email, 'someone@example.com');
    });

    test('database requests carry the session token afterwards', () async {
      final session = await signInTestUser(supabase.auth);
      httpClient.stubTable('todos', rows: []);

      await supabase.from('todos').select();

      final request = httpClient.requests.single;
      expect(
        request.headers['Authorization'],
        'Bearer ${session.accessToken}',
      );
    });
  });
}
