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
        publishableKey: supabaseKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: const MockLocalStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
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
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: const MockLocalStorage(),
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
      publishableKey: supabaseUrl,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        localStorage: const MockLocalStorage(),
        pkceAsyncStorage: MockAsyncStorage(),
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
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: const MockExpiredStorage(),
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

  group("Expired session with autoRefresh — regression #1372", () {
    // Regression test for https://github.com/supabase/supabase-flutter/issues/1372
    //
    // When the backend is unavailable and a session recovery refresh fails,
    // the AuthRetryableFetchException must NOT escape as an unhandled zone
    // exception. It must be silently suppressed or surfaced only through the
    // onAuthStateChange stream (so callers with onError: can handle it).
    setUp(() async {
      mockAppLink();
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: const MockExpiredStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
          // autoRefreshToken: true triggers _callRefreshToken which throws
          // AuthRetryableFetchException when the backend is unavailable.
          autoRefreshToken: true,
        ),
      );
    });

    test(
        'does not leak unhandled exception — '
        'error is only routed through onAuthStateChange stream', () async {
      final errors = <Object>[];

      // The user's stream listener with onError – mirrors the minimal
      // reproduction from issue #1372.
      final sub = Supabase.instance.client.auth.onAuthStateChange.listen(
        (_) {},
        onError: (Object err, StackTrace _) => errors.add(err),
      );

      // Wait long enough for the session recovery / refresh attempt to
      // complete and any potential zone error to propagate.
      await Future.delayed(const Duration(milliseconds: 300));

      await sub.cancel();

      // The error must have been surfaced via the stream, not as an
      // unhandled zone exception (which would have failed the test).
      // Verify at least one AuthException was routed through the stream.
      expect(errors, isNotEmpty,
          reason:
              'Expected the refresh failure to be surfaced through the stream');
      expect(errors.first, isA<AuthException>());
    });
  });

  group("No session", () {
    setUp(() async {
      mockAppLink();
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: const MockEmptyLocalStorage(),
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
        publishableKey: supabaseKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: localStorage,
          pkceAsyncStorage: MockAsyncStorage(),
        ),
      );
    });

    test('all methods work together in a typical flow', () async {
      // Initialize the storage
      await localStorage.initialize();

      // Check if there's a token (should be false)
      final hasToken = await localStorage.hasAccessToken();
      expect(hasToken, isFalse);

      // Get the token (should be null)
      final token = await localStorage.accessToken();
      expect(token, null);

      // Try to persist a session
      await localStorage.persistSession('test-session-data');

      // Check if there's a token after persisting (should still be false)
      final hasTokenAfterPersist = await localStorage.hasAccessToken();
      expect(hasTokenAfterPersist, isFalse);

      // Get the token after persisting (should still be null)
      final tokenAfterPersist = await localStorage.accessToken();
      expect(tokenAfterPersist, null);

      // Try to remove the session
      await localStorage.removePersistedSession();

      // Check if there's a token after removing (should still be false)
      final hasTokenAfterRemove = await localStorage.hasAccessToken();
      expect(hasTokenAfterRemove, isFalse);
    });
  });
}
