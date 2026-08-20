import 'package:supabase/supabase.dart';
import 'package:supabase_testing/supabase_testing.dart';
import 'package:test/test.dart';

void main() {
  test('testSupabaseClient constructs without further configuration', () async {
    final supabase = testSupabaseClient();
    addTearDown(supabase.dispose);

    expect(supabase.auth.currentSession, isNull);
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
