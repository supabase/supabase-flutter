import 'package:app_links/app_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        anonKey: supabaseKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: MockLocalStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
        ),
      );
    });

    test('can access Supabase singleton', () async {
      final supabase = Supabase.instance.client;

      expect(supabase, isNotNull);
    });

    test('can re-initialize client', () async {
      final supabase = Supabase.instance.client;
      await Supabase.instance.dispose();
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: MockLocalStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
        ),
      );

      final newClient = Supabase.instance.client;
      expect(supabase, isNot(newClient));
    });
  });

  test('with custom access token', () async {
    final supabase = await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseUrl,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        localStorage: MockLocalStorage(),
        pkceAsyncStorage: MockAsyncStorage(),
      ),
      accessToken: () async => 'my-access-token',
    );

    // print(supabase.client.auth.runtimeType);

    void accessAuth() {
      supabase.client.auth;
    }

    expect(accessAuth, throwsA(isA<AuthException>()));
  });

  group("Expired session", () {
    setUp(() async {
      mockAppLink();
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: MockExpiredStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
          autoRefreshToken: false,
        ),
      );
    });

    test('emits exception when no auto refresh', () async {
      // Give it a delay to wait for recoverSession to throw
      await Future.delayed(const Duration(milliseconds: 100));

      await expectLater(Supabase.instance.client.auth.onAuthStateChange,
          emitsError(isA<AuthException>()));
    });
  });

  group("No session", () {
    setUp(() async {
      mockAppLink();
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: MockEmptyLocalStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
        ),
      );
    });

    test('initial session contains the error', () async {
      final event = await Supabase.instance.client.auth.onAuthStateChange.first;
      expect(event.event, AuthChangeEvent.initialSession);
      expect(event.session, isNull);
    });
  });

  group('EmptyLocalStorage', () {
    late EmptyLocalStorage localStorage;

    setUp(() async {
      mockAppLink();

      localStorage = const EmptyLocalStorage();
      // Initialize the Supabase singleton
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: localStorage,
          pkceAsyncStorage: MockAsyncStorage(),
        ),
      );
    });

    test('initialize does nothing', () async {
      // Should not throw any exceptions
      await localStorage.initialize();
    });

    test('hasAccessToken returns false', () async {
      final result = await localStorage.hasAccessToken();
      expect(result, false);
    });

    test('accessToken returns null', () async {
      final result = await localStorage.accessToken();
      expect(result, null);
    });

    test('removePersistedSession does nothing', () async {
      // Should not throw any exceptions
      await localStorage.removePersistedSession();
    });

    test('persistSession does nothing', () async {
      // Should not throw any exceptions
      await localStorage.persistSession('test-session-string');
    });

    test('all methods work together in a typical flow', () async {
      // Initialize the storage
      await localStorage.initialize();

      // Check if there's a token (should be false)
      final hasToken = await localStorage.hasAccessToken();
      expect(hasToken, false);

      // Get the token (should be null)
      final token = await localStorage.accessToken();
      expect(token, null);

      // Try to persist a session
      await localStorage.persistSession('test-session-data');

      // Check if there's a token after persisting (should still be false)
      final hasTokenAfterPersist = await localStorage.hasAccessToken();
      expect(hasTokenAfterPersist, false);

      // Get the token after persisting (should still be null)
      final tokenAfterPersist = await localStorage.accessToken();
      expect(tokenAfterPersist, null);

      // Try to remove the session
      await localStorage.removePersistedSession();

      // Check if there's a token after removing (should still be false)
      final hasTokenAfterRemove = await localStorage.hasAccessToken();
      expect(hasTokenAfterRemove, false);
    });
  });
}
