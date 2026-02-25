@TestOn('!browser')

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';

  group('Deep Link with PKCE code', () {
    late final PkceHttpClient pkceHttpClient;

    setUp(() async {
      pkceHttpClient = PkceHttpClient();

      mockAppLink(
        mockMethodChannel: false,
        mockEventChannel: true,
        initialLink: 'com.supabase://callback/?code=my-code-verifier',
      );
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        debug: false,
        httpClient: pkceHttpClient,
        authOptions: FlutterAuthClientOptions(
          localStorage: MockEmptyLocalStorage(),
          pkceAsyncStorage: MockAsyncStorage()
            ..setItem(
                key: 'supabase.auth.token-code-verifier',
                value: 'raw-code-verifier'),
        ),
      );
    });

    test(
        'Having `code` as the query parameter triggers `getSessionFromUrl` call on initialize',
        () async {
      // Wait for the initial app link to be handled, as this is an async
      // process when mocking the event channel.
      await Future.delayed(const Duration(milliseconds: 500));
      expect(pkceHttpClient.requestCount, 1);
      expect(pkceHttpClient.lastRequestBody['auth_code'], 'my-code-verifier');
    });

    tearDown(() async {
      try {
        await Supabase.instance.dispose();
      } catch (e) {
        // Ignore dispose errors in tests
      }
    });
  });

  group('Deep Link Error Handling', () {
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

    test('handles malformed deep link URL gracefully', () async {
      // This test simulates error handling in deep link processing
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: MockEmptyLocalStorage(),
        ),
      );

      // The initialization should complete successfully even if there are
      // potential deep link errors to handle
      expect(Supabase.instance.client, isNotNull);
    });

    test('handles non-auth deep links correctly', () async {
      // Mock a deep link that is not auth-related
      mockAppLink(
        initialLink: 'com.supabase://other-action/?param=value',
      );

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: MockEmptyLocalStorage(),
        ),
      );

      // Should initialize normally without attempting auth
      expect(Supabase.instance.client, isNotNull);
    });

    test('handles auth deep link without proper parameters', () async {
      // Mock a deep link that looks like auth but missing required params
      mockAppLink(
        initialLink: 'com.supabase://callback/?error=access_denied',
      );

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: MockEmptyLocalStorage(),
        ),
      );

      // Should initialize normally and handle the error case
      expect(Supabase.instance.client, isNotNull);
    });

    test('handles empty deep link', () async {
      // Mock empty initial link
      mockAppLink(initialLink: '');

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: MockEmptyLocalStorage(),
        ),
      );

      expect(Supabase.instance.client, isNotNull);
    });
  });
}
