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

  Future<AuthClient> initializeApp({
    LocalStorage localStorage = const MockEmptyLocalStorage(),
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: localStorage,
        pkceAsyncStorage: MockAsyncStorage(),
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
        pkceAsyncStorage: MockAsyncStorage(),
        persistSession: persistSession,
      ),
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

  test('a sign-in in the app does not reach a standalone client', () async {
    final appAuth = await initializeApp();
    final serviceClient = createClient('service-role-key');

    final broadcasts = collectBroadcasts(serviceClient.auth);
    await signInTestUser(appAuth);

    expect(await broadcasts, isEmpty);
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
    final appAuth = await initializeApp(
      localStorage: const EmptyLocalStorage(),
    );
    final otherClient = createClient(supabaseKey, persistSession: true);

    final broadcasts = collectBroadcasts(otherClient.auth);
    await signInTestUser(appAuth);

    expect(await broadcasts, isEmpty);
    expect(otherClient.auth.currentSession, isNull);
  });
}
