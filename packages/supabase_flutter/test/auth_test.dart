import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

class _MockLocalStorage extends MockLocalStorage {
  bool _initializeCalled = false;

  bool get initializeCalled => _initializeCalled;

  @override
  Future<void> initialize() async {
    _initializeCalled = true;
    return super.initialize();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = '';
  const supabaseKey = '';

  group('Authentication', () {
    setUp(() async {
      try {
        await Supabase.instance.dispose();
      } catch (e) {
        // Ignore dispose errors
      }

      mockAppLink();
    });

    tearDown(() async {
      try {
        await Supabase.instance.dispose();
      } catch (e) {
        // Ignore dispose errors
      }
    });

    group('Session management', () {
      test('initializes local storage on initialize', () async {
        final mockStorage = _MockLocalStorage();

        await Supabase.initialize(
          url: supabaseUrl,
          supabaseKey: supabaseKey,
          debug: false,
          authOptions: FlutterAuthClientOptions(
            localStorage: mockStorage,
            pkceAsyncStorage: MockAsyncStorage(),
          ),
        );

        // Give time for initialization to complete
        await Future.delayed(const Duration(milliseconds: 100));

        expect(mockStorage.initializeCalled, isTrue);
      });
    });

    group('Auth state stream error handling', () {
      test(
          'does not propagate auth state stream errors as unhandled exceptions',
          () async {
        await Supabase.initialize(
          url: supabaseUrl,
          supabaseKey: supabaseKey,
          debug: false,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockEmptyLocalStorage(),
            pkceAsyncStorage: MockAsyncStorage(),
          ),
        );

        // Trigger an error on the auth state change stream via notifyException.
        // This should not throw or cause an unhandled zone error.
        final auth = Supabase.instance.client.auth;
        // ignore: invalid_use_of_internal_member
        auth.notifyException(Exception('test auth error'), StackTrace.current);

        // Allow the stream listener to process the error.
        await Future.delayed(Duration.zero);

        // If we reach here the error was not rethrown as an unhandled exception.
      });
    });

    group('Session recovery', () {
      test('handles corrupted session data gracefully', () async {
        final corruptedStorage = MockExpiredStorage();

        await Supabase.initialize(
          url: supabaseUrl,
          supabaseKey: supabaseKey,
          debug: false,
          authOptions: FlutterAuthClientOptions(
            localStorage: corruptedStorage,
            pkceAsyncStorage: MockAsyncStorage(),
          ),
        );

        // MockExpiredStorage returns an expired session, not null
        expect(Supabase.instance.client.auth.currentSession, isNotNull);
        expect(Supabase.instance.client.auth.currentSession?.isExpired, isTrue);
      });

      test('handles null session during initialization', () async {
        final emptyStorage = MockEmptyLocalStorage();

        await Supabase.initialize(
          url: supabaseUrl,
          supabaseKey: supabaseKey,
          debug: false,
          authOptions: FlutterAuthClientOptions(
            localStorage: emptyStorage,
            pkceAsyncStorage: MockAsyncStorage(),
          ),
        );

        // Should handle empty storage gracefully
        expect(Supabase.instance.client.auth.currentSession, isNull);
      });
    });
  });
}
