@TestOn('!browser')
/// Tests for the migration of a v2 session over to [SharedPreferencesAsync].
///
/// On web the session is stored in `window.localStorage` under the same key as
/// it was in v2, so there is nothing to migrate there.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesLocalStorage migration from v2', () {
    const persistSessionKey = 'sb-test-auth-token';
    const testSessionValue = '{"key": "value"}';

    test('moves a session written by the legacy API over', () async {
      mockSharedPreferences(
        legacyValues: {persistSessionKey: testSessionValue},
      );
      final localStorage = SharedPreferencesLocalStorage(
        persistSessionKey: persistSessionKey,
      );
      await localStorage.initialize();

      expect(await localStorage.accessToken(), testSessionValue);
      expect(
        await SharedPreferencesAsync().getString(persistSessionKey),
        testSessionValue,
      );
    });

    test('removes the session from the legacy store', () async {
      mockSharedPreferences(
        legacyValues: {persistSessionKey: testSessionValue},
      );
      final localStorage = SharedPreferencesLocalStorage(
        persistSessionKey: persistSessionKey,
      );
      await localStorage.initialize();

      final legacyPreferences = await SharedPreferences.getInstance();
      expect(legacyPreferences.getString(persistSessionKey), isNull);
    });

    test('keeps the session of the new store when both have one', () async {
      mockSharedPreferences(
        legacyValues: {persistSessionKey: '{"key": "legacy"}'},
      );
      await SharedPreferencesAsync().setString(
        persistSessionKey,
        testSessionValue,
      );
      final localStorage = SharedPreferencesLocalStorage(
        persistSessionKey: persistSessionKey,
      );
      await localStorage.initialize();

      expect(await localStorage.accessToken(), testSessionValue);
    });

    test('does not restore a session that was signed out of', () async {
      mockSharedPreferences(
        legacyValues: {persistSessionKey: testSessionValue},
      );
      final localStorage = SharedPreferencesLocalStorage(
        persistSessionKey: persistSessionKey,
      );
      await localStorage.initialize();
      await localStorage.removePersistedSession();

      // A restart of the app, which runs the migration again.
      final newLocalStorage = SharedPreferencesLocalStorage(
        persistSessionKey: persistSessionKey,
      );
      await newLocalStorage.initialize();

      expect(await newLocalStorage.hasAccessToken(), isFalse);
    });

    test(
      'does not restore a signed-out session when both stores had one',
      () async {
        mockSharedPreferences(
          legacyValues: {persistSessionKey: '{"key": "legacy"}'},
        );
        await SharedPreferencesAsync().setString(
          persistSessionKey,
          testSessionValue,
        );
        final localStorage = SharedPreferencesLocalStorage(
          persistSessionKey: persistSessionKey,
        );
        await localStorage.initialize();
        await localStorage.removePersistedSession();

        // A restart of the app, which runs the migration again.
        final newLocalStorage = SharedPreferencesLocalStorage(
          persistSessionKey: persistSessionKey,
        );
        await newLocalStorage.initialize();

        expect(await newLocalStorage.hasAccessToken(), isFalse);
      },
    );

    test('runs once, so a resurrected legacy entry is ignored', () async {
      mockSharedPreferences(
        legacyValues: {persistSessionKey: testSessionValue},
      );
      final localStorage = SharedPreferencesLocalStorage(
        persistSessionKey: persistSessionKey,
      );
      await localStorage.initialize();
      await localStorage.removePersistedSession();

      // Stands in for the platforms where a write through either API can bring
      // a deleted entry of the other one back.
      final legacyPreferences = await SharedPreferences.getInstance();
      await legacyPreferences.setString(persistSessionKey, testSessionValue);

      final newLocalStorage = SharedPreferencesLocalStorage(
        persistSessionKey: persistSessionKey,
      );
      await newLocalStorage.initialize();

      expect(await newLocalStorage.hasAccessToken(), isFalse);
    });

    test('keeps the session when the legacy entry cannot be deleted', () async {
      mockSharedPreferences();
      SharedPreferencesStorePlatform.instance = _ReadOnlyLegacyStore({
        'flutter.$persistSessionKey': testSessionValue,
      });
      final localStorage = SharedPreferencesLocalStorage(
        persistSessionKey: persistSessionKey,
      );

      // The new store is written before the legacy entry is deleted, so a
      // failure to delete costs a leftover entry rather than the session.
      await localStorage.initialize();

      expect(await localStorage.accessToken(), testSessionValue);
    });

    test('initializes even when the legacy store cannot be read', () async {
      mockSharedPreferences();
      SharedPreferencesStorePlatform.instance = _ThrowingLegacyStore();
      final localStorage = SharedPreferencesLocalStorage(
        persistSessionKey: persistSessionKey,
      );

      await expectLater(localStorage.initialize(), completes);
      await localStorage.persistSession(testSessionValue);
      expect(await localStorage.accessToken(), testSessionValue);
    });
  });

  group('SharedPreferencesGotrueAsyncStorage migration from v2', () {
    const codeVerifierKey = 'supabase.auth.token-code-verifier';
    const codeVerifier = 'raw-code-verifier';

    test('moves a code verifier written by the legacy API over', () async {
      mockSharedPreferences(legacyValues: {codeVerifierKey: codeVerifier});
      final storage = SharedPreferencesGotrueAsyncStorage();

      expect(await storage.getItem(key: codeVerifierKey), codeVerifier);
      expect(
        await SharedPreferencesAsync().getString(codeVerifierKey),
        codeVerifier,
      );
      final legacyPreferences = await SharedPreferences.getInstance();
      expect(legacyPreferences.getString(codeVerifierKey), isNull);
    });

    test('does not resurrect a verifier that was used up', () async {
      mockSharedPreferences(legacyValues: {codeVerifierKey: codeVerifier});
      final storage = SharedPreferencesGotrueAsyncStorage();
      expect(await storage.getItem(key: codeVerifierKey), codeVerifier);

      await storage.removeItem(key: codeVerifierKey);

      expect(await storage.getItem(key: codeVerifierKey), isNull);
    });

    test('returns null when the legacy store cannot be read', () async {
      mockSharedPreferences();
      SharedPreferencesStorePlatform.instance = _ThrowingLegacyStore();
      final storage = SharedPreferencesGotrueAsyncStorage();

      expect(await storage.getItem(key: codeVerifierKey), isNull);
    });
  });
}

/// Stands in for a legacy store that can be read but not written.
class _ReadOnlyLegacyStore extends SharedPreferencesStorePlatform {
  _ReadOnlyLegacyStore(this._data);

  final Map<String, Object> _data;

  @override
  Future<bool> clear() => throw UnimplementedError();

  @override
  Future<Map<String, Object>> getAll() async => _data;

  @override
  Future<bool> remove(String key) =>
      throw MissingPluginException('Store is read only');

  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      throw MissingPluginException('Store is read only');
}

/// Stands in for a platform where the legacy API is unavailable or its store
/// cannot be read.
class _ThrowingLegacyStore extends SharedPreferencesStorePlatform {
  @override
  Future<bool> clear() => throw UnimplementedError();

  @override
  Future<Map<String, Object>> getAll() =>
      throw MissingPluginException('No implementation found');

  @override
  Future<bool> remove(String key) => throw UnimplementedError();

  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      throw UnimplementedError();
}
