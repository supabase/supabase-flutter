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

    test('makes linkIdentityWithIdToken throw without signing in', () async {
      await expectLater(
        client.linkIdentityWithIdToken(
          provider: OAuthProvider.google,
          idToken: 'id-token',
        ),
        throwsSessionMissing,
      );
      await pumpEventQueue();

      expectNothingSignedIn();
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
}
