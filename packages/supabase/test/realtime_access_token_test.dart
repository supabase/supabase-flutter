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

  group('over a realtime connection', () {
    late MockRealtimeTransport realtimeTransport;
    late DateTime now;
    late String refreshedToken;

    setUp(() async {
      now = clock.now();
      refreshedToken = accessTokenWith({
        'exp': now.add(const Duration(hours: 3)).millisecondsSinceEpoch ~/ 1000,
      });
      realtimeTransport = MockRealtimeTransport();
      await supabase.dispose();
    });

    /// Runs [body] at [now], so moving [now] forward expires the session.
    Future<void> atNow(Future<void> Function() body) =>
        withClock(Clock(() => now), body);

    void createClient({Map<String, String>? headers}) {
      supabase = SupabaseClient(
        'http://localhost:54321',
        apiKey,
        httpClient: httpClient,
        headers: headers,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          retryOptions: SupabaseRetryOptions(enabled: false),
        ),
        realtimeOptions: RealtimeClientOptions(
          transport: realtimeTransport.call,
          heartbeatInterval: const Duration(milliseconds: 10),
          reconnectAfter: (_) => Duration.zero,
        ),
      );
    }

    Future<void> subscribe() async {
      supabase.channel('todos').subscribe();
      await pumpEventQueue();
      expect(realtimeTransport.joinedTopics, contains('realtime:todos'));
    }

    Future<void> nextHeartbeat() async {
      await supabase.realtime.onHeartbeat.firstWhere(
        (status) => status == RealtimeHeartbeatStatus.sent,
      );
      await pumpEventQueue();
    }

    void stubRefresh() => httpClient.stub(
      testSessionResponseJson(accessToken: refreshedToken),
      method: HttpMethod.post,
      path: '/auth/v1/token',
    );

    Iterable<Object?> joinTokens() => realtimeTransport.sent
        .where((message) => message.event == 'phx_join')
        .map(
          (message) =>
              (message.payload as Map<String, dynamic>)['access_token'],
        );

    test('follows a token refresh when the socket reconnects', () async {
      await atNow(() async {
        createClient();
        await signInTestUser(supabase.auth);
        await subscribe();
        stubRefresh();
        now = now.add(const Duration(hours: 2));

        await realtimeTransport.closeConnection(code: 1006);
        await pumpEventQueue();
      });

      expect(await realtimeToken(), refreshedToken);
      expect(joinTokens().last, refreshedToken);
    });

    test('follows a token refresh on a heartbeat', () async {
      await atNow(() async {
        createClient();
        await signInTestUser(supabase.auth);
        await subscribe();
        stubRefresh();
        now = now.add(const Duration(hours: 2));

        await nextHeartbeat();
      });

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
        late String expiredToken;
        late int joinCount;
        await atNow(() async {
          createClient();
          expiredToken = (await signInTestUser(supabase.auth)).accessToken;
          await subscribe();
          joinCount = joinTokens().length;
          httpClient.stubError(
            ClientException('offline'),
            method: HttpMethod.post,
            path: '/auth/v1/token',
          );
          now = now.add(const Duration(hours: 2));

          await realtimeTransport.closeConnection(code: 1006);
          await pumpEventQueue();
        });

        expect(joinTokens(), hasLength(joinCount));
        expect(supabase.realtime.accessToken, expiredToken);
      },
    );

    test('does not refresh a valid token on a heartbeat', () async {
      late Session session;
      await atNow(() async {
        createClient();
        session = await signInTestUser(supabase.auth);
        await subscribe();

        await nextHeartbeat();
      });

      expect(await realtimeToken(), session.accessToken);
      expect(httpClient.requestsTo('/auth/v1/token'), isEmpty);
    });

    test(
      'keeps the JWT of an Authorization header without a session',
      () async {
        createClient(headers: {'Authorization': 'Bearer header-jwt'});
        await subscribe();

        await nextHeartbeat();

        expect(await realtimeToken(), 'header-jwt');
        expect(joinTokens().last, 'header-jwt');
      },
    );
  });
}
