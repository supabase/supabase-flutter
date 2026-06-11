@TestOn('!browser')

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';

  tearDown(() async {
    await Supabase.instance.dispose();
  });

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
        publishableKey: supabaseKey,
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

  group('Deep Link with implicit token while PKCE flow is configured', () {
    late final GetUserHttpClient getUserHttpClient;
    late final Future<AuthState> userUpdatedState;

    setUp(() async {
      getUserHttpClient = GetUserHttpClient('new@email.com');

      // Email change confirmation links return implicit-style tokens in the
      // fragment even when the client is configured for the (default) PKCE
      // flow. See https://github.com/supabase/supabase-flutter/issues/986
      mockAppLink(
        mockMethodChannel: false,
        mockEventChannel: true,
        initialLink: 'com.supabase://callback/#access_token=my-access-token'
            '&expires_in=3600&refresh_token=my-refresh-token'
            '&token_type=bearer&type=email_change',
      );
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        debug: false,
        httpClient: getUserHttpClient,
        authOptions: FlutterAuthClientOptions(
          localStorage: MockEmptyLocalStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
        ),
      );

      // Subscribe before the (asynchronously delivered) deep link is handled so
      // the event is not missed, avoiding a flaky fixed delay.
      userUpdatedState = Supabase.instance.client.auth.onAuthStateChange
          .firstWhere((state) => state.event == AuthChangeEvent.userUpdated)
          .timeout(const Duration(seconds: 5));
    });

    test(
        'Implicit token in the fragment triggers `getSessionFromUrl` and '
        'updates the current user', () async {
      final state = await userUpdatedState;
      expect(state.session?.user.email, 'new@email.com');
      expect(getUserHttpClient.requestCount, 1);
      expect(getUserHttpClient.lastRequestUrl?.path, endsWith('/user'));
      expect(
        Supabase.instance.client.auth.currentUser?.email,
        'new@email.com',
      );
    });
  });
}
