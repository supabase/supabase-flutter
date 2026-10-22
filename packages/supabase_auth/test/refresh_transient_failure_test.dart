import 'dart:async';

import 'package:clock/clock.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// Only a refresh token the auth service rejects ends the session. A rate
/// limit, or a response from something in front of the service such as a
/// captive portal or proxy, keeps it so the next refresh can try again.
void main() {
  const authUrl = 'http://localhost:9999';
  const refreshQuery = {'grant_type': 'refresh_token'};
  const apiVersionHeaders = {'x-sb-api-version': '2024-01-01'};
  const htmlPage = '<html><body>Sign in to the network</body></html>';
  final storageKey = defaultPersistSessionKey(authUrl);

  late MockSupabaseHttpClient httpClient;
  late TestAsyncStorage storage;
  late AuthClient client;
  late List<AuthState> states;
  late List<Object> errors;
  late Session stored;

  AuthClient createClient({
    SupabaseRetryOptions retryOptions = const SupabaseRetryOptions(
      enabled: false,
    ),
  }) {
    final authClient = AuthClient(
      url: authUrl,
      asyncStorage: storage,
      httpClient: httpClient,
      persistSession: true,
      autoRefreshToken: false,
      retryOptions: retryOptions,
    );
    addTearDown(authClient.dispose);
    final subscription = authClient.onAuthStateChange.listen(
      states.add,
      onError: errors.add,
    );
    addTearDown(subscription.cancel);
    return authClient;
  }

  void stubRefreshJson(
    Object? body, {
    required int statusCode,
    Map<String, String> headers = const {},
    int? times,
  }) {
    httpClient.stub(
      body,
      method: HttpMethod.post.value,
      path: '/token',
      query: refreshQuery,
      statusCode: statusCode,
      headers: {...apiVersionHeaders, ...headers},
      times: times,
    );
  }

  void stubRefreshHtml(int statusCode, {int? times}) {
    httpClient.stubText(
      htmlPage,
      method: HttpMethod.post.value,
      path: '/token',
      query: refreshQuery,
      statusCode: statusCode,
      contentType: 'text/html; charset=utf-8',
      times: times,
    );
  }

  void stubRefreshSuccess() {
    stubRefreshJson(
      testSessionResponseJson(
        accessToken: unsignedTestJwt({
          'sub': testUserId,
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
        }),
        refreshToken: 'refreshed-refresh-token',
      ),
      statusCode: 200,
    );
  }

  Iterable<AuthChangeEvent> events() => states.map((state) => state.event);

  setUp(() async {
    httpClient = MockSupabaseHttpClient();
    storage = TestAsyncStorage();
    states = [];
    errors = [];
    client = createClient();
    stored = await signInTestUser(client);
    await pumpEventQueue();
    states.clear();
  });

  Future<void> expectSessionKept() async {
    await pumpEventQueue();
    expect(events(), isNot(contains(AuthChangeEvent.signedOut)));
    expect(client.currentSession?.refreshToken, stored.refreshToken);
    expect(await storage.getItem(storageKey), isNotNull);
  }

  final transientFailures = <String, void Function({int? times})>{
    '429 with a JSON error': ({times}) => stubRefreshJson(
      {'code': 'over_request_rate_limit', 'msg': 'Request rate limit reached'},
      statusCode: 429,
      times: times,
    ),
    '429 with a Retry-After header': ({times}) => stubRefreshJson(
      {'code': 'over_request_rate_limit', 'msg': 'Request rate limit reached'},
      statusCode: 429,
      headers: {'retry-after': '3600'},
      times: times,
    ),
    '429 with an HTML page': ({times}) => stubRefreshHtml(429, times: times),
    '401 with an HTML page': ({times}) => stubRefreshHtml(401, times: times),
    '403 with an HTML page': ({times}) => stubRefreshHtml(403, times: times),
    '404 with an HTML page': ({times}) => stubRefreshHtml(404, times: times),
    '403 with an empty body': ({times}) => stubRefreshJson(
      null,
      statusCode: 403,
      times: times,
    ),
    '401 with a JSON error without a code': ({times}) => stubRefreshJson(
      {'message': 'Invalid API key'},
      statusCode: 401,
      times: times,
    ),
  };

  group('a refresh answered with', () {
    for (final MapEntry(key: description, value: stubFailure)
        in transientFailures.entries) {
      test('$description keeps the session', () async {
        stubFailure();

        await expectLater(
          client.refreshSession(),
          throwsA(isA<AuthException>()),
        );

        await expectSessionKept();
        expect(errors, hasLength(1));
      });

      test('$description is retried on the next tick', () async {
        stubRefreshSuccess();
        stubFailure(times: 1);

        // Close enough to expiry that every auto refresh tick refreshes.
        final nearExpiry = stored.expiresAt!.subtract(
          const Duration(seconds: 20),
        );
        await withClock(Clock.fixed(nearExpiry), () async {
          client.startAutoRefresh();
          await pumpEventQueue();
          await expectSessionKept();

          client.startAutoRefresh();
          await pumpEventQueue();
          client.stopAutoRefresh();
        });

        expect(events(), [AuthChangeEvent.tokenRefreshed]);
        expect(client.currentSession?.refreshToken, 'refreshed-refresh-token');
        expect(httpClient.requestsTo('/token'), hasLength(2));
      });
    }
  });

  test('a 429 within the tick is retried after its Retry-After', () async {
    client = createClient(
      retryOptions: const SupabaseRetryOptions(
        count: 1,
        initialDelay: Duration(hours: 1),
      ),
    );
    stored = await signInTestUser(client);
    await pumpEventQueue();
    states.clear();
    stubRefreshSuccess();
    stubRefreshJson(
      {'code': 'over_request_rate_limit', 'msg': 'Request rate limit reached'},
      statusCode: 429,
      headers: {'retry-after': '0'},
      times: 1,
    );

    final session = await client.refreshSession().timeout(
      const Duration(seconds: 5),
    );

    expect(session.refreshToken, 'refreshed-refresh-token');
    expect(httpClient.requestsTo('/token'), hasLength(2));
  });

  group('a refresh token rejected with', () {
    for (final code in [
      'refresh_token_not_found',
      'session_not_found',
      'session_expired',
      'user_not_found',
      'user_banned',
      'validation_failed',
    ]) {
      test('$code signs out', () async {
        stubRefreshJson({
          'code': code,
          'msg': 'Invalid Refresh Token',
        }, statusCode: 400);

        await expectLater(
          client.refreshSession(),
          throwsA(
            isA<AuthApiException>().having(
              (error) => error.errorCode,
              'errorCode',
              code,
            ),
          ),
        );
        await pumpEventQueue();

        final signedOut = states.whereType<AuthSignedOut>().single;
        expect(signedOut.reason, SignOutReason.sessionExpired);
        expect(client.currentSession, isNull);
        expect(await storage.getItem(storageKey), isNull);
        expect(httpClient.requestsTo('/token'), hasLength(1));
      });
    }

    test('a 400 without a code from a server that predates codes signs '
        'out', () async {
      stubRefreshJson({
        'error': 'invalid_grant',
        'error_description': 'Invalid Refresh Token: Refresh Token Not Found',
      }, statusCode: 400);

      await expectLater(
        client.refreshSession(),
        throwsA(isA<AuthApiException>()),
      );
      await pumpEventQueue();

      expect(
        states.whereType<AuthSignedOut>().single.reason,
        SignOutReason.sessionExpired,
      );
      expect(client.currentSession, isNull);
    });
  });
}
