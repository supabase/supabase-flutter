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

  Future<List<AuthState>> collectBroadcasts(AuthClient auth) async {
    final broadcasts = <AuthState>[];
    final subscription = auth.onAuthStateChange
        .where((state) => state.fromBroadcast)
        .listen(broadcasts.add);
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

    final broadcasts = collectBroadcasts(bystander);
    await signInTestUser(sender);

    expect(await broadcasts, isEmpty);
    expect(bystander.currentSession, isNull);
  });

  test('a client without a persisted session does not broadcast', () async {
    final sender = createClient(persistSession: false);
    final receiver = createClient(persistSession: true);

    final broadcasts = collectBroadcasts(receiver);
    await signInTestUser(sender);

    expect(await broadcasts, isEmpty);
    expect(receiver.currentSession, isNull);
  });
}
