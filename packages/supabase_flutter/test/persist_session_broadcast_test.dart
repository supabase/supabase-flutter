@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';
import 'widget_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = 'https://project.supabase.co';
  const supabaseKey = 'publishable-key';

  late Session session;

  setUp(() {
    mockSharedPreferences();
    mockAppLink();
    session = Session.fromJson(
      json.decode(
        getSessionData(
          DateTime.now().add(const Duration(hours: 1)),
        ).sessionString,
      ),
    )!;
  });

  tearDown(() async {
    try {
      await Supabase.instance.dispose();
    } catch (_) {
      // Ignore dispose errors
    }
  });

  Future<void> initializeApp() => Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: const MockEmptyLocalStorage(),
      pkceAsyncStorage: MockAsyncStorage(),
    ),
  );

  Future<List<AuthState>> collectBroadcasts(AuthClient auth) async {
    final broadcasts = <AuthState>[];
    final subscription = auth.onAuthStateChange
        .where((state) => state.fromBroadcast)
        .listen(broadcasts.add);
    // Give a message that would have been delivered time to arrive.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await subscription.cancel();
    return broadcasts;
  }

  test('a sign-in in the app does not reach a standalone client', () async {
    await initializeApp();
    final serviceClient = SupabaseClient(
      supabaseUrl,
      'service-role-key',
      authOptions: AuthClientOptions(pkceAsyncStorage: MockAsyncStorage()),
    );
    addTearDown(serviceClient.dispose);

    final broadcasts = collectBroadcasts(serviceClient.auth);
    Supabase.instance.client.auth
    // ignore: invalid_use_of_internal_member
    .notifyAllSubscribers(AuthChangeEvent.signedIn, session: session);

    expect(await broadcasts, isEmpty);
    expect(serviceClient.auth.currentSession, isNull);
  });

  test('a sign-in in the app reaches a client that persists too', () async {
    await initializeApp();
    final otherClient = SupabaseClient(
      supabaseUrl,
      supabaseKey,
      authOptions: AuthClientOptions(
        pkceAsyncStorage: MockAsyncStorage(),
        persistSession: true,
      ),
    );
    addTearDown(otherClient.dispose);

    final broadcasts = collectBroadcasts(otherClient.auth);
    Supabase.instance.client.auth
    // ignore: invalid_use_of_internal_member
    .notifyAllSubscribers(AuthChangeEvent.signedIn, session: session);

    expect(
      (await broadcasts).map((state) => state.event),
      [AuthChangeEvent.signedIn],
    );
    expect(otherClient.auth.currentSession?.accessToken, session.accessToken);
  });
}
