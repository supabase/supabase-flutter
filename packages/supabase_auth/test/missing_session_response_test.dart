import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('a token response without a session', () {
    const requestId = 'request-id';
    late MockSupabaseHttpClient httpClient;
    late AuthClient client;
    late List<AuthChangeEvent> events;

    setUp(() async {
      httpClient = MockSupabaseHttpClient()
        ..stub(testUserJson(), headers: {'sb-request-id': requestId});
      client = AuthClient(
        url: 'http://localhost:9999',
        httpClient: httpClient,
        autoRefreshToken: false,
        asyncStorage: TestAsyncStorage(),
      );
      events = [];
      client.onAuthStateChange.listen(
        (state) => events.add(state.event),
        onError: (_) {},
      );
      await pumpEventQueue();
    });

    tearDown(() {
      client.dispose();
    });

    void expectNothingSignedIn() {
      expect(client.currentSession, isNull);
      expect(events, [AuthChangeEvent.initialSession]);
    }

    final throwsSessionMissing = throwsA(
      isA<AuthSessionMissingException>()
          .having(
            (error) => error.message,
            'message',
            'The server response did not contain a session.',
          )
          .having(
            (error) => error.errorCode,
            'errorCode',
            ErrorCode.sessionMissing.code,
          )
          .having((error) => error.requestId, 'requestId', requestId),
    );

    test('makes signInWithPassword throw without signing in', () async {
      await expectLater(
        client.signInWithPassword(
          email: 'fake1@email.com',
          password: 'password',
        ),
        throwsSessionMissing,
      );
      await pumpEventQueue();

      expectNothingSignedIn();
    });

    test(
      'makes signInWithPassword with a phone throw without signing in',
      () async {
        await expectLater(
          client.signInWithPassword(
            phone: '166600000000',
            password: 'password',
          ),
          throwsSessionMissing,
        );
        await pumpEventQueue();

        expectNothingSignedIn();
      },
    );

    test('makes signInAnonymously throw without signing in', () async {
      await expectLater(client.signInAnonymously(), throwsSessionMissing);
      await pumpEventQueue();

      expectNothingSignedIn();
    });

    test('makes signInWithIdToken throw without signing in', () async {
      await expectLater(
        client.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: 'id-token',
        ),
        throwsSessionMissing,
      );
      await pumpEventQueue();

      expectNothingSignedIn();
    });

    test('makes signInWithWeb3 throw without signing in', () async {
      await expectLater(
        client.signInWithWeb3(
          chain: Web3Chain.ethereum,
          message: 'example.com wants you to sign in',
          signature: '0xdeadbeef',
        ),
        throwsSessionMissing,
      );
      await pumpEventQueue();

      expectNothingSignedIn();
    });

    test('makes linkIdentityWithIdToken throw and keep the session', () async {
      final session = await signInTestUser(client);
      await pumpEventQueue();
      events.clear();

      await expectLater(
        client.linkIdentityWithIdToken(
          provider: OAuthProvider.google,
          idToken: 'id-token',
        ),
        throwsSessionMissing,
      );
      await pumpEventQueue();

      expect(client.currentSession?.accessToken, session.accessToken);
      expect(events, isEmpty);
    });

    test(
      'makes passkey.verifyAuthentication throw without signing in',
      () async {
        await expectLater(
          client.passkey.verifyAuthentication(
            challengeId: 'challenge-id',
            credential: {'id': 'credential-id'},
          ),
          throwsSessionMissing,
        );
        await pumpEventQueue();

        expectNothingSignedIn();
      },
    );

    test('makes exchangeCodeForSession throw without signing in', () async {
      final flow = await client.getOAuthSignInUrl(
        provider: OAuthProvider.google,
      );

      await expectLater(
        client.exchangeCodeForSession('auth-code', flowId: flow.flowId),
        throwsSessionMissing,
      );
      await pumpEventQueue();

      expectNothingSignedIn();
    });

    test('makes refreshSession throw and sign out', () async {
      await signInTestUser(client);
      final signedOut = client.onAuthStateChange.firstWhere(
        (state) => state is AuthSignedOut,
      );

      await expectLater(client.refreshSession(), throwsSessionMissing);

      expect(
        await signedOut,
        isA<AuthSignedOut>().having(
          (state) => state.reason,
          'reason',
          SignOutReason.sessionExpired,
        ),
      );
      expect(client.currentSession, isNull);
    });
  });

  test('a token response with a malformed session throws a retryable '
      'exception', () async {
    final httpClient = MockSupabaseHttpClient()
      ..stub({'access_token': 'token', 'token_type': 'bearer'});
    final client = AuthClient(
      url: 'http://localhost:9999',
      httpClient: httpClient,
      autoRefreshToken: false,
      asyncStorage: TestAsyncStorage(),
    );
    addTearDown(client.dispose);

    await expectLater(
      client.signInWithPassword(email: 'fake1@email.com', password: 'password'),
      throwsA(
        isA<AuthRetryableFetchException>().having(
          (error) => error.cause,
          'cause',
          isA<FormatException>(),
        ),
      ),
    );
    expect(client.currentSession, isNull);
  });

  group('a token response', () {
    late MockSupabaseHttpClient httpClient;
    late AuthClient client;

    setUp(() {
      httpClient = MockSupabaseHttpClient();
      client = AuthClient(
        url: 'http://localhost:9999',
        httpClient: httpClient,
        autoRefreshToken: false,
        asyncStorage: TestAsyncStorage(),
      );
    });

    tearDown(() {
      client.dispose();
    });

    Future<Session> signIn() => client.signInWithPassword(
      email: 'fake1@email.com',
      password: 'password',
    );

    test(
      'with a field of the wrong type throws a retryable exception',
      () async {
        httpClient.stub({
          ...testSessionResponseJson(
            accessToken: unsignedTestJwt({'sub': testUserId}),
          ),
          'token_type': 1,
        });

        await expectLater(
          signIn(),
          throwsA(
            isA<AuthRetryableFetchException>().having(
              (error) => error.cause,
              'cause',
              isA<FormatException>(),
            ),
          ),
        );
        expect(client.currentSession, isNull);
      },
    );

    test('that is not an object throws a retryable exception', () async {
      httpClient.stub(['not', 'a', 'session']);

      await expectLater(
        signIn(),
        throwsA(
          isA<AuthRetryableFetchException>().having(
            (error) => error.cause,
            'cause',
            isA<FormatException>(),
          ),
        ),
      );
    });

    test('with a malformed user throws a retryable exception', () async {
      httpClient.stub(
        testSessionResponseJson(
          accessToken: unsignedTestJwt({'sub': testUserId}),
          user: {
            ...testUserJson(),
            'factors': [1],
          },
        ),
      );

      await expectLater(
        signIn(),
        throwsA(
          isA<AuthRetryableFetchException>().having(
            (error) => error.cause,
            'cause',
            isA<FormatException>(),
          ),
        ),
      );
      expect(client.currentSession, isNull);
    });
  });
}
