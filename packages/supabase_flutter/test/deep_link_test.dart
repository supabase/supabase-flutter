@TestOn('!browser')

import 'package:flutter_test/flutter_test.dart';
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
  });
}
