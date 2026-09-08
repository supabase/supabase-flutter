import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widget_test_stubs.dart';

class _RecordingStorage extends MockAsyncStorage {
  final readKeys = <String>[];

  @override
  Future<String?> getItem(String key) {
    readKeys.add(key);
    return super.getItem(key);
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
      } catch (_) {
        // Ignore dispose errors
      }

      mockAppLink();
    });

    tearDown(() async {
      try {
        await Supabase.instance.dispose();
      } catch (_) {
        // Ignore dispose errors
      }
    });

    group('Session management', () {
      test('reads the persisted session on initialize', () async {
        final mockStorage = _RecordingStorage();

        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(asyncStorage: mockStorage),
        );

        expect(mockStorage.readKeys, [defaultPersistSessionKey(supabaseUrl)]);
      });

      test(
        'does not read the storage when the session is not persisted',
        () async {
          final mockStorage = _RecordingStorage();

          await Supabase.initialize(
            url: supabaseUrl,
            publishableKey: supabaseKey,
            authOptions: FlutterAuthClientOptions(
              asyncStorage: mockStorage,
              persistSession: false,
            ),
          );

          expect(mockStorage.readKeys, isEmpty);
        },
      );
    });

    group('Auth state stream error handling', () {
      test(
        'does not propagate auth state stream errors as unhandled exceptions',
        () async {
          await Supabase.initialize(
            url: supabaseUrl,
            publishableKey: supabaseKey,
            authOptions: FlutterAuthClientOptions(
              asyncStorage: MockAsyncStorage(),
            ),
          );

          // Trigger an error on the auth state change stream via
          // notifyException. This should not throw or cause an unhandled zone
          // error.
          final auth = Supabase.instance.client.auth;
          // ignore: invalid_use_of_internal_member
          auth.notifyException(
            Exception('test auth error'),
            StackTrace.current,
          );

          // Allow the stream listener to process the error.
          await Future.delayed(Duration.zero);

          // If we reach here the error was not rethrown as an unhandled
          // exception.
        },
      );
    });

    group('Session recovery', () {
      test('restores an expired session', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            asyncStorage: MockAsyncStorage.withSession(
              DateTime.now().subtract(const Duration(hours: 1)),
            ),
          ),
        );

        expect(Supabase.instance.client.auth.currentSession, isNotNull);
        expect(Supabase.instance.client.auth.currentSession?.isExpired, isTrue);
      });

      test('handles null session during initialization', () async {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseKey,
          authOptions: FlutterAuthClientOptions(
            asyncStorage: MockAsyncStorage(),
          ),
        );

        // Should handle empty storage gracefully
        expect(Supabase.instance.client.auth.currentSession, isNull);
      });
    });
  });
}
