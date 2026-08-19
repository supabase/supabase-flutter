@TestOn('!browser')
/// Tests for deep link handling on non-browser platforms.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';
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
        httpClient: pkceHttpClient,
        authOptions: FlutterAuthClientOptions(
          localStorage: const MockEmptyLocalStorage(),
          pkceAsyncStorage: pkceAsyncStorage,
        ),
      );
    });

    test(
      'Having `code` as the query parameter triggers `getSessionFromUrl` call '
      'on initialize',
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
    late final Future<AuthState> userUpdatedState;

    setUp(() async {
      getUserHttpClient = GetUserHttpClient('new@email.com');

      mockAppLink(
        mockMethodChannel: false,
        mockEventChannel: true,
        initialLink:
            'com.supabase://callback/#access_token=my-access-token&expires_in=3'
            '600&refresh_token=my-refresh-token&token_type=bearer&type=email_ch'
            'ange',
      );
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        httpClient: getUserHttpClient,
        authOptions: FlutterAuthClientOptions(
          localStorage: const MockEmptyLocalStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
        ),
      );

      // The link confirms an email change, so it emits `userUpdated` rather
      // than `signedIn`.
      userUpdatedState = Supabase.instance.client.auth.onAuthStateChange
          .firstWhere((state) => state.event == AuthChangeEvent.userUpdated)
          .timeout(const Duration(seconds: 5));
    });

    test('Implicit token in the fragment triggers `getSessionFromUrl` and '
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
        mockSharedPreferences();
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
          httpClient: pkceHttpClient,
          authOptions: FlutterAuthClientOptions(
            pkceAsyncStorage: pkceAsyncStorage,
          ),
        );

        await Supabase.instance.client.auth.onAuthStateChange
            .firstWhere((state) => state.event == AuthChangeEvent.signedIn)
            .timeout(const Duration(seconds: 5));

        final preferences = SharedPreferencesAsync();
        expect(await preferences.getString(persistSessionKey), isNotNull);
      },
    );

    test(
      'does not persist the session when persistSession is false',
      () async {
        mockSharedPreferences();
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
          httpClient: pkceHttpClient,
          authOptions: FlutterAuthClientOptions(
            pkceAsyncStorage: pkceAsyncStorage,
            persistSession: false,
          ),
        );

        await Supabase.instance.client.auth.onAuthStateChange
            .firstWhere((state) => state.event == AuthChangeEvent.signedIn)
            .timeout(const Duration(seconds: 5));

        final preferences = SharedPreferencesAsync();
        expect(await preferences.getString(persistSessionKey), isNull);
      },
    );
  });

  group('Deep Link with error query parameter', () {
    late final Completer<AuthApiException> errorCompleter;

    setUp(() async {
      errorCompleter = Completer<AuthApiException>();

      mockAppLink(
        mockMethodChannel: false,
        mockEventChannel: true,
        initialLink:
            'com.supabase://callback/?error=access_denied&error_code=403',
      );
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        httpClient: GetUserHttpClient('new@email.com'),
        authOptions: FlutterAuthClientOptions(
          localStorage: const MockEmptyLocalStorage(),
          pkceAsyncStorage: MockAsyncStorage(),
        ),
      );

      Supabase.instance.client.auth.onAuthStateChange.listen(
        (_) {},
        onError: (error) {
          if (error is AuthApiException && !errorCompleter.isCompleted) {
            errorCompleter.complete(error);
          }
        },
      );
    });

    test('Error query parameter triggers `getSessionFromUrl` and surfaces an '
        'AuthApiException', () async {
      final exception = await errorCompleter.future.timeout(
        const Duration(seconds: 5),
      );
      expect(exception.errorCode, 'access_denied');
      expect(exception.statusCode, 403);
    });
  });
}
