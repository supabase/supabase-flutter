import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
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

    group('Auth state stream error handling', () {
      test('logs auth state stream errors at warning level', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
          debug: false,
          authOptions: FlutterAuthClientOptions(
            localStorage: MockEmptyLocalStorage(),
            pkceAsyncStorage: MockAsyncStorage(),
          ),
        );

        final logRecords = <LogRecord>[];
        final sub = Logger('supabase.supabase_flutter').onRecord.listen(
              (record) => logRecords.add(record),
            );

        // Trigger an error on the auth state change stream via notifyException.
        final auth = Supabase.instance.client.auth;
        // ignore: invalid_use_of_internal_member
        auth.notifyException(Exception('test auth error'), StackTrace.current);

        // Allow the stream listener to process the error.
        await Future.delayed(Duration.zero);

        await sub.cancel();

        expect(
          logRecords,
          contains(
            predicate<LogRecord>(
              (r) =>
                  r.level == Level.WARNING &&
                  r.message == 'Auth state change stream error' &&
                  r.error.toString().contains('test auth error'),
            ),
          ),
        );
      });
    });

    group('Session recovery', () {
      test('handles corrupted session data gracefully', () async {
        final corruptedStorage = MockExpiredStorage();

        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
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
          anonKey: supabaseKey,
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
