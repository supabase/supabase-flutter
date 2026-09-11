@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';
import 'widget_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = 'https://project.supabase.co';
  const supabaseKey = 'publishable-key';

  tearDown(() => Supabase.instance.dispose());

  Future<AuthClient> initializeApp({bool persistSession = true}) async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
      authOptions: FlutterAuthClientOptions(
        asyncStorage: MockAsyncStorage(),
        persistSession: persistSession,
        detectSessionInUri: false,
      ),
    );
    return Supabase.instance.client.auth;
  }

  SupabaseClient createClient(String key, {bool persistSession = false}) {
    final client = SupabaseClient(
      supabaseUrl,
      key,
      authOptions: AuthClientOptions(
        asyncStorage: MockAsyncStorage(),
        persistSession: persistSession,
      ),
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

  test('a sign-in in the app does not reach a standalone client', () async {
    final appAuth = await initializeApp();
    final serviceClient = createClient('service-role-key');

    final broadcasts = await collectBroadcasts(
      serviceClient.auth,
      () => signInTestUser(appAuth),
    );

    expect(broadcasts, isEmpty);
    expect(serviceClient.auth.currentSession, isNull);
  });

  test('a sign-in in the app reaches a client that persists too', () async {
    final appAuth = await initializeApp();
    final otherClient = createClient(supabaseKey, persistSession: true);

    final received = otherClient.auth.onAuthStateChange
        .firstWhere((state) => state.fromBroadcast)
        .timeout(const Duration(seconds: 5));
    final session = await signInTestUser(appAuth);

    final state = await received;
    expect(state.event, AuthChangeEvent.tokenRefreshed);
    expect(otherClient.auth.currentSession?.accessToken, session.accessToken);
  });

  test('an app that keeps the session in memory does not broadcast', () async {
    final appAuth = await initializeApp(persistSession: false);
    final otherClient = createClient(supabaseKey, persistSession: true);

    final broadcasts = await collectBroadcasts(
      otherClient.auth,
      () => signInTestUser(appAuth),
    );

    expect(broadcasts, isEmpty);
    expect(otherClient.auth.currentSession, isNull);
  });
}
