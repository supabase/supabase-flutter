import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';
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
      mockSharedPreferences();
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
          ),
          completes,
        );
      });
    });

    group('Custom JSON codec initialization', () {
      test('initializes with a supplied codec', () async {
        final jsonCodec = _RecordingJsonCodec();

        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          jsonCodec: jsonCodec,
        );

        expect(Supabase.instance.isInitialized, isTrue);
        expect(jsonCodec.isDisposed, isFalse);
      });

      test('leaves a supplied codec usable after dispose', () async {
        final jsonCodec = _RecordingJsonCodec();

        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          jsonCodec: jsonCodec,
        );
        await Supabase.instance.dispose();

        // The caller owns it, so the client must not have disposed it.
        expect(jsonCodec.isDisposed, isFalse);
        expect(await jsonCodec.decode('{"a":1}'), {'a': 1});
      });
    });

    group('Custom storage initialization', () {
      test('initialize successfully with a custom storage', () {
        expect(
          Supabase.initialize(
            url: supabaseUrl,
            publishableKey: supabaseKey,
            authOptions: FlutterAuthClientOptions(
              asyncStorage: MockAsyncStorage.withSession(
                DateTime.now().add(const Duration(hours: 1)),
              ),
            ),
          ),
          completes,
        );
      });

      test('handles initialization with expired session in storage', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            asyncStorage: MockAsyncStorage.withSession(
              DateTime.now().subtract(const Duration(hours: 1)),
            ),
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
        final httpClient = createPkceHttpClient();
        expect(
          Supabase.initialize(
            url: supabaseUrl,
            publishableKey: supabaseKey,
            httpClient: httpClient,
          ),
          completes,
        );
      });

      test('initialize successfully with custom access token', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
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
        );

        // Dispose
        await Supabase.instance.dispose();

        // Need to run the event loop to let the dispose complete
        await Future.delayed(Duration.zero);

        // Re-initialize should work without errors
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
        );
      });

      test('dispose drops the reference to the client', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
        );

        final supabase = Supabase.instance;
        await supabase.dispose();

        expect(() => supabase.client, throwsStateError);
      });

      test('instance asserts that supabase is initialized', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
        );
        await Supabase.instance.dispose();

        expect(() => Supabase.instance, throwsA(isA<AssertionError>()));
      });

      test('dispose can be called more than once', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
        );

        final supabase = Supabase.instance;
        await supabase.dispose();

        await expectLater(supabase.dispose(), completes);
      });

      test('a concurrent call waits for the first one to finish', () async {
        final asyncStorage = BlockingAsyncStorage();
        final first = Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(asyncStorage: asyncStorage),
        );
        var secondCompleted = false;
        final second = Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
        ).whenComplete(() => secondCompleted = true);

        await pumpEventQueue();
        expect(secondCompleted, isFalse);

        asyncStorage.release();
        expect(await second, same(await first));
      });

      test('a call with another url or key throws', () async {
        final asyncStorage = BlockingAsyncStorage();
        final first = Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(asyncStorage: asyncStorage),
        );

        await expectLater(
          Supabase.initialize(
            url: 'https://other.supabase.co',
            publishableKey: supabaseKey,
          ),
          throwsStateError,
        );

        asyncStorage.release();
        await first;

        await expectLater(
          Supabase.initialize(url: supabaseUrl, publishableKey: 'other-key'),
          throwsStateError,
        );
      });

      test('a call after a failed initialization tries again', () async {
        await expectLater(
          Supabase.initialize(url: 'http://[', publishableKey: supabaseKey),
          throwsA(anything),
        );

        await expectLater(
          Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey),
          completes,
        );
      });

      test('handles multiple initializations correctly', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            asyncStorage: MockAsyncStorage.withSession(
              DateTime.now().add(const Duration(hours: 1)),
            ),
          ),
        );

        // Store first instance to verify it's different after re-initialization
        final firstInstance = Supabase.instance.client;

        // Dispose first instance before re-initializing
        await Supabase.instance.dispose();

        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            asyncStorage: MockAsyncStorage(),
          ),
        );

        final secondInstance = Supabase.instance.client;
        expect(identical(firstInstance, secondInstance), isFalse);
      });
    });
  });
}

/// An [AsyncJsonCodec] that works inline and records whether it was disposed,
/// so a test can assert that a supplied codec stays the caller's to dispose.
class _RecordingJsonCodec implements AsyncJsonCodec {
  bool isDisposed = false;

  @override
  Future<dynamic> decode(String json) async => jsonDecode(json);

  @override
  Future<dynamic> decodeBytes(Uint8List encodedJson) async =>
      jsonDecode(utf8.decode(encodedJson));

  @override
  Future<String> encode(Object? json) async => jsonEncode(json);

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }
}
