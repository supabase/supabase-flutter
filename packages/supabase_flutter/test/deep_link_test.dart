@TestOn('!browser')
/// Tests for deep link handling on non-browser platforms.
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';
import 'widget_test_stubs.dart';

void main() {
  const supabaseUrl = '';
  const supabaseKey = '';

  tearDown(() async {
    if (Supabase.isInitializingOrInitialized) {
      await Supabase.instance.dispose();
    }
  });

  group('Deep Link with PKCE code', () {
    late final MockSupabaseHttpClient pkceHttpClient;

    setUp(() async {
      pkceHttpClient = createPkceHttpClient();

      mockAppLink(
        mockMethodChannel: false,
        mockEventChannel: true,
        initialLink: 'com.supabase://callback/?code=my-code-verifier',
      );
      final asyncStorage = MockAsyncStorage();
      await asyncStorage.setItem(
        '${defaultPersistSessionKey(supabaseUrl)}-code-verifier',
        'raw-code-verifier',
      );
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        httpClient: pkceHttpClient,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: asyncStorage,
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
        expect(pkceHttpClient.requests.length, 1);
        expect(
          pkceHttpClient.requests.last.jsonBody['auth_code'],
          'my-code-verifier',
        );
      },
    );
  });

  group('Deep Link with an implicit token with the implicit flow', () {
    late final MockSupabaseHttpClient getUserHttpClient;
    late final Future<AuthState> userUpdatedState;

    setUp(() async {
      getUserHttpClient = createGetUserHttpClient('new@email.com');

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
          authFlowType: AuthFlowType.implicit,
          asyncStorage: MockAsyncStorage(),
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
      expect(getUserHttpClient.requests.length, 1);
      expect(getUserHttpClient.requests.last.url.path, endsWith('/user'));
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
        final pkceHttpClient = createPkceHttpClient();

        mockAppLink(
          mockMethodChannel: false,
          mockEventChannel: true,
          initialLink: 'com.supabase://callback/?code=my-code-verifier',
        );
        final asyncStorage = MockAsyncStorage();
        await asyncStorage.setItem(
          '${defaultPersistSessionKey(supabaseUrl)}-code-verifier',
          'raw-code-verifier',
        );
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          httpClient: pkceHttpClient,
          authOptions: FlutterAuthClientOptions(
            asyncStorage: asyncStorage,
            detectSessionInUriPredicate: (uri) => false,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
        expect(pkceHttpClient.requests.length, 0);
      },
    );

    test(
      'predicate governs detection based on the incoming uri',
      () async {
        final pkceHttpClient = createPkceHttpClient();
        final receivedUris = <Uri>[];

        mockAppLink(
          mockMethodChannel: false,
          mockEventChannel: true,
          initialLink: 'com.supabase://callback/?code=my-code-verifier',
        );
        final asyncStorage = MockAsyncStorage();
        await asyncStorage.setItem(
          '${defaultPersistSessionKey(supabaseUrl)}-code-verifier',
          'raw-code-verifier',
        );
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          httpClient: pkceHttpClient,
          authOptions: FlutterAuthClientOptions(
            asyncStorage: asyncStorage,
            detectSessionInUriPredicate: (uri) {
              receivedUris.add(uri);
              return uri.queryParameters.containsKey('code');
            },
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
        expect(receivedUris.single.queryParameters['code'], 'my-code-verifier');
        expect(pkceHttpClient.requests.length, 1);
        expect(
          pkceHttpClient.requests.last.jsonBody['auth_code'],
          'my-code-verifier',
        );
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
        final pkceHttpClient = createPkceHttpClient();

        mockAppLink(
          mockMethodChannel: false,
          mockEventChannel: true,
          initialLink: 'com.supabase://callback/?code=my-code-verifier',
        );
        final preferences = SharedPreferencesAsync();
        await preferences.setString(
          '$persistSessionKey-code-verifier',
          'raw-code-verifier',
        );
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          httpClient: pkceHttpClient,
        );

        await Supabase.instance.client.auth.onAuthStateChange
            .firstWhere((state) => state.event == AuthChangeEvent.signedIn)
            .timeout(const Duration(seconds: 5));
        await pumpEventQueue();

        expect(await preferences.getString(persistSessionKey), isNotNull);
      },
    );

    test(
      'does not persist the session when persistSession is false',
      () async {
        mockSharedPreferences();
        final pkceHttpClient = createPkceHttpClient();

        mockAppLink(
          mockMethodChannel: false,
          mockEventChannel: true,
          initialLink: 'com.supabase://callback/?code=my-code-verifier',
        );
        final preferences = SharedPreferencesAsync();
        await preferences.setString(
          '$persistSessionKey-code-verifier',
          'raw-code-verifier',
        );
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          httpClient: pkceHttpClient,
          authOptions: const FlutterAuthClientOptions(persistSession: false),
        );

        await Supabase.instance.client.auth.onAuthStateChange
            .firstWhere((state) => state.event == AuthChangeEvent.signedIn)
            .timeout(const Duration(seconds: 5));
        await pumpEventQueue();

        expect(await preferences.getString(persistSessionKey), isNull);
        expect(Supabase.instance.client.auth.currentSession, isNotNull);
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
        httpClient: createGetUserHttpClient('new@email.com'),
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage(),
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
  group('Deep Link with an error redirect from the auth server', () {
    Future<AuthException> surfacedException(String link) async {
      final exception = Completer<AuthException>();
      mockAppLink(
        mockMethodChannel: false,
        mockEventChannel: true,
        initialLink: link,
      );
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage(),
        ),
      );
      Supabase.instance.client.auth.onAuthStateChange.listen(
        (_) {},
        onError: (Object error) {
          if (error is AuthException && !exception.isCompleted) {
            exception.complete(error);
          }
        },
      );
      return exception.future.timeout(const Duration(seconds: 5));
    }

    test(
      'an error_code and error_description in the fragment are surfaced',
      () async {
        final exception = await surfacedException(
          'com.supabase://callback/#error_code=otp_expired'
          '&error_description=Link+expired&sb=',
        );

        expect(exception.errorCode, 'otp_expired');
        expect(exception.message, 'Link expired');
      },
    );

    test('an error and error_description in the query are surfaced', () async {
      final exception = await surfacedException(
        'com.supabase://callback/?error=access_denied'
        '&error_description=Signups+not+allowed',
      );

      expect(exception.errorCode, 'access_denied');
      expect(exception.message, 'Signups not allowed');
    });
  });

  group('Deep Link that is not an auth redirect', () {
    Future<AuthException> nextAuthException() {
      final exception = Completer<AuthException>();
      final subscription = Supabase.instance.client.auth.onAuthStateChange
          .listen(
            (_) {},
            onError: (Object error) {
              if (error is AuthException && !exception.isCompleted) {
                exception.complete(error);
              }
            },
          );
      addTearDown(subscription.cancel);
      return exception.future.timeout(const Duration(seconds: 5));
    }

    Future<void> expectIgnored(
      String link, {
      MockAsyncStorage? asyncStorage,
    }) async {
      final httpClient = createPkceHttpClient();
      final errors = <Object>[];
      mockNativeAppLinks(launchLink: link);

      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        httpClient: httpClient,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: asyncStorage ?? MockAsyncStorage(),
        ),
      );
      final subscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((_) {}, onError: errors.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      expect(httpClient.requests, isEmpty);
      expect(errors, isEmpty);
      expect(Supabase.instance.client.auth.currentSession, isNull);
    }

    for (final link in [
      'com.supabase://invite?code=X',
      'com.supabase://invite#code=X',
      'com.supabase://form?error=1',
      'com.supabase://form?error_description=Invalid+input',
      'com.supabase://form#error_code=E42',
    ]) {
      test('$link is ignored when no PKCE flow is pending', () async {
        await expectIgnored(link);
      });
    }

    for (final link in [
      'com.supabase://login-callback#access_token=A&refresh_token=R'
          '&expires_in=3600&token_type=bearer',
      'com.supabase://login-callback?access_token=A&refresh_token=R'
          '&expires_in=3600&token_type=bearer',
    ]) {
      test('$link is ignored with the PKCE flow', () async {
        await expectIgnored(link);
      });
    }

    test('a link with a code received later is ignored when no PKCE flow is '
        'pending', () async {
      final httpClient = createPkceHttpClient();
      final errors = <Object>[];
      mockNativeAppLinks();
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        httpClient: httpClient,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage(),
        ),
      );
      final subscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((_) {}, onError: errors.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await sendAppLink('com.supabase://invite?code=X');
      await pumpEventQueue();

      expect(httpClient.requests, isEmpty);
      expect(errors, isEmpty);
    });

    test('a code is exchanged once a PKCE flow is pending', () async {
      final httpClient = createPkceHttpClient();
      final asyncStorage = MockAsyncStorage();
      mockNativeAppLinks();
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        httpClient: httpClient,
        authOptions: FlutterAuthClientOptions(asyncStorage: asyncStorage),
      );
      await pumpEventQueue();

      await sendAppLink('com.supabase://invite?code=X');
      await pumpEventQueue();
      expect(httpClient.requests, isEmpty);

      await asyncStorage.setItem(
        '${defaultPersistSessionKey(supabaseUrl)}-code-verifier',
        'raw-code-verifier',
      );
      await sendAppLink('com.supabase://callback?code=my-code');
      await pumpEventQueue();

      expect(httpClient.requests.single.jsonBody['auth_code'], 'my-code');
    });

    test(
      'a code with the flow id of this client is claimed even when its '
      'verifier is gone',
      () async {
        final httpClient = createPkceHttpClient();
        mockNativeAppLinks(
          launchLink:
              'com.supabase://callback?code=my-code'
              '&sb_flow_id=0123456789abcdef',
        );
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          httpClient: httpClient,
          authOptions: FlutterAuthClientOptions(
            asyncStorage: MockAsyncStorage(),
          ),
        );
        expect(
          (await nextAuthException()).message,
          'Code verifier could not be found in local storage.',
        );
        expect(httpClient.requests, isEmpty);
      },
    );

    test('the custom predicate still claims a code with no pending PKCE '
        'flow', () async {
      mockNativeAppLinks(launchLink: 'com.supabase://invite?code=X');
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        httpClient: createPkceHttpClient(),
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage(),
          detectSessionInUriPredicate: (uri) => true,
        ),
      );
      expect(
        (await nextAuthException()).message,
        'Code verifier could not be found in local storage.',
      );
    });

    test('an access_token link the custom predicate claims is rejected with '
        'the PKCE flow', () async {
      final httpClient = createGetUserHttpClient('attacker@email.com');
      mockNativeAppLinks(
        launchLink:
            'com.supabase://login-callback#access_token=A&refresh_token=R'
            '&expires_in=3600&token_type=bearer',
      );
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        httpClient: httpClient,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage(),
          detectSessionInUriPredicate: (uri) => true,
        ),
      );

      expect(
        await nextAuthException(),
        isA<AuthPKCEGrantCodeExchangeException>(),
      );
      expect(httpClient.requests, isEmpty);
      expect(Supabase.instance.client.auth.currentSession, isNull);
    });
  });

  group('Deep Link errors from the platform', () {
    const methodChannel = MethodChannel('com.llfbandit.app_links/messages');
    const eventChannel = MethodChannel('com.llfbandit.app_links/events');

    Future<LogRecord> receivingWarning() => Logger.root.onRecord
        .firstWhere(
          (record) =>
              record.level == Level.WARNING &&
              record.message == 'Error while receiving deeplink',
        )
        .timeout(const Duration(seconds: 5));

    test('a failing initial link lookup is logged', () async {
      mockNativeAppLinks();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            methodChannel,
            (_) => throw PlatformException(
              code: 'unavailable',
              message: 'No initial link',
            ),
          );
      final warning = receivingWarning();

      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage(),
        ),
      );

      expect((await warning).error, 'No initial link');
    });

    test('an error on the link stream is logged', () async {
      mockNativeAppLinks();
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage(),
        ),
      );
      final warning = receivingWarning();

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            eventChannel.name,
            const StandardMethodCodec().encodeErrorEnvelope(
              code: 'broken',
              message: 'Link stream broke',
            ),
            (_) {},
          );

      expect(
        (await warning).error,
        isA<PlatformException>().having(
          (error) => error.message,
          'message',
          'Link stream broke',
        ),
      );
    });
  });

  group('Deep Link with malformed percent-encoding', () {
    Future<void> expectIgnoredDeeplink(
      String link, {
      bool Function(Uri uri)? detectSessionInUriPredicate,
    }) async {
      final httpClient = createGetUserHttpClient('new@email.com');
      final warning = Logger.root.onRecord.firstWhere(
        (record) =>
            record.level == Level.WARNING &&
            record.message ==
                'Ignoring deeplink that is not valid percent-encoded UTF-8',
      );

      mockAppLink(
        mockMethodChannel: false,
        mockEventChannel: true,
        initialLink: link,
      );
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        httpClient: httpClient,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: MockAsyncStorage(),
          detectSessionInUriPredicate: detectSessionInUriPredicate,
        ),
      );

      final record = await warning.timeout(const Duration(seconds: 5));
      expect(record.error, isA<FormatException>());
      expect(httpClient.requests, isEmpty);
      expect(Supabase.instance.client.auth.currentSession, isNull);
    }

    for (final link in [
      'com.supabase://callback/?code=%FF',
      'com.supabase://callback/#access_token=%FF',
      'com.supabase://callback/#/route%C3',
    ]) {
      test('$link is ignored by the default predicate', () async {
        await expectIgnoredDeeplink(link);
      });
    }

    test('a throwing custom predicate is ignored', () async {
      await expectIgnoredDeeplink(
        'com.supabase://callback/?code=%FF',
        detectSessionInUriPredicate: (uri) =>
            uri.queryParameters.containsKey('code'),
      );
    });
  });

  group('Link the app was launched with', () {
    const launchLink = 'com.supabase://callback/?code=my-code-verifier';

    Future<MockAsyncStorage> storageWithCodeVerifier() async {
      final asyncStorage = MockAsyncStorage();
      await asyncStorage.setItem(
        '${defaultPersistSessionKey(supabaseUrl)}-code-verifier',
        'raw-code-verifier',
      );
      return asyncStorage;
    }

    test(
      'is exchanged when the app listened to the link stream first',
      () async {
        final httpClient = createPkceHttpClient();
        mockNativeAppLinks(launchLink: launchLink);
        final appLinks = <Uri>[];
        final appSubscription = AppLinks().uriLinkStream.listen(appLinks.add);
        addTearDown(appSubscription.cancel);
        await pumpEventQueue();
        expect(appLinks, [Uri.parse(launchLink)]);

        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          httpClient: httpClient,
          authOptions: FlutterAuthClientOptions(
            asyncStorage: await storageWithCodeVerifier(),
          ),
        );

        await pumpEventQueue();

        expect(
          httpClient.requests.single.jsonBody['auth_code'],
          'my-code-verifier',
        );
      },
    );

    test('is exchanged once when the link stream delivers it too', () async {
      final httpClient = createPkceHttpClient();
      mockNativeAppLinks(launchLink: launchLink);

      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        httpClient: httpClient,
        authOptions: FlutterAuthClientOptions(
          asyncStorage: await storageWithCodeVerifier(),
        ),
      );
      await Supabase.instance.client.auth.onAuthStateChange
          .firstWhere((state) => state.event == AuthChangeEvent.signedIn)
          .timeout(const Duration(seconds: 5));
      await pumpEventQueue();

      expect(httpClient.requests, hasLength(1));
    });

    test('a link received while the session is restored is exchanged after '
        'the restore', () async {
      final httpClient = createPkceHttpClient();
      mockNativeAppLinks(launchLink: launchLink, answerGetInitialLink: false);
      final asyncStorage = BlockingAsyncStorage();
      await asyncStorage.setItem(
        '${defaultPersistSessionKey(supabaseUrl)}-code-verifier',
        'raw-code-verifier',
      );

      final initialization = Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        httpClient: httpClient,
        authOptions: FlutterAuthClientOptions(asyncStorage: asyncStorage),
      );
      await pumpEventQueue();
      expect(httpClient.requests, isEmpty);

      asyncStorage.release();
      await initialization;
      await pumpEventQueue();

      expect(httpClient.requests, hasLength(1));
    });

    test(
      'a link the predicate throws for does not hold back later links',
      () async {
        final httpClient = createPkceHttpClient();
        mockNativeAppLinks(
          launchLink: 'com.supabase://unexpected/?code=other',
          answerGetInitialLink: false,
        );

        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          httpClient: httpClient,
          authOptions: FlutterAuthClientOptions(
            asyncStorage: await storageWithCodeVerifier(),
            detectSessionInUriPredicate: (uri) {
              if (uri.host != 'callback') {
                throw StateError('Unexpected host ${uri.host}');
              }
              return true;
            },
          ),
        );
        await pumpEventQueue();
        expect(httpClient.requests, isEmpty);

        await sendAppLink(launchLink);
        await pumpEventQueue();

        expect(
          httpClient.requests.single.jsonBody['auth_code'],
          'my-code-verifier',
        );
      },
    );

    test('dispose during initialize leaves no link subscription', () async {
      final httpClient = createPkceHttpClient();
      final eventChannelCalls = mockNativeAppLinks(launchLink: launchLink);
      final asyncStorage = BlockingAsyncStorage();

      final initialization = Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        httpClient: httpClient,
        authOptions: FlutterAuthClientOptions(asyncStorage: asyncStorage),
      );
      await pumpEventQueue();
      await Supabase.instance.dispose();

      asyncStorage.release();
      await initialization;
      await pumpEventQueue();

      expect(
        eventChannelCalls.where((method) => method == 'listen').length,
        eventChannelCalls.where((method) => method == 'cancel').length,
      );
      expect(httpClient.requests, isEmpty);
    });
  });
}
