import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

/// Asserts that the realtime client follows every access token change of the
/// auth client.
void main() {
  late MockSupabaseHttpClient httpClient;
  late SupabaseClient supabase;
  const apiKey = 'test-api-key';

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    supabase = testSupabaseClient(
      httpClient: httpClient,
      publishableKey: apiKey,
    );
  });

  tearDown(() => supabase.dispose());

  Future<String?> realtimeToken() async {
    await pumpEventQueue();
    return supabase.realtime.accessToken;
  }

  String accessTokenWith(Map<String, dynamic> claims) => unsignedTestJwt({
    'exp':
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000,
    'sub': testUserId,
    'role': 'authenticated',
    ...claims,
  });

  test('follows a sign-in', () async {
    httpClient.stubSignIn();

    final session = await supabase.auth.signInWithPassword(
      email: 'fake1@email.com',
      password: 'password',
    );

    expect(await realtimeToken(), session.accessToken);
  });

  test('follows a token refresh', () async {
    await signInTestUser(supabase.auth);
    httpClient.stubSignIn();

    final session = await supabase.auth.refreshSession();

    expect(await realtimeToken(), session.accessToken);
  });

  test('falls back to the API key after a sign-out', () async {
    await signInTestUser(supabase.auth);
    httpClient.stubSignOut();

    await supabase.auth.signOut();

    expect(await realtimeToken(), apiKey);
  });

  test('follows the aal2 session of a verified MFA challenge', () async {
    await signInTestUser(supabase.auth, claims: {'aal': 'aal1'});
    final aal2Token = accessTokenWith({'aal': 'aal2'});
    httpClient.stub(
      testSessionResponseJson(accessToken: aal2Token),
      method: HttpMethod.post,
      path: '/auth/v1/factors/factor-id/verify',
    );

    await supabase.auth.mfa.verify(
      factorId: 'factor-id',
      challengeId: 'challenge-id',
      code: '123456',
    );

    expect(supabase.auth.currentSession?.accessToken, aal2Token);
    expect(await realtimeToken(), aal2Token);
  });

  for (final (redirectType, event) in [
    ('recovery', AuthChangeEvent.passwordRecovery),
    ('email_change', AuthChangeEvent.userUpdated),
  ]) {
    test('follows the session of a ${event.name} redirect', () async {
      final redirectToken = accessTokenWith({});
      httpClient.stubUser();
      final events = <AuthChangeEvent>[];
      final subscription = supabase.auth.onAuthStateChange.listen(
        (state) => events.add(state.event),
      );
      addTearDown(subscription.cancel);

      await supabase.auth.getSessionFromUrl(
        Uri.parse(
          'http://localhost/#access_token=$redirectToken'
          '&expires_in=3600&refresh_token=refresh&token_type=bearer'
          '&type=$redirectType',
        ),
      );

      expect(await realtimeToken(), redirectToken);
      expect(events, contains(event));
    });
  }
}
