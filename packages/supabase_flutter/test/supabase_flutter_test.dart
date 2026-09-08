import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';
import 'widget_test_stubs.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';
  tearDown(() async => await Supabase.instance.dispose());

  group("Initialize", () {
    setUp(() async {
      mockAppLink();
      // Initialize the Supabase singleton
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage.withSession(
            DateTime.now().add(const Duration(hours: 1)),
          ),
        ),
      );
    });

    test('can access Supabase singleton', () {
      final supabase = Supabase.instance.client;

      expect(supabase, same(Supabase.instance.client));
    });

    test('can re-initialize client', () async {
      final supabase = Supabase.instance.client;
      await Supabase.instance.dispose();
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage.withSession(
            DateTime.now().add(const Duration(hours: 1)),
          ),
        ),
      );

      final newClient = Supabase.instance.client;
      expect(supabase, isNot(newClient));
    });
  });

  test('with custom access token', () async {
    final supabase = await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseUrl,
      authOptions: FlutterAuthClientOptions(
        asyncStorage: MockAsyncStorage.withSession(
          DateTime.now().add(const Duration(hours: 1)),
        ),
      ),
      accessToken: () async => 'my-access-token',
    );

    expect(() => supabase.client.auth, throwsA(isA<AuthException>()));
  });

  group("Expired session", () {
    setUp(() async {
      mockAppLink();
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage.withSession(
            DateTime.now().subtract(const Duration(hours: 1)),
          ),
          autoRefreshToken: false,
        ),
      );
    });

    test('emits exception when no auto refresh', () async {
      // The session recovery emits a `signedOut` event before the failure
      // reaches the stream, and the subject replays only the latest event,
      // so skip past any data events until the error arrives.
      await expectLater(
        Supabase.instance.client.auth.onAuthStateChange,
        emitsThrough(emitsError(isA<AuthException>())),
      );
    });
  });

  group("No session", () {
    setUp(() async {
      mockAppLink();
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage(),
        ),
      );
    });

    test('initial session contains the error', () async {
      final event = await Supabase.instance.client.auth.onAuthStateChange.first;
      expect(event.event, AuthChangeEvent.initialSession);
      expect(event.session, isNull);
    });
  });

  group('Without session persistence', () {
    late MockAsyncStorage storage;

    setUp(() async {
      mockAppLink();
      storage = MockAsyncStorage();
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: storage,
          persistSession: false,
        ),
      );
    });

    test('emits a null initial session', () async {
      final event = await Supabase.instance.client.auth.onAuthStateChange.first;
      expect(event.event, AuthChangeEvent.initialSession);
      expect(event.session, isNull);
    });

    test('does not restore a session from the storage', () async {
      await Supabase.instance.dispose();
      await storage.setItem(
        defaultPersistSessionKey(supabaseUrl),
        getSessionData(
          DateTime.now().add(const Duration(hours: 1)),
        ).sessionString,
      );

      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: storage,
          persistSession: false,
        ),
      );

      expect(Supabase.instance.client.auth.currentSession, isNull);
    });
  });
}
