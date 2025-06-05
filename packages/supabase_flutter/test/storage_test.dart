import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Storage Tests', () {
    // SharedPreferencesLocalStorage Tests
    group('SharedPreferencesLocalStorage', () {
      const persistSessionKey = 'test_persist_key';
      const testSessionValue = '{"key": "value"}';

      Future<SharedPreferencesLocalStorage> createFreshLocalStorage() async {
        // Set up fresh shared preferences for each test
        SharedPreferences.setMockInitialValues({});
        final localStorage = SharedPreferencesLocalStorage(
          persistSessionKey: persistSessionKey,
        );
        await localStorage.initialize();
        return localStorage;
      }

      test('hasAccessToken returns false when no session exists', () async {
        final localStorage = await createFreshLocalStorage();
        final result = await localStorage.hasAccessToken();
        expect(result, false);
      });

      test('hasAccessToken returns true when session exists', () async {
        final localStorage = await createFreshLocalStorage();
        await localStorage.persistSession(testSessionValue);
        final result = await localStorage.hasAccessToken();
        expect(result, true);
      });

      test('accessToken returns null when no session exists', () async {
        final localStorage = await createFreshLocalStorage();
        final result = await localStorage.accessToken();
        expect(result, null);
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

        // Verify the session was stored by checking through localStorage's own methods
        final hasToken = await localStorage.hasAccessToken();
        expect(hasToken, true);

        final storedValue = await localStorage.accessToken();
        expect(storedValue, testSessionValue);
      });

      test('removePersistedSession removes session', () async {
        final localStorage = await createFreshLocalStorage();
        // First store a session
        await localStorage.persistSession(testSessionValue);
        expect(await localStorage.hasAccessToken(), true);

        // Then remove it
        await localStorage.removePersistedSession();
        expect(await localStorage.hasAccessToken(), false);
        expect(await localStorage.accessToken(), null);
      });
    });

    // SharedPreferencesGotrueAsyncStorage Tests
    group('SharedPreferencesGotrueAsyncStorage', () {
      late SharedPreferencesGotrueAsyncStorage asyncStorage;
      const testKey = 'test_key';
      const testValue = 'test_value';

      setUp(() async {
        // Set up fake shared preferences
        SharedPreferences.setMockInitialValues({});
        asyncStorage = SharedPreferencesGotrueAsyncStorage();
        // Allow for initialization to complete
        await Future.delayed(const Duration(milliseconds: 100));
      });

      test('setItem stores value for key', () async {
        await asyncStorage.setItem(key: testKey, value: testValue);
        final prefs = await SharedPreferences.getInstance();
        final storedValue = prefs.getString(testKey);
        expect(storedValue, testValue);
      });

      test('getItem returns null when no value exists', () async {
        final result = await asyncStorage.getItem(key: 'non_existent_key');
        expect(result, null);
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
        expect(await asyncStorage.getItem(key: testKey), null);
      });
    });
  });
}
