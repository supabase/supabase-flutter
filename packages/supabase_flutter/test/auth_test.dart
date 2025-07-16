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
          anonKey: supabaseKey,
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

    group('Session recovery', () {
      test('handles expired session with auto-refresh disabled', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          debug: false,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockExpiredStorage(),
            pkceAsyncStorage: MockAsyncStorage(),
            autoRefreshToken: false,
          ),
        );

        // Give it a delay to wait for recoverSession to throw
        await Future.delayed(const Duration(milliseconds: 100));

        await expectLater(Supabase.instance.client.auth.onAuthStateChange,
            emitsError(isA<AuthException>()));
      });

      test('handles null session during initialization', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          debug: false,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockEmptyLocalStorage(),
            pkceAsyncStorage: MockAsyncStorage(),
          ),
        );

        // Should handle empty storage gracefully
        expect(Supabase.instance.client.auth.currentSession, isNull);

        // Verify initial session event
        final event =
            await Supabase.instance.client.auth.onAuthStateChange.first;
        expect(event.event, AuthChangeEvent.initialSession);
        expect(event.session, isNull);
      });

      test('handles expired session with auto-refresh enabled', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          debug: false,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockExpiredStorage(),
            pkceAsyncStorage: MockAsyncStorage(),
            autoRefreshToken: true,
          ),
        );

        // With auto-refresh enabled, expired session should be handled
        expect(Supabase.instance.client.auth.currentSession, isNotNull);
        expect(Supabase.instance.client.auth.currentSession?.isExpired, isTrue);
      });
    });
  });
}
