import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  late MockSupabaseHttpClient httpClient;
  late AuthClient client;
  late List<AuthChangeEvent> events;

  setUp(() async {
    httpClient = MockSupabaseHttpClient();
    client = AuthClient(
      url: 'http://localhost:9999/auth/v1',
      httpClient: httpClient,
      autoRefreshToken: false,
      asyncStorage: TestAsyncStorage(),
    );
    await signInTestUser(client);
    events = [];
    client.onAuthStateChange.listen(
      (state) => events.add(state.event),
      onError: (_) {},
    );
    await pumpEventQueue();
    events.clear();
  });

  tearDown(() {
    client.dispose();
  });

  void stubOffline() {
    httpClient.stubError(ClientException('Offline'), path: '/auth/v1/logout');
  }

  void stubServerError() {
    httpClient.stub(
      {'code': 500, 'msg': 'Internal server error'},
      path: '/auth/v1/logout',
      statusCode: 500,
    );
  }

  String expiredAccessToken() => unsignedTestJwt({
    'sub': testUserId,
    'exp':
        DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch ~/
        1000,
  });

  Future<void> restoreExpiredSession() async {
    await client.setInitialSession(
      jsonEncode(testSessionResponseJson(accessToken: expiredAccessToken())),
    );
    await pumpEventQueue();
    events.clear();
  }

  void stubRateLimitedRefresh() {
    httpClient.stub(
      {'code': 'over_request_rate_limit', 'msg': 'Too many requests'},
      method: HttpMethod.post,
      path: '/auth/v1/token',
      query: {'grant_type': 'refresh_token'},
      statusCode: 429,
    );
  }

  void stubExpiredTokenRejected() {
    httpClient.stub(
      {
        'code': 'bad_jwt',
        'msg':
            'invalid JWT: unable to parse or verify signature, token has '
            'invalid claims: token is expired',
      },
      method: HttpMethod.post,
      path: '/auth/v1/logout',
      statusCode: 403,
    );
  }

  void stubRejectedRefresh() {
    httpClient.stub(
      {
        'code': 'refresh_token_not_found',
        'msg': 'Invalid Refresh Token: Refresh Token Not Found',
      },
      method: HttpMethod.post,
      path: '/auth/v1/token',
      statusCode: 400,
    );
  }

  group('signOut with the local scope', () {
    late List<LogRecord> warnings;

    setUp(() {
      warnings = [];
      final subscription = Logger.root.onRecord
          .where(
            (record) =>
                record.loggerName == 'supabase.auth' &&
                record.level == Level.WARNING,
          )
          .listen(warnings.add);
      addTearDown(subscription.cancel);
    });

    test('signs out on this device and logs while offline', () async {
      stubOffline();

      await client.signOut();
      await pumpEventQueue();

      expect(client.currentSession, isNull);
      expect(events, [AuthChangeEvent.signedOut]);
      expect(httpClient.requestsTo('/auth/v1/logout'), hasLength(1));
      expect(warnings.single.error, isA<AuthRetryableFetchException>());
    });

    test('signs out on this device and logs a server error', () async {
      stubServerError();

      await client.signOut();

      expect(client.currentSession, isNull);
      expect(warnings.single.error, isA<AuthRetryableApiException>());
    });

    test('signs out on this device before the call completes', () async {
      httpClient.stubStall(path: '/auth/v1/logout');

      unawaited(client.signOut());

      expect(client.currentSession, isNull);
      await pumpEventQueue();
      expect(events, [AuthChangeEvent.signedOut]);
    });

    test('waits for the server to revoke the session', () async {
      final logout = Completer<Response>();
      httpClient.stubHandler((_) => logout.future, path: '/auth/v1/logout');

      var done = false;
      final signOut = client.signOut().then((_) => done = true);
      await pumpEventQueue();

      expect(client.currentSession, isNull);
      expect(done, isFalse);

      logout.complete(Response('', 204));
      await signOut;

      expect(done, isTrue);
      expect(warnings, isEmpty);
    });

    test('gives up on the revoke after a timeout', () {
      fakeAsync((async) {
        httpClient.stubStall(path: '/auth/v1/logout');
        var done = false;
        unawaited(client.signOut().then((_) => done = true));

        async.elapse(const Duration(seconds: 9));
        expect(done, isFalse);
        expect(client.currentSession, isNull);

        async.elapse(const Duration(seconds: 1));
        expect(done, isTrue);
        expect(warnings.single.error, isA<AuthRetryableFetchException>());
      });
    });

    test('refreshes an expired access token before revoking', () async {
      await restoreExpiredSession();
      final expired = client.currentSession!.accessToken;
      httpClient
        ..stubSignIn()
        ..stubSignOut();

      await client.signOut();
      await pumpEventQueue();

      final logout = httpClient.requestsTo('/auth/v1/logout').single;
      expect(logout.headers['authorization'], startsWith('Bearer '));
      expect(logout.headers['authorization'], isNot('Bearer $expired'));
      expect(httpClient.requestsTo('/auth/v1/token'), hasLength(1));
      expect(client.currentSession, isNull);
      expect(events, [AuthChangeEvent.signedOut]);
      expect(warnings, isEmpty);
    });

    test(
      'treats a refresh token the server already revoked as revoked',
      () async {
        await restoreExpiredSession();
        stubRejectedRefresh();

        await client.signOut();

        expect(client.currentSession, isNull);
        expect(httpClient.requestsTo('/auth/v1/logout'), isEmpty);
        expect(warnings, isEmpty);
      },
    );

    test(
      'revokes with a token inside the expiry margin when the refresh fails',
      () async {
        await signInTestUser(
          client,
          expiresAt: DateTime.now().add(const Duration(seconds: 20)),
        );
        final token = client.currentSession!.accessToken;
        stubRateLimitedRefresh();
        httpClient.stubSignOut();

        await client.signOut();

        expect(
          httpClient
              .requestsTo('/auth/v1/logout')
              .single
              .headers['authorization'],
          'Bearer $token',
        );
        expect(client.currentSession, isNull);
        expect(warnings, isEmpty);
      },
    );

    test('logs when an expired access token cannot be refreshed', () async {
      await restoreExpiredSession();
      stubRateLimitedRefresh();
      stubExpiredTokenRejected();

      await client.signOut();

      expect(client.currentSession, isNull);
      expect(httpClient.requestsTo('/auth/v1/logout'), isEmpty);
      expect(warnings.single.error, isA<AuthApiException>());
    });
  });

  group('signOut with the global scope', () {
    test('throws and keeps the session while offline', () async {
      stubOffline();
      final session = client.currentSession;

      await expectLater(
        client.signOut(scope: SignOutScope.global),
        throwsA(isA<AuthRetryableFetchException>()),
      );
      await pumpEventQueue();

      expect(client.currentSession, session);
      expect(events, isEmpty);
    });

    test('can be retried once the server answers', () async {
      stubServerError();
      await expectLater(
        client.signOut(scope: SignOutScope.global),
        throwsA(isA<AuthRetryableApiException>()),
      );

      httpClient
        ..reset()
        ..stubSignOut();
      await client.signOut(scope: SignOutScope.global);
      await pumpEventQueue();

      expect(client.currentSession, isNull);
      expect(events, [AuthChangeEvent.signedOut]);
      expect(
        httpClient.requestsTo('/auth/v1/logout').single.url.queryParameters,
        {'scope': 'global'},
      );
    });

    test('signs out when the session is already gone on the server', () async {
      httpClient.stub(
        {
          'code': 'session_not_found',
          'msg': 'Session from session_id claim in JWT does not exist',
        },
        path: '/auth/v1/logout',
        statusCode: 403,
      );

      await client.signOut(scope: SignOutScope.global);

      expect(client.currentSession, isNull);
    });
    test('refreshes an expired access token before revoking', () async {
      final expired = unsignedTestJwt({
        'sub': testUserId,
        'exp':
            DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      });
      await client.setInitialSession(
        jsonEncode(testSessionResponseJson(accessToken: expired)),
      );
      httpClient
        ..stubSignIn()
        ..stubSignOut();

      await client.signOut(scope: SignOutScope.global);

      final logout = httpClient.requestsTo('/auth/v1/logout').single;
      expect(logout.headers['authorization'], isNot('Bearer $expired'));
      expect(httpClient.requestsTo('/auth/v1/token'), hasLength(1));
      expect(client.currentSession, isNull);
    });

    test(
      'throws and keeps an expired session that cannot be refreshed',
      () async {
        await restoreExpiredSession();
        final session = client.currentSession;
        stubRateLimitedRefresh();
        stubExpiredTokenRejected();

        await expectLater(
          () => client.signOut(scope: SignOutScope.global),
          throwsA(isA<AuthApiException>()),
        );
        await pumpEventQueue();

        expect(client.currentSession, session);
        expect(events, isEmpty);
        expect(httpClient.requestsTo('/auth/v1/logout'), isEmpty);
      },
    );

    test('throws on a 401 without an error code once the access token has '
        'expired', () {
      fakeAsync((async) {
        unawaited(
          signInTestUser(
            client,
            expiresAt: clock.now().add(const Duration(seconds: 20)),
          ),
        );
        async.flushMicrotasks();
        final session = client.currentSession;
        stubRateLimitedRefresh();
        httpClient.stubHandler(
          (_) => Future.delayed(
            const Duration(seconds: 30),
            () => Response(
              jsonEncode({'code': 401, 'msg': 'invalid JWT'}),
              401,
            ),
          ),
          path: '/auth/v1/logout',
        );
        Object? error;
        unawaited(
          client
              .signOut(scope: SignOutScope.global)
              .then(
                (_) {},
                onError: (Object signOutError) {
                  error = signOutError;
                },
              ),
        );

        async.elapse(const Duration(seconds: 30));

        expect(error, isA<AuthApiException>());
        expect(client.currentSession, session);
      });
    });

    test('throws when the server says the token has expired', () async {
      final session = client.currentSession;
      stubExpiredTokenRejected();

      await expectLater(
        () => client.signOut(scope: SignOutScope.global),
        throwsA(isA<AuthApiException>()),
      );

      expect(client.currentSession, session);
    });

    test('throws when the server rejects the token signature', () async {
      final session = client.currentSession;
      httpClient.stub(
        {
          'code': 'bad_jwt',
          'msg':
              'invalid JWT: unable to parse or verify signature, token '
              'signature is invalid: crypto/rsa: verification error',
        },
        method: HttpMethod.post,
        path: '/auth/v1/logout',
        statusCode: 403,
      );

      await expectLater(
        () => client.signOut(scope: SignOutScope.global),
        throwsA(isA<AuthApiException>()),
      );

      expect(client.currentSession, session);
    });

    test(
      'keeps a session signed in while the expired session was refreshed',
      () async {
        await restoreExpiredSession();
        final refresh = Completer<Response>();
        httpClient
          ..stubSignIn()
          ..stubSignOut()
          ..stubHandler(
            (_) => refresh.future,
            method: HttpMethod.post,
            path: '/auth/v1/token',
            query: {'grant_type': 'refresh_token'},
          );

        final signOut = client.signOut(scope: SignOutScope.global);
        await pumpEventQueue();
        final session = await client.signInWithPassword(
          email: 'fake2@email.com',
          password: 'password',
        );
        refresh.complete(
          Response(
            jsonEncode(
              testSessionResponseJson(
                accessToken: unsignedTestJwt({'sub': testUserId}),
                refreshToken: 'refreshed',
              ),
            ),
            200,
          ),
        );
        await signOut;
        await pumpEventQueue();

        expect(httpClient.requestsTo('/auth/v1/logout'), hasLength(1));
        expect(client.currentSession, session);
        expect(events, isNot(contains(AuthChangeEvent.signedOut)));
      },
    );

    test(
      'throws the refresh error when the PKCE verifiers cannot be removed',
      () async {
        final failingClient = AuthClient(
          url: 'http://localhost:9999/auth/v1',
          httpClient: httpClient,
          autoRefreshToken: false,
          asyncStorage: _FailingRemoveStorage(),
        );
        addTearDown(failingClient.dispose);
        await failingClient.setInitialSession(
          jsonEncode(
            testSessionResponseJson(accessToken: expiredAccessToken()),
          ),
        );
        stubRejectedRefresh();

        await expectLater(
          () => failingClient.signOut(scope: SignOutScope.global),
          throwsA(isA<AuthApiException>()),
        );
      },
    );

    test(
      'throws when the refresh token was rejected, signed out on this device',
      () async {
        await restoreExpiredSession();
        stubRejectedRefresh();

        await expectLater(
          () => client.signOut(scope: SignOutScope.global),
          throwsA(isA<AuthApiException>()),
        );

        expect(client.currentSession, isNull);
        expect(httpClient.requestsTo('/auth/v1/logout'), isEmpty);
      },
    );

    test('keeps a session signed in while the request was sent', () async {
      final logout = Completer<Response>();
      httpClient
        ..stubHandler((_) => logout.future, path: '/auth/v1/logout')
        ..stubSignIn();

      final signOut = client.signOut(scope: SignOutScope.global);
      await pumpEventQueue();
      final session = await client.signInWithPassword(
        email: 'fake2@email.com',
        password: 'password',
      );
      logout.complete(Response('', 204));
      await signOut;
      await pumpEventQueue();

      expect(client.currentSession, session);
      expect(events, isNot(contains(AuthChangeEvent.signedOut)));
    });
  });

  group('signOut with the others scope', () {
    test('throws and keeps the session while offline', () async {
      stubOffline();
      final session = client.currentSession;

      await expectLater(
        client.signOut(scope: SignOutScope.others),
        throwsA(isA<AuthRetryableFetchException>()),
      );

      expect(client.currentSession, session);
    });

    test(
      'throws and keeps an expired session that cannot be refreshed',
      () async {
        await restoreExpiredSession();
        final session = client.currentSession;
        stubRateLimitedRefresh();
        stubExpiredTokenRejected();

        await expectLater(
          () => client.signOut(scope: SignOutScope.others),
          throwsA(isA<AuthApiException>()),
        );

        expect(client.currentSession, session);
        expect(httpClient.requestsTo('/auth/v1/logout'), isEmpty);
      },
    );

    test('throws when the refresh token was rejected', () async {
      await restoreExpiredSession();
      stubRejectedRefresh();

      await expectLater(
        () => client.signOut(scope: SignOutScope.others),
        throwsA(isA<AuthApiException>()),
      );

      expect(httpClient.requestsTo('/auth/v1/logout'), isEmpty);
    });

    test('keeps the session once the server revoked the others', () async {
      httpClient.stubSignOut();
      final session = client.currentSession;

      await client.signOut(scope: SignOutScope.others);
      await pumpEventQueue();

      expect(client.currentSession, session);
      expect(events, isEmpty);
    });
  });
}

class _FailingRemoveStorage extends MemoryAuthAsyncStorage {
  @override
  Future<void> removeItem(String key) =>
      Future.error(StateError('Storage is unavailable'));
}
