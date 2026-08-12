import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Storage Tests', () {
    // SharedPreferencesLocalStorage Tests
    group('SharedPreferencesLocalStorage', () {
      const testSessionValue = '{"key": "value"}';
      var testCount = 0;

      Future<SharedPreferencesLocalStorage> createFreshLocalStorage() async {
        // A key per test, counted rather than timestamped: on web the storage
        // goes to the window's own localStorage, which outlives the test, and
        // `microsecondsSinceEpoch` is only millisecond-resolution there, so two
        // tests in the same millisecond used to share a key.
        final uniqueKey = 'test_persist_key_${testCount++}';

        // Set up fresh shared preferences for each test
        mockSharedPreferences();

        final localStorage = SharedPreferencesLocalStorage(
          persistSessionKey: uniqueKey,
        );
        await localStorage.initialize();
        // The web store can hold a value from an earlier run under this key.
        await localStorage.removePersistedSession();
        return localStorage;
      }

      test('hasAccessToken returns false when no session exists', () async {
        final localStorage = await createFreshLocalStorage();
        final result = await localStorage.hasAccessToken();
        expect(result, isFalse);
      });

      test('hasAccessToken returns true when session exists', () async {
        final localStorage = await createFreshLocalStorage();
        await localStorage.persistSession(testSessionValue);
        final result = await localStorage.hasAccessToken();
        expect(result, isTrue);
      });

      test('accessToken returns null when no session exists', () async {
        final localStorage = await createFreshLocalStorage();
        final result = await localStorage.accessToken();
        expect(result, isNull);
      });

      test('accessToken returns session string when session exists', () async {
        final localStorage = await createFreshLocalStorage();
        await localStorage.persistSession(testSessionValue);
        final result = await localStorage.accessToken();
        expect(result, testSessionValue);
      });

      test('persistSession stores session string', () async {
        final localStorage = await createFreshLocalStorage();
        await localStorage.persistSession(testSessionValue);

        // Verify the session was stored by checking through localStorage's own
        // methods
        final hasToken = await localStorage.hasAccessToken();
        expect(hasToken, isTrue);

        final storedValue = await localStorage.accessToken();
        expect(storedValue, testSessionValue);
      });

      test('removePersistedSession removes session', () async {
        final localStorage = await createFreshLocalStorage();
        // First store a session
        await localStorage.persistSession(testSessionValue);
        expect(await localStorage.hasAccessToken(), isTrue);

        // Then remove it
        await localStorage.removePersistedSession();
        expect(await localStorage.hasAccessToken(), isFalse);
        expect(await localStorage.accessToken(), isNull);
      });
    });

    // SharedPreferencesGotrueAsyncStorage Tests
    group('SharedPreferencesGotrueAsyncStorage', () {
      late SharedPreferencesGotrueAsyncStorage asyncStorage;
      const testKey = 'test_key';
      const testValue = 'test_value';

      setUp(() {
        // Set up fake shared preferences
        mockSharedPreferences();
        asyncStorage = SharedPreferencesGotrueAsyncStorage();
      });

      test('setItem stores value for key', () async {
        await asyncStorage.setItem(key: testKey, value: testValue);
        final storedValue = await SharedPreferencesAsync().getString(testKey);
        expect(storedValue, testValue);
      });

      test('getItem returns null when no value exists', () async {
        final result = await asyncStorage.getItem(key: 'non_existent_key');
        expect(result, isNull);
      });

      test('getItem returns value when value exists', () async {
        await asyncStorage.setItem(key: testKey, value: testValue);
        final result = await asyncStorage.getItem(key: testKey);
        expect(result, testValue);
      });

      test('removeItem removes value', () async {
        // First store a value
        await asyncStorage.setItem(key: testKey, value: testValue);
        expect(await asyncStorage.getItem(key: testKey), testValue);

        // Then remove it
        await asyncStorage.removeItem(key: testKey);
        expect(await asyncStorage.getItem(key: testKey), isNull);
      });
    });
  });
}
