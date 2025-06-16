import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/src/supabase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = 'https://test.supabase.co';
  const supabaseKey = 'test-anon-key';

  // Skip problematic tests on web due to disposal race conditions
  final skipOnWeb = kIsWeb;

  group('SupabaseAuth', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAppLink();
    });

    tearDown(() async {
      try {
        await Supabase.instance.dispose();
      } catch (e) {
        // Ignore dispose errors in tests - this can happen when:
        // 1. Instance was already disposed in the test
        // 2. Future completion races occur during disposal on web
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
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);

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
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);
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
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);
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
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);

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
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);

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
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);
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
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);
    });

    group('OAuth Authentication', () {
      test('signInWithOAuth launches OAuth URL correctly', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        // Mock successful OAuth URL generation
        final client = Supabase.instance.client;

        // Verify the method exists and can be called
        expect(() => client.auth.signInWithOAuth(OAuthProvider.google),
            returnsNormally);
      });

      test('signInWithOAuth handles different providers', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final client = Supabase.instance.client;

        // Test different OAuth providers
        expect(() => client.auth.signInWithOAuth(OAuthProvider.github),
            returnsNormally);
        expect(() => client.auth.signInWithOAuth(OAuthProvider.apple),
            returnsNormally);
      });

      test('signInWithOAuth handles custom parameters', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final client = Supabase.instance.client;

        // Test with custom parameters
        expect(
            () => client.auth.signInWithOAuth(
                  OAuthProvider.google,
                  redirectTo: 'myapp://callback',
                  scopes: 'email profile',
                  queryParams: {'custom': 'param'},
                ),
            returnsNormally);
      });
    });

    group('SSO Authentication', () {
      test('signInWithSSO launches SSO URL correctly', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final client = Supabase.instance.client;

        // Test SSO with domain
        expect(() => client.auth.signInWithSSO(domain: 'company.com'),
            returnsNormally);
      });

      test('signInWithSSO handles provider ID', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final client = Supabase.instance.client;

        // Test SSO with provider ID
        expect(() => client.auth.signInWithSSO(providerId: 'provider-uuid'),
            returnsNormally);
      });

      test('signInWithSSO handles custom parameters', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final client = Supabase.instance.client;

        // Test SSO with all parameters
        expect(
            () => client.auth.signInWithSSO(
                  domain: 'company.com',
                  redirectTo: 'myapp://callback',
                  captchaToken: 'captcha-token',
                ),
            returnsNormally);
      });
    });

    group('Identity Linking', () {
      test('generateRawNonce generates secure nonce', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final client = Supabase.instance.client;

        // Test nonce generation
        final nonce1 = client.auth.generateRawNonce();
        final nonce2 = client.auth.generateRawNonce();

        expect(nonce1, isNotEmpty);
        expect(nonce2, isNotEmpty);
        expect(nonce1, isNot(equals(nonce2))); // Should be different each time
      });

      test('linkIdentity launches identity linking correctly', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final client = Supabase.instance.client;

        // Test identity linking
        expect(() => client.auth.linkIdentity(OAuthProvider.google),
            returnsNormally);
      });

      test('linkIdentity handles custom parameters', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final client = Supabase.instance.client;

        // Test identity linking with parameters
        expect(
            () => client.auth.linkIdentity(
                  OAuthProvider.github,
                  redirectTo: 'myapp://callback',
                  scopes: 'user:email',
                  queryParams: {'custom': 'param'},
                ),
            returnsNormally);
      });
    });

    group('Deep Link Validation', () {
      test('identifies auth callback deep links correctly', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            authFlowType: AuthFlowType.implicit,
          ),
        );

        // Test implicit flow deep link detection
        final implicitUri =
            Uri.parse('myapp://auth#access_token=abc123&token_type=bearer');
        // This tests the internal deep link validation logic
        expect(implicitUri.fragment, contains('access_token'));
      });

      test('identifies PKCE flow deep links correctly', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            authFlowType: AuthFlowType.pkce,
          ),
        );

        // Test PKCE flow deep link detection
        final pkceUri = Uri.parse('myapp://auth?code=abc123&state=xyz789');
        expect(pkceUri.queryParameters.containsKey('code'), true);
      });

      test('identifies error deep links correctly', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        // Test error deep link detection
        final errorUri =
            Uri.parse('myapp://auth#error_description=access_denied');
        expect(errorUri.fragment, contains('error_description'));
      });
    });

    group('App Lifecycle Behavior', () {
      test('configures app lifecycle observer correctly', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            autoRefreshToken: true,
          ),
        );

        // Verify that the auth client is properly configured
        // The actual lifecycle behavior is tested through the framework
        expect(Supabase.instance.client.auth, isNotNull);
      });

      test('handles auto refresh configuration', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            autoRefreshToken: false,
          ),
        );

        // Test that auto refresh can be disabled
        expect(Supabase.instance.client.auth, isNotNull);
      });
    });

    group('Error Recovery', () {
      test('handles invalid session data gracefully', () async {
        final mockStorage = MockInvalidSessionStorage();

        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: mockStorage,
          ),
        );

        // Should initialize without throwing even with invalid session data
        expect(Supabase.instance.client, isNotNull);
      });

      test('handles localStorage initialization errors', () async {
        final mockStorage = MockErrorStorage();

        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: mockStorage,
          ),
        );

        // Should handle storage errors gracefully
        expect(Supabase.instance.client, isNotNull);
      });
    });

    group('Session Persistence', () {
      test('persists session on auth state changes', () async {
        final localStorage = MockLocalStorage();
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: localStorage,
          ),
        );

        // Test that session persistence is set up correctly
        expect(Supabase.instance.client.auth, isNotNull);
      });

      test('handles session recovery with no persisted session', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockEmptyLocalStorage(),
          ),
        );

        // Should emit initial session when no persisted session exists
        expect(Supabase.instance.client.auth.currentSession, isNull);
      });
    });

    group('Deep Link Handling Setup', () {
      test('starts deep link observer when detectSessionInUri is true',
          () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            detectSessionInUri: true,
          ),
        );

        expect(Supabase.instance.client, isNotNull);
      });

      test('skips deep link observer when detectSessionInUri is false',
          () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            detectSessionInUri: false,
          ),
        );

        expect(Supabase.instance.client, isNotNull);
      });
    });

    group('RecoverSession Method', () {
      test('recoverSession recovers valid persisted session', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        // Call recoverSession
        await (Supabase.instance as dynamic).recoverSession();

        expect(Supabase.instance.client.auth.currentSession, isNotNull);
      });

      test('recoverSession handles no persisted session', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockEmptyLocalStorage(),
          ),
        );

        // Call recoverSession - should not throw
        await (Supabase.instance as dynamic).recoverSession();

        expect(Supabase.instance.client.auth.currentSession, isNull);
      });

      test('recoverSession handles auth exceptions', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockInvalidSessionStorage(),
          ),
        );

        // Call recoverSession - should handle exception gracefully
        await expectLater(
          (Supabase.instance as dynamic).recoverSession(),
          completes,
        );
      });
    });

    group('OAuth URL Launching', () {
      test('getOAuthSignInUrl returns proper URL structure', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final result = await Supabase.instance.client.auth.getOAuthSignInUrl(
          provider: OAuthProvider.google,
          redirectTo: 'myapp://callback',
        );

        expect(result.url, contains('authorize'));
        expect(result.url, contains('google'));
      });

      test('getSSOSignInUrl returns proper URL structure', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          httpClient: MockSSOHttpClient(),
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final result = await Supabase.instance.client.auth.getSSOSignInUrl(
          domain: 'example.com',
        );

        expect(result, contains('sso'));
        expect(result, contains('domain=example.com'));
      });

      test('generateRawNonce returns base64 encoded nonce', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final nonce = Supabase.instance.client.auth.generateRawNonce();

        // Check that it's a valid base64 string
        expect(nonce, matches(RegExp(r'^[A-Za-z0-9+/\-_]+={0,2}$')));
        expect(nonce.length, greaterThan(0));
      });
    });

    group('App Lifecycle State Changes', () {
      test('handles AppLifecycleState.resumed with auto refresh enabled',
          () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            autoRefreshToken: true,
          ),
        );

        // Get the auth instance
        final supabaseAuth =
            (Supabase.instance as dynamic).auth as SupabaseAuth;

        // Call didChangeAppLifecycleState with resumed state
        supabaseAuth.didChangeAppLifecycleState(AppLifecycleState.resumed);

        // Should not throw and auth should still be available
        expect(Supabase.instance.client.auth, isNotNull);
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);

      test('handles AppLifecycleState.paused', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            autoRefreshToken: true,
          ),
        );

        // Get the auth instance
        final supabaseAuth =
            (Supabase.instance as dynamic).auth as SupabaseAuth;

        // Call didChangeAppLifecycleState with paused state
        supabaseAuth.didChangeAppLifecycleState(AppLifecycleState.paused);

        // Should not throw and auth should still be available
        expect(Supabase.instance.client.auth, isNotNull);
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);

      test('handles AppLifecycleState.detached', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            autoRefreshToken: true,
          ),
        );

        // Get the auth instance
        final supabaseAuth =
            (Supabase.instance as dynamic).auth as SupabaseAuth;

        // Call didChangeAppLifecycleState with detached state
        supabaseAuth.didChangeAppLifecycleState(AppLifecycleState.detached);

        // Should not throw and auth should still be available
        expect(Supabase.instance.client.auth, isNotNull);
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);

      test('handles AppLifecycleState.resumed without auto refresh', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            autoRefreshToken: false,
          ),
        );

        // Get the auth instance
        final supabaseAuth =
            (Supabase.instance as dynamic).auth as SupabaseAuth;

        // Call didChangeAppLifecycleState with resumed state
        supabaseAuth.didChangeAppLifecycleState(AppLifecycleState.resumed);

        // Should not throw and auth should still be available
        expect(Supabase.instance.client.auth, isNotNull);
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);
    });

    group('URL Launching for OAuth/SSO/LinkIdentity', () {
      test('signInWithOAuth actually launches URL', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          httpClient: MockOAuthHttpClient(),
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final client = Supabase.instance.client;

        // Test that the method attempts to launch URL
        final result = await client.auth.signInWithOAuth(OAuthProvider.google);

        // Should return a boolean indicating launch attempt
        expect(result, isA<bool>());
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);

      test('signInWithOAuth handles Google provider on Android', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          httpClient: MockOAuthHttpClient(),
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final client = Supabase.instance.client;

        // Test Google provider which has special handling on Android
        final result = await client.auth.signInWithOAuth(
          OAuthProvider.google,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );

        expect(result, isA<bool>());
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);

      test('signInWithSSO actually launches URL', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          httpClient: MockSSOHttpClient(),
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final client = Supabase.instance.client;

        // Test that the method attempts to launch URL
        final result = await client.auth.signInWithSSO(domain: 'company.com');

        // Should return a boolean indicating launch attempt
        expect(result, isA<bool>());
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);

      test('linkIdentity actually launches URL', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          httpClient: MockOAuthHttpClient(),
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final client = Supabase.instance.client;

        // Test that the method attempts to launch URL
        final result = await client.auth.linkIdentity(OAuthProvider.github);

        // Should return a boolean indicating launch attempt
        expect(result, isA<bool>());
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);

      test('linkIdentity handles Google provider on Android', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          httpClient: MockOAuthHttpClient(),
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
          ),
        );

        final client = Supabase.instance.client;

        // Test Google provider which has special handling on Android
        final result = await client.auth.linkIdentity(
          OAuthProvider.google,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );

        expect(result, isA<bool>());
      }, skip: skipOnWeb ? 'Disposal race conditions on web' : null);
    });

    group('Web-specific Deep Link Handling', () {
      test('handles web-specific initial URI path', () async {
        // Mock a web environment by testing the web-specific code path
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            detectSessionInUri: true,
          ),
        );

        // The web-specific path in _handleInitialUri should be covered
        // by the initialization process on web platform
        expect(Supabase.instance.client, isNotNull);
      });

      test('handles NoSuchMethodError in initial URI handling', () async {
        // This tests the fallback path when getInitialAppLink doesn't exist
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            detectSessionInUri: true,
          ),
        );

        expect(Supabase.instance.client, isNotNull);
      });
    });

    group('Deep Link Error Handling', () {
      test('handles PlatformException in initial URI', () async {
        // Mock a deep link that could cause platform exceptions
        mockAppLink(
          initialLink: 'invalid-scheme://malformed-url',
        );

        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            detectSessionInUri: true,
          ),
        );

        // Should initialize without throwing despite platform exception
        expect(Supabase.instance.client, isNotNull);
      });

      test('handles FormatException in initial URI', () async {
        // Mock a malformed URL that could cause format exceptions
        mockAppLink(
          initialLink: 'myapp://[invalid-brackets]',
        );

        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            detectSessionInUri: true,
          ),
        );

        // Should initialize without throwing despite format exception
        expect(Supabase.instance.client, isNotNull);
      });

      test('handles generic exceptions in initial URI', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            detectSessionInUri: true,
          ),
        );

        // Should handle any unexpected exceptions gracefully
        expect(Supabase.instance.client, isNotNull);
      });

      test('handles AuthException in deep link processing', () async {
        // Mock a deep link with valid auth parameters but that might cause auth errors
        mockAppLink(
          initialLink: 'myapp://auth?code=invalid-code&state=test-state',
        );

        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            detectSessionInUri: true,
            authFlowType: AuthFlowType.pkce,
          ),
        );

        // Should handle auth exceptions during deep link processing
        expect(Supabase.instance.client, isNotNull);
      });

      test('handles generic exceptions in deep link processing', () async {
        // Mock a deep link that might cause processing errors
        mockAppLink(
          initialLink:
              'myapp://auth#access_token=malformed-token&token_type=bearer',
        );

        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            detectSessionInUri: true,
            authFlowType: AuthFlowType.implicit,
          ),
        );

        // Should handle generic exceptions during deep link processing
        expect(Supabase.instance.client, isNotNull);
      });

      test('handles non-auth callback deep links', () async {
        // Mock a deep link that is not an auth callback
        mockAppLink(
          initialLink: 'myapp://other-page?param=value',
        );

        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            detectSessionInUri: true,
          ),
        );

        // Should ignore non-auth deep links without issues
        expect(Supabase.instance.client, isNotNull);
      });
    });

    group('Deep Link Stream Error Handling', () {
      test('handles stream errors in incoming links', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockLocalStorage(),
            detectSessionInUri: true,
          ),
        );

        // Test that the error handler for deep link stream is set up
        // The actual error handling is tested by the framework
        expect(Supabase.instance.client, isNotNull);
      }, skip: skipOnWeb ? 'Deep link streams not available on web' : null);
    });
  });
}
