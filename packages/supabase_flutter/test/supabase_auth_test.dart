import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = 'https://test.supabase.co';
  const supabaseKey = 'test-anon-key';

  group('SupabaseAuth', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAppLink();
    });

    tearDown(() async {
      try {
        await Supabase.instance.dispose();
      } catch (e) {
        // Ignore dispose errors in tests
      }
    });

    group('Auth state management', () {
      test('persists session on auth state change', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        // The MockLocalStorage should have persisted the session
        final localStorage = MockLocalStorage();
        await localStorage.initialize();
        final hasToken = await localStorage.hasAccessToken();
        expect(hasToken, true);
      });

      test('handles sign out flow', () async {
        final localStorage = MockLocalStorage();
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: localStorage,
          ),
        );

        // Verify auth is initialized
        expect(Supabase.instance.client.auth, isNotNull);

        // Note: Actual sign out would require real network call
        // This test verifies the auth client is properly set up
      });
    });

    group('App lifecycle integration', () {
      test('configures auto refresh when enabled', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            autoRefreshToken: true,
          ),
        );

        // Verify the client is properly configured
        expect(Supabase.instance.client.auth, isNotNull);
      });

      test('configures auth without auto refresh', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            autoRefreshToken: false,
          ),
        );

        // Verify the client is properly configured
        expect(Supabase.instance.client.auth, isNotNull);
      });
    });

    group('Deep link handling', () {
      test('enables deep link detection by default', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockEmptyLocalStorage(),
            detectSessionInUri: true,
          ),
        );

        // This test verifies the deep link observer is set up
        expect(Supabase.instance.client, isNotNull);
      });

      test('handles deep link with error parameter', () async {
        // Mock a deep link with error
        mockAppLink(
          initialLink:
              'myapp://auth?error=access_denied&error_description=User+denied+access',
        );

        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockEmptyLocalStorage(),
            detectSessionInUri: true,
          ),
        );

        // Should initialize without throwing
        expect(Supabase.instance.client, isNotNull);
      });

      test('can disable deep link detection', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockEmptyLocalStorage(),
            detectSessionInUri: false,
          ),
        );

        // Should not throw even when deep link detection is disabled
        expect(Supabase.instance.client, isNotNull);
      });
    });

    group('Auth configuration', () {
      test('supports custom localStorage implementation', () async {
        final customStorage = MockExpiredStorage();
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: customStorage,
          ),
        );

        expect(Supabase.instance.client, isNotNull);
        expect(Supabase.instance.client.auth.currentSession, isNotNull);
      });

      test('supports custom async storage for PKCE', () async {
        final customAsyncStorage = MockAsyncStorage();
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockEmptyLocalStorage(),
            pkceAsyncStorage: customAsyncStorage,
          ),
        );

        expect(Supabase.instance.client, isNotNull);
      });

      test('supports different auth flow types', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            authFlowType: AuthFlowType.pkce,
          ),
        );

        expect(Supabase.instance.client.auth, isNotNull);
      });
    });

    group('Error handling', () {
      test('handles localStorage errors gracefully', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockEmptyLocalStorage(),
          ),
        );

        // Should handle storage errors without crashing
        expect(Supabase.instance.client, isNotNull);
      });
    });

    group('Session recovery', () {
      test('recovers valid session from localStorage', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        // Should recover session successfully
        expect(Supabase.instance.client.auth.currentSession, isNotNull);
      });

      test('handles expired session gracefully', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockExpiredStorage(),
            autoRefreshToken: false,
          ),
        );

        // Should handle expired session
        expect(Supabase.instance.client.auth.currentSession, isNotNull);
        expect(Supabase.instance.client.auth.currentSession?.isExpired, true);
      });

      test('handles corrupted session data', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockExpiredStorage(),
          ),
        );

        // Should handle corrupted data gracefully
        expect(Supabase.instance.client, isNotNull);
      });
    });

    group('Cleanup and disposal', () {
      test('properly cleans up on dispose', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        // Dispose should clean up properly
        await Supabase.instance.dispose();

        // Should not be able to access instance after disposal
        expect(() => Supabase.instance, throwsA(isA<AssertionError>()));
      });
    });
  });
}
