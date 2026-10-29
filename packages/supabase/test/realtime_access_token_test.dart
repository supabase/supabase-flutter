import 'package:clock/clock.dart';
import 'package:http/http.dart';
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

  group('with a session that expires while connected', () {
    late MockRealtimeTransport realtimeTransport;
    late DateTime now;
    late String expiredToken;
    late String refreshedToken;

    setUp(() async {
      now = clock.now();
      realtimeTransport = MockRealtimeTransport();
      await supabase.dispose();
      supabase = testSupabaseClient(
        httpClient: httpClient,
        publishableKey: apiKey,
        realtimeTransport: realtimeTransport.call,
      );
      await withClock(Clock.fixed(now), () async {
        final session = await signInTestUser(supabase.auth);
        expiredToken = session.accessToken;
        supabase.channel('todos').subscribe();
        await pumpEventQueue();
      });
      expect(realtimeTransport.joinedTopics, contains('realtime:todos'));

      now = now.add(const Duration(hours: 2));
      refreshedToken = accessTokenWith({
        'exp': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      });
    });

    Future<void> atCurrentTime(Future<void> Function() body) =>
        withClock(Clock(() => now), body);

    void stubRefresh() => httpClient.stub(
      testSessionResponseJson(accessToken: refreshedToken),
      method: HttpMethod.post,
      path: '/auth/v1/token',
    );

    String lastJoinToken() {
      final join = realtimeTransport.sent.lastWhere(
        (message) => message.event == 'phx_join',
      );
      return (join.payload as Map<String, dynamic>)['access_token'] as String;
    }

    test('follows a token refresh when the socket reconnects', () async {
      stubRefresh();

      await atCurrentTime(() async {
        await supabase.realtime.disconnect();
        // ignore: invalid_use_of_internal_member
        await supabase.realtime.connect();
        await pumpEventQueue();
      });

      expect(await realtimeToken(), refreshedToken);
      expect(lastJoinToken(), refreshedToken);
    });

    test('follows a token refresh on a heartbeat', () async {
      stubRefresh();

      // ignore: invalid_use_of_internal_member
      await atCurrentTime(supabase.realtime.sendHeartbeat);

      expect(await realtimeToken(), refreshedToken);
      expect(
        realtimeTransport.sent.where(
          (message) => message.event == 'access_token',
        ),
        contains(
          isA<RealtimeMessage>().having(
            (message) => message.payload,
            'payload',
            {'access_token': refreshedToken},
          ),
        ),
      );
    });

    test(
      'does not rejoin with the expired token when refreshing fails',
      () async {
        httpClient.stubError(
          ClientException('offline'),
          method: HttpMethod.post,
          path: '/auth/v1/token',
        );
        final joinsBefore = realtimeTransport.sent
            .where((message) => message.event == 'phx_join')
            .length;

        await atCurrentTime(() async {
          await supabase.realtime.disconnect();
          // ignore: invalid_use_of_internal_member
          await supabase.realtime.connect();
          await pumpEventQueue();
        });

        expect(realtimeTransport.isConnected, isFalse);
        expect(
          realtimeTransport.sent.where(
            (message) => message.event == 'phx_join',
          ),
          hasLength(joinsBefore),
        );
        expect(supabase.realtime.accessToken, expiredToken);
      },
    );
  });

  test('does not refresh a valid token on a heartbeat', () async {
    final realtimeTransport = MockRealtimeTransport();
    await supabase.dispose();
    supabase = testSupabaseClient(
      httpClient: httpClient,
      publishableKey: apiKey,
      realtimeTransport: realtimeTransport.call,
    );
    final session = await signInTestUser(supabase.auth);
    supabase.channel('todos').subscribe();
    await pumpEventQueue();

    // ignore: invalid_use_of_internal_member
    await supabase.realtime.sendHeartbeat();

    expect(await realtimeToken(), session.accessToken);
    expect(httpClient.requestsTo('/auth/v1/token'), isEmpty);
  });

  for (final header in ['Authorization', 'authorization']) {
    test('keeps the JWT of an $header header without a session', () async {
      final realtimeTransport = MockRealtimeTransport();
      await supabase.dispose();
      supabase = SupabaseClient(
        'http://localhost:54321',
        apiKey,
        httpClient: httpClient,
        headers: {header: 'Bearer header-jwt'},
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          persistSession: false,
        ),
        realtimeOptions: RealtimeClientOptions(
          transport: realtimeTransport.call,
        ),
      );
      supabase.channel('todos').subscribe();
      await pumpEventQueue();

      // ignore: invalid_use_of_internal_member
      await supabase.realtime.sendHeartbeat();

      expect(await realtimeToken(), 'header-jwt');
    });
  }
}
