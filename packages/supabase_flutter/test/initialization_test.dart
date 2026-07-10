import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = '';
  const supabaseKey = '';

  setUpAll(() {
    debugPrint = (String? message, {int? wrapWidth}) {};
  });

  group('Supabase initialization', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAppLink();
    });

    tearDown(() async {
      try {
        await Supabase.instance.dispose();
      } catch (_) {
        // Ignore dispose errors
      }
    });

    group('Basic initialization', () {
      test('initialize successfully with default options', () {
        expect(
          Supabase.initialize(
            url: supabaseUrl,
            publishableKey: supabaseKey,
            debug: false,
          ),
          completes,
        );
      });
    });

    group('Custom storage initialization', () {
      test('initialize successfully with custom localStorage', () {
        const localStorage = MockLocalStorage();
        expect(
          Supabase.initialize(
            url: supabaseUrl,
            publishableKey: supabaseKey,
            debug: false,
            authOptions: const FlutterAuthClientOptions(
              localStorage: localStorage,
            ),
          ),
          completes,
        );
      });

      test('handles initialization with expired session in storage', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          debug: true,
          authOptions: FlutterAuthClientOptions(
            localStorage: const MockExpiredStorage(),
            pkceAsyncStorage: MockAsyncStorage(),
          ),
        );

        // Should handle expired session gracefully
        expect(Supabase.instance.client.auth.currentSession, isNotNull);
      });
    });

    group('Auth options initialization', () {
      test('initialize successfully with PKCE auth flow', () {
        expect(
          Supabase.initialize(
            url: supabaseUrl,
            publishableKey: supabaseKey,
            debug: false,
            authOptions: const FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
            ),
          ),
          completes,
        );
      });
    });

    group('Custom client initialization', () {
      test('initialize successfully with custom HTTP client', () {
        final httpClient = PkceHttpClient();
        expect(
          Supabase.initialize(
            url: supabaseUrl,
            publishableKey: supabaseKey,
            debug: false,
            httpClient: httpClient,
          ),
          completes,
        );
      });

      test('initialize successfully with custom access token', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          debug: false,
          accessToken: () async => 'custom-access-token',
        );

        // Should throw AuthException when trying to access auth
        expect(
          () => Supabase.instance.client.auth,
          throwsA(isA<AuthException>()),
        );
      });
    });

    group('Multiple initialization and disposal', () {
      test('dispose and reinitialize works', () async {
        // First initialization
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          debug: false,
        );

        // Dispose
        await Supabase.instance.dispose();

        // Need to run the event loop to let the dispose complete
        await Future.delayed(Duration.zero);

        // Re-initialize should work without errors
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          debug: false,
        );
      });

      test('handles multiple initializations correctly', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          debug: false,
          authOptions: FlutterAuthClientOptions(
            localStorage: const MockLocalStorage(),
            pkceAsyncStorage: MockAsyncStorage(),
          ),
        );

        // Store first instance to verify it's different after re-initialization
        final firstInstance = Supabase.instance.client;

        // Dispose first instance before re-initializing
        await Supabase.instance.dispose();

        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          debug: true,
          authOptions: FlutterAuthClientOptions(
            localStorage: const MockEmptyLocalStorage(),
            pkceAsyncStorage: MockAsyncStorage(),
          ),
        );

        final secondInstance = Supabase.instance.client;
        expect(identical(firstInstance, secondInstance), isFalse);
      });
    });
  });
}
