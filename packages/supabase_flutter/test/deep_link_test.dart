@TestOn('!browser')
/// Tests for deep link handling on non-browser platforms.
library;

import 'dart:async';

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
      final pkceAsyncStorage = MockAsyncStorage();
      await pkceAsyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'raw-code-verifier',
      );
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        debug: false,
        httpClient: pkceHttpClient,
        authOptions: FlutterAuthClientOptions(
          localStorage: const MockEmptyLocalStorage(),
          pkceAsyncStorage: pkceAsyncStorage,
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
      },
    );
  });

  group('Deep Link with implicit token while PKCE flow is configured', () {
    late final GetUserHttpClient getUserHttpClient;
    late final Future<AuthState> signedInState;

    setUp(() async {
      getUserHttpClient = GetUserHttpClient('new@email.com');

      mockAppLink(
        mockMethodChannel: false,
        mockEventChannel: true,
        initialLink:
            'com.supabase://callback/#access_token=my-access-token'
            '&expires_in=3600&refresh_token=my-refresh-token'
            '&token_type=bearer&type=email_change',
      );
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        debug: false,
        httpClient: getUserHttpClient,
        authOptions: FlutterAuthClientOptions(
          localStorage: const MockEmptyLocalStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
        ),
      );

      signedInState = Supabase.instance.client.auth.onAuthStateChange
          .firstWhere((state) => state.event == AuthChangeEvent.signedIn)
          .timeout(const Duration(seconds: 5));
    });

    test('Implicit token in the fragment triggers `getSessionFromUrl` and '
        'updates the current user', () async {
      final state = await signedInState;
      expect(state.session?.user.email, 'new@email.com');
      expect(getUserHttpClient.requestCount, 1);
      expect(getUserHttpClient.lastRequestUrl?.path, endsWith('/user'));
      expect(
        Supabase.instance.client.auth.currentUser?.email,
        'new@email.com',
      );
    });
  });

  group('Deep Link with error query parameter', () {
    late final Completer<AuthException> errorCompleter;

    setUp(() async {
      errorCompleter = Completer<AuthException>();

      mockAppLink(
        mockMethodChannel: false,
        mockEventChannel: true,
        initialLink:
            'com.supabase://callback/?error=access_denied'
            '&error_code=403',
      );
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        debug: false,
        httpClient: GetUserHttpClient('new@email.com'),
        authOptions: FlutterAuthClientOptions(
          localStorage: const MockEmptyLocalStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
        ),
      );

      Supabase.instance.client.auth.onAuthStateChange.listen(
        (_) {},
        onError: (error) {
          if (error is AuthException && !errorCompleter.isCompleted) {
            errorCompleter.complete(error);
          }
        },
      );
    });

    test('Error query parameter triggers `getSessionFromUrl` and surfaces an '
        'AuthException', () async {
      final exception = await errorCompleter.future.timeout(
        const Duration(seconds: 5),
      );
      expect(exception.code, 'access_denied');
      expect(exception.statusCode, '403');
    });
  });
}
