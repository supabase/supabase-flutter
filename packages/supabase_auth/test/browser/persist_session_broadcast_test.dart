@TestOn('browser')
library;

import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_testing/supabase_testing.dart';
import 'package:test/test.dart';

void main() {
  const url = 'https://project.supabase.co/auth/v1';

  AuthClient createClient({required bool persistSession}) {
    final client = AuthClient(
      url: url,
      autoRefreshToken: false,
      asyncStorage: MemoryAuthAsyncStorage(),
      persistSession: persistSession,
    );
    addTearDown(client.dispose);
    return client;
  }

  /// Runs [act] while listening for broadcasts on [auth], then gives a
  /// message that [act] may have caused time to arrive.
  Future<List<AuthState>> collectBroadcasts(
    AuthClient auth,
    Future<void> Function() act,
  ) async {
    final broadcasts = <AuthState>[];
    final subscription = auth.onAuthStateChange
        .where((state) => state.fromBroadcast)
        .listen(broadcasts.add);
    await act();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await subscription.cancel();
    return broadcasts;
  }

  test('a persisted session reaches the other persisting clients', () async {
    final sender = createClient(persistSession: true);
    final receiver = createClient(persistSession: true);

    final received = receiver.onAuthStateChange
        .firstWhere((state) => state.fromBroadcast)
        .timeout(const Duration(seconds: 5));
    final session = await signInTestUser(sender);

    final state = await received;
    expect(state.event, AuthChangeEvent.tokenRefreshed);
    expect(state.session?.accessToken, session.accessToken);
    expect(receiver.currentSession?.accessToken, session.accessToken);
  });

  test('a client without a persisted session is left alone', () async {
    final sender = createClient(persistSession: true);
    final bystander = createClient(persistSession: false);

    final broadcasts = await collectBroadcasts(
      bystander,
      () => signInTestUser(sender),
    );

    expect(broadcasts, isEmpty);
    expect(bystander.currentSession, isNull);
  });

  test('a client without a persisted session does not broadcast', () async {
    final sender = createClient(persistSession: false);
    final receiver = createClient(persistSession: true);

    final broadcasts = await collectBroadcasts(
      receiver,
      () => signInTestUser(sender),
    );

    expect(broadcasts, isEmpty);
    expect(receiver.currentSession, isNull);
  });
}
