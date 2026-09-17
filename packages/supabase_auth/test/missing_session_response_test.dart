import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('a token response without a session', () {
    late MockSupabaseHttpClient httpClient;
    late AuthClient client;
    late List<AuthChangeEvent> events;

    setUp(() async {
      httpClient = MockSupabaseHttpClient()..stub(testUserJson());
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

    test('makes signInWithPassword throw without signing in', () async {
      await expectLater(
        client.signInWithPassword(
          email: 'fake1@email.com',
          password: 'password',
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            'The server response did not contain a session.',
          ),
        ),
      );
      await pumpEventQueue();

      expectNothingSignedIn();
    });

    test('makes signInAnonymously throw without signing in', () async {
      await expectLater(
        client.signInAnonymously(),
        throwsA(isA<AuthException>()),
      );
      await pumpEventQueue();

      expectNothingSignedIn();
    });

    test('makes signInWithIdToken throw without signing in', () async {
      await expectLater(
        client.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: 'id-token',
        ),
        throwsA(isA<AuthException>()),
      );
      await pumpEventQueue();

      expectNothingSignedIn();
    });
  });
}
