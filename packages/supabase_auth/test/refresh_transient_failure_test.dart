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
  const tickDuration = Duration(seconds: 10);
  const htmlPage = '<html><body>Sign in to the network</body></html>';
  const rateLimit = {
    'code': 'over_request_rate_limit',
    'msg': 'Request rate limit reached',
  };
  final storageKey = defaultPersistSessionKey(authUrl);

  late MockSupabaseHttpClient httpClient;
  late TestAsyncStorage storage;
  late AuthClient client;
  late List<AuthState> states;
  late List<Object> errors;
  late Session stored;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    storage = TestAsyncStorage();
    states = [];
    errors = [];
  });

  Future<void> signIn({
    SupabaseRetryOptions retryOptions = const SupabaseRetryOptions(
      enabled: false,
    ),
  }) async {
    client = AuthClient(
      url: authUrl,
      asyncStorage: storage,
      httpClient: httpClient,
      persistSession: true,
      autoRefreshToken: false,
      retryOptions: retryOptions,
    );
    addTearDown(client.dispose);
    final subscription = client.onAuthStateChange.listen(
      states.add,
      onError: errors.add,
    );
    addTearDown(subscription.cancel);
    stored = await signInTestUser(client);
    await pumpEventQueue();
    states.clear();
  }

  void stubRefreshJson(
    Object? body, {
    required int statusCode,
    Map<String, String> headers = const {},
    int? times,
  }) {
    httpClient.stub(
      body,
      method: HttpMethod.post,
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
      method: HttpMethod.post,
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

  int refreshRequests() => httpClient.requestsTo('/token').length;

  Future<void> expectSessionKept() async {
    await pumpEventQueue();
    expect(events(), isNot(contains(AuthChangeEvent.signedOut)));
    expect(client.currentSession?.refreshToken, stored.refreshToken);
    expect(await storage.getItem(storageKey), isNotNull);
  }

  /// Runs an auto refresh tick at [now], close enough to the expiry of the
  /// stored session that the tick refreshes it.
  Future<void> tick({Duration after = Duration.zero}) {
    final now = stored.expiresAt!
        .subtract(const Duration(seconds: 20))
        .add(after);
    return withClock(Clock.fixed(now), () async {
      client.startAutoRefresh();
      await pumpEventQueue();
      client.stopAutoRefresh();
    });
  }

  final transientFailures = <String, void Function({int? times})>{
    '429 with a JSON error': ({times}) =>
        stubRefreshJson(rateLimit, statusCode: 429, times: times),
    '429 with an HTML page': ({times}) => stubRefreshHtml(429, times: times),
    '401 with an HTML page': ({times}) => stubRefreshHtml(401, times: times),
    '403 with an HTML page': ({times}) => stubRefreshHtml(403, times: times),
    '404 with an HTML page': ({times}) => stubRefreshHtml(404, times: times),
    '403 with an empty body': ({times}) =>
        stubRefreshJson(null, statusCode: 403, times: times),
    '401 with a JSON error without a code': ({times}) => stubRefreshJson(
      {'message': 'Invalid API key'},
      statusCode: 401,
      times: times,
    ),
  };

  group('a refresh answered with', () {
    setUp(signIn);

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

        await tick();
        await expectSessionKept();

        await tick(after: tickDuration);

        expect(events(), [AuthChangeEvent.tokenRefreshed]);
        expect(client.currentSession?.refreshToken, 'refreshed-refresh-token');
        expect(refreshRequests(), 2);
      });
    }

    test('a 429 with a Retry-After keeps the session', () async {
      stubRefreshJson(
        rateLimit,
        statusCode: 429,
        headers: {'retry-after': '3600'},
      );

      await expectLater(
        client.refreshSession(),
        throwsA(isA<AuthApiException>()),
      );

      await expectSessionKept();
    });

    test('a 429 with a Retry-After pauses the ticks until it passes', () async {
      stubRefreshSuccess();
      stubRefreshJson(
        rateLimit,
        statusCode: 429,
        headers: {'retry-after': '60'},
        times: 1,
      );

      await tick();
      await expectSessionKept();

      await tick(after: tickDuration);
      expect(refreshRequests(), 1);

      await tick(after: const Duration(seconds: 61));

      expect(events(), [AuthChangeEvent.tokenRefreshed]);
      expect(refreshRequests(), 2);
    });
  });

  group('with retries enabled, a refresh answered with', () {
    setUp(
      () => signIn(
        retryOptions: const SupabaseRetryOptions(
          count: 2,
          initialDelay: Duration(milliseconds: 1),
        ),
      ),
    );

    for (final MapEntry(key: description, value: stubFailure)
        in transientFailures.entries) {
      test('$description is not retried within the tick', () async {
        stubFailure();

        await expectLater(
          client.refreshSession(),
          throwsA(isA<AuthException>()),
        );

        expect(refreshRequests(), 1);
      });
    }

    test('a 429 is retried within the tick after its Retry-After', () async {
      stubRefreshSuccess();
      stubRefreshJson(
        rateLimit,
        statusCode: 429,
        headers: {'retry-after': '0'},
        times: 1,
      );

      final session = await client.refreshSession().timeout(
        const Duration(seconds: 5),
      );

      expect(session.refreshToken, 'refreshed-refresh-token');
      expect(refreshRequests(), 2);
    });
  });

  group('a refresh token rejected with', () {
    setUp(signIn);

    for (final code in [
      ErrorCode.refreshTokenNotFound,
      ErrorCode.sessionNotFound,
      ErrorCode.sessionExpired,
      ErrorCode.userNotFound,
      ErrorCode.userBanned,
      ErrorCode.validationFailed,
    ]) {
      test('${code.code} signs out', () async {
        stubRefreshJson({
          'code': code.code,
          'msg': 'Invalid Refresh Token',
        }, statusCode: 400);

        await expectLater(
          client.refreshSession(),
          throwsA(
            isA<AuthApiException>().having(
              (error) => error.errorCode,
              'errorCode',
              code.code,
            ),
          ),
        );
        await pumpEventQueue();

        final signedOut = states.whereType<AuthSignedOut>().single;
        expect(signedOut.reason, SignOutReason.sessionExpired);
        expect(client.currentSession, isNull);
        expect(await storage.getItem(storageKey), isNull);
        expect(refreshRequests(), 1);
      });
    }
  });
}
