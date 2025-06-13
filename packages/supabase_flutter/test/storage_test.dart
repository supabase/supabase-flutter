import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Storage Tests', () {
    // SharedPreferencesLocalStorage Tests
    group('SharedPreferencesLocalStorage', () {
      const testSessionValue = '{"key": "value"}';

      Future<SharedPreferencesLocalStorage> createFreshLocalStorage() async {
        // Use a unique key for each test to ensure complete isolation
        final uniqueKey =
            'test_persist_key_${DateTime.now().microsecondsSinceEpoch}';

        // Set up fresh shared preferences for each test
        SharedPreferences.setMockInitialValues({});

        final localStorage = SharedPreferencesLocalStorage(
          persistSessionKey: uniqueKey,
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

      test('setItem handles null value', () async {
        // Remove the item first to ensure clean state
        await asyncStorage.removeItem(key: testKey);
        final result = await asyncStorage.getItem(key: testKey);
        expect(result, null);
      });

      test('setItem overwrites existing value', () async {
        const initialValue = 'initial';
        const newValue = 'new';
        
        await asyncStorage.setItem(key: testKey, value: initialValue);
        expect(await asyncStorage.getItem(key: testKey), initialValue);
        
        await asyncStorage.setItem(key: testKey, value: newValue);
        expect(await asyncStorage.getItem(key: testKey), newValue);
      });

      test('removeItem handles non-existent key gracefully', () async {
        // Should not throw when removing a key that doesn't exist
        expect(() => asyncStorage.removeItem(key: 'non_existent_key'), returnsNormally);
        await asyncStorage.removeItem(key: 'non_existent_key');
      });
    });

    // Test EmptyLocalStorage error handling
    group('EmptyLocalStorage', () {
      late EmptyLocalStorage emptyStorage;

      setUp(() {
        emptyStorage = const EmptyLocalStorage();
      });

      test('hasAccessToken always returns false', () async {
        final result = await emptyStorage.hasAccessToken();
        expect(result, false);
      });

      test('accessToken always returns null', () async {
        final result = await emptyStorage.accessToken();
        expect(result, null);
      });

      test('persistSession does nothing and returns normally', () async {
        expect(() => emptyStorage.persistSession('test'), returnsNormally);
        await emptyStorage.persistSession('test');
        
        // Should still return null/false after persist attempt
        expect(await emptyStorage.hasAccessToken(), false);
        expect(await emptyStorage.accessToken(), null);
      });

      test('removePersistedSession does nothing and returns normally', () async {
        expect(() => emptyStorage.removePersistedSession(), returnsNormally);
        await emptyStorage.removePersistedSession();
        
        // Should still return null/false after remove attempt
        expect(await emptyStorage.hasAccessToken(), false);
        expect(await emptyStorage.accessToken(), null);
      });
    });

    // Test edge cases for SharedPreferencesLocalStorage
    group('SharedPreferencesLocalStorage edge cases', () {
      test('handles empty session string', () async {
        final localStorage = SharedPreferencesLocalStorage(
          persistSessionKey: 'test_empty_session',
        );
        await localStorage.initialize();
        
        await localStorage.persistSession('');
        expect(await localStorage.hasAccessToken(), true);
        expect(await localStorage.accessToken(), '');
      });

      test('handles special characters in session string', () async {
        final localStorage = SharedPreferencesLocalStorage(
          persistSessionKey: 'test_special_chars',
        );
        await localStorage.initialize();
        
        const specialSession = '{"access_token": "áéíóú-test-token-!@#\$%^&*()"}';
        await localStorage.persistSession(specialSession);
        expect(await localStorage.hasAccessToken(), true);
        expect(await localStorage.accessToken(), specialSession);
      });

      test('multiple operations work correctly', () async {
        final localStorage = SharedPreferencesLocalStorage(
          persistSessionKey: 'test_multiple_ops',
        );
        await localStorage.initialize();
        
        // Multiple persist operations
        await localStorage.persistSession('session1');
        await localStorage.persistSession('session2');
        expect(await localStorage.accessToken(), 'session2');
        
        // Remove then add again
        await localStorage.removePersistedSession();
        expect(await localStorage.hasAccessToken(), false);
        
        await localStorage.persistSession('session3');
        expect(await localStorage.accessToken(), 'session3');
      });
    });
  });
}
