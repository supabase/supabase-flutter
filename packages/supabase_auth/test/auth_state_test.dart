import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// Exhaustive over the sealed hierarchy, so a new subtype fails to compile
/// here until it is handled.
String describe(AuthState state) => switch (state) {
  AuthInitialSession(session: null) => 'initial, signed out',
  AuthInitialSession(session: final session?) => 'initial ${session.user.id}',
  AuthSignedIn(:final session) => 'signed in ${session.user.id}',
  AuthSignedOut(:final reason) => 'signed out ${reason?.name}',
  AuthTokenRefreshed(:final session) => 'refreshed ${session.user.id}',
  AuthUserUpdated(:final session) => 'updated ${session.user.id}',
  AuthPasswordRecovery(:final session) => 'recovery ${session.user.id}',
  AuthMfaChallengeVerified(:final session) => 'mfa ${session.user.id}',
};

void main() {
  group('AuthState', () {
    late MockSupabaseHttpClient httpClient;
    late AuthClient client;
    late List<AuthState> states;

    Future<Session> signIn() => client.signInWithPassword(
      email: 'fake1@email.com',
      password: 'password',
    );

    setUp(() async {
      httpClient = MockSupabaseHttpClient()
        ..stubSignIn()
        ..stubSignOut()
        ..stubUser();
      client = AuthClient(
        url: 'http://localhost:9999',
        httpClient: httpClient,
        autoRefreshToken: false,
        asyncStorage: TestAsyncStorage(),
      );
      states = [];
      client.onAuthStateChange.listen(states.add, onError: (_) {});
      await pumpEventQueue();
    });

    tearDown(() {
      client.dispose();
    });

    test('the first event is an AuthInitialSession without a session', () {
      expect(states, hasLength(1));
      expect(
        states.single,
        isA<AuthInitialSession>()
            .having((state) => state.session, 'session', isNull)
            .having(
              (state) => state.event,
              'event',
              AuthChangeEvent.initialSession,
            ),
      );
      expect(describe(states.single), 'initial, signed out');
    });

    test('signing in emits an AuthSignedIn carrying the new session', () async {
      final session = await signIn();
      await pumpEventQueue();

      expect(
        states.last,
        isA<AuthSignedIn>()
            .having((state) => state.session, 'session', session)
            .having((state) => state.event, 'event', AuthChangeEvent.signedIn)
            .having((state) => state.fromBroadcast, 'fromBroadcast', isFalse),
      );
      expect(describe(states.last), 'signed in $testUserId');
    });

    test(
      'refreshing emits an AuthTokenRefreshed carrying the refreshed session',
      () async {
        await signIn();
        final refreshed = await client.refreshSession();
        await pumpEventQueue();

        expect(
          states.last,
          isA<AuthTokenRefreshed>()
              .having((state) => state.session, 'session', refreshed)
              .having(
                (state) => state.event,
                'event',
                AuthChangeEvent.tokenRefreshed,
              ),
        );
      },
    );

    test(
      'updating the user emits an AuthUserUpdated carrying the session',
      () async {
        await signIn();
        await client.updateUser(UserAttributes(data: {'name': 'Alice'}));
        await pumpEventQueue();

        expect(
          states.last,
          isA<AuthUserUpdated>()
              .having(
                (state) => state.session,
                'session',
                client.currentSession,
              )
              .having(
                (state) => state.event,
                'event',
                AuthChangeEvent.userUpdated,
              ),
        );
      },
    );

    test('signing out emits an AuthSignedOut with the reason', () async {
      await signIn();
      await client.signOut();
      await pumpEventQueue();

      expect(
        states.last,
        isA<AuthSignedOut>()
            .having((state) => state.session, 'session', isNull)
            .having(
              (state) => state.reason,
              'reason',
              SignOutReason.userInitiated,
            )
            .having((state) => state.event, 'event', AuthChangeEvent.signedOut),
      );
      expect(describe(states.last), 'signed out userInitiated');
    });

    test('a signedIn event without a session is not emitted', () async {
      client.notifyAllSubscribers(AuthChangeEvent.signedIn, broadcast: false);
      await pumpEventQueue();

      expect(states, hasLength(1));
      expect(states.single, isA<AuthInitialSession>());
    });

    test(
      'an event received from another tab is marked fromBroadcast',
      () async {
        final session = await signIn();
        client.notifyAllSubscribers(
          AuthChangeEvent.tokenRefreshed,
          session: session,
          broadcast: false,
        );
        await pumpEventQueue();

        expect(
          states.last,
          isA<AuthTokenRefreshed>()
              .having((state) => state.session, 'session', session)
              .having((state) => state.fromBroadcast, 'fromBroadcast', isTrue),
        );
      },
    );

    test(
      'a late subscriber gets the current session as AuthInitialSession',
      () async {
        final session = await signIn();

        final first = await client.onAuthStateChange.first;

        expect(
          first,
          isA<AuthInitialSession>().having(
            (state) => state.session,
            'session',
            session,
          ),
        );
        expect(describe(first), 'initial $testUserId');
      },
    );
  });
}
