// ignore_for_file: depend_on_referenced_packages

import 'package:clock/clock.dart';
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

  test('refreshes expired access token on socket reconnect', () async {
    var currentTime = DateTime(2026, 1, 1, 12);
    await withClock(Clock(() => currentTime), () async {
      final realtimeTransport = MockRealtimeTransport();
      await supabase.dispose();
      supabase = SupabaseClient(
        'http://localhost:54321',
        apiKey,
        httpClient: httpClient,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        realtimeOptions: RealtimeClientOptions(
          transport: realtimeTransport.call,
          reconnectAfter: (_) => const Duration(milliseconds: 10),
        ),
      );

      final initialSession = await signInTestUser(
        supabase.auth,
        expiresAt: currentTime.add(const Duration(hours: 1)),
      );
      expect(await realtimeToken(), initialSession.accessToken);

      final channel = supabase.channel('todos');
      channel.subscribe();
      await pumpEventQueue();
      expect(realtimeTransport.joinedTopics, contains('realtime:todos'));

      // Move clock forward past expiry
      currentTime = currentTime.add(const Duration(hours: 2));
      final newExp =
          currentTime.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      final refreshedToken = accessTokenWith({'exp': newExp});

      httpClient.stub(
        testSessionResponseJson(accessToken: refreshedToken),
        method: HttpMethod.post,
        path: '/auth/v1/token',
      );

      await realtimeTransport.closeConnection(code: 1006);
      while (supabase.realtime.accessToken != refreshedToken) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(supabase.realtime.accessToken, refreshedToken);
    });
  });

  test('refreshes expired access token on heartbeat', () async {
    var currentTime = DateTime(2026, 1, 1, 12);
    await withClock(Clock(() => currentTime), () async {
      final realtimeTransport = MockRealtimeTransport();
      await supabase.dispose();
      supabase = testSupabaseClient(
        httpClient: httpClient,
        publishableKey: apiKey,
        realtimeTransport: realtimeTransport.call,
      );

      final initialSession = await signInTestUser(
        supabase.auth,
        expiresAt: currentTime.add(const Duration(hours: 1)),
      );
      expect(await realtimeToken(), initialSession.accessToken);

      final channel = supabase.channel('todos');
      channel.subscribe();
      await pumpEventQueue();

      currentTime = currentTime.add(const Duration(hours: 2));
      final newExp =
          currentTime.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      final refreshedToken = accessTokenWith({'exp': newExp});

      httpClient.stub(
        testSessionResponseJson(accessToken: refreshedToken),
        method: HttpMethod.post,
        path: '/auth/v1/token',
      );

      // ignore: invalid_use_of_internal_member
      await supabase.realtime.sendHeartbeat();
      await pumpEventQueue();

      expect(await realtimeToken(), refreshedToken);
    });
  });
}
