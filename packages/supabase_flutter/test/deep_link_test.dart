@TestOn('!browser')
/// Tests for deep link handling on non-browser platforms.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  group('Custom session-URL-detection predicate', () {
    test(
      'predicate returning false suppresses detection of an otherwise valid '
      'auth callback',
      () async {
        final pkceHttpClient = PkceHttpClient();

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
            detectSessionInUriPredicate: (uri) => false,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
        expect(pkceHttpClient.requestCount, 0);
      },
    );

    test(
      'predicate governs detection based on the incoming uri',
      () async {
        final pkceHttpClient = PkceHttpClient();
        final receivedUris = <Uri>[];

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
            detectSessionInUriPredicate: (uri) {
              receivedUris.add(uri);
              return uri.queryParameters.containsKey('code');
            },
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
        expect(receivedUris.single.queryParameters['code'], 'my-code-verifier');
        expect(pkceHttpClient.requestCount, 1);
        expect(pkceHttpClient.lastRequestBody['auth_code'], 'my-code-verifier');
      },
    );
  });

  group('persistSession flag', () {
    // With url '', the default persist session key resolves to this value.
    const persistSessionKey = 'sb--auth-token';

    test(
      'persists the session to the default storage when persistSession is true',
      () async {
        SharedPreferences.setMockInitialValues({});
        final pkceHttpClient = PkceHttpClient();

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
            pkceAsyncStorage: pkceAsyncStorage,
          ),
        );

        await Supabase.instance.client.auth.onAuthStateChange
            .firstWhere((state) => state.event == AuthChangeEvent.signedIn)
            .timeout(const Duration(seconds: 5));

        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString(persistSessionKey), isNotNull);
      },
    );

    test(
      'does not persist the session when persistSession is false',
      () async {
        SharedPreferences.setMockInitialValues({});
        final pkceHttpClient = PkceHttpClient();

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
            pkceAsyncStorage: pkceAsyncStorage,
            persistSession: false,
          ),
        );

        await Supabase.instance.client.auth.onAuthStateChange
            .firstWhere((state) => state.event == AuthChangeEvent.signedIn)
            .timeout(const Duration(seconds: 5));

        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString(persistSessionKey), isNull);
      },
    );
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
