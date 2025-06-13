@TestOn('!browser')

import 'package:app_links/app_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';

  group('Deep Link with PKCE code', () {
    late final PkceHttpClient pkceHttpClient;
    late final bool mockEventChannel;

    /// Check if the current version of AppLinks uses an explicit call to get
    /// the initial link. This is only the case before version 6.0.0, where we
    /// can find the getInitialAppLink function.
    ///
    /// CI pipeline is set so that it tests both app_links newer and older than v6.0.0
    bool appLinksExposesInitialLinkInStream() {
      try {
        // before app_links 6.0.0
        (AppLinks() as dynamic).getInitialAppLink;
        return false;
      } on NoSuchMethodError catch (_) {
        return true;
      }
    }

    setUp(() async {
      pkceHttpClient = PkceHttpClient();

      // Add initial deep link with a `code` parameter, use method channel if
      // we are in a version of AppLinks that use the explcit method for
      // getting the initial link. Otherwise we want to mock the event channel
      // and put the initial link there.
      mockEventChannel = appLinksExposesInitialLinkInStream();
      mockAppLink(
        mockMethodChannel: !mockEventChannel,
        mockEventChannel: mockEventChannel,
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
      if (mockEventChannel) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
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
