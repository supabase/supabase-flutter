@TestOn('!browser')
/// Tests for the migration of values written by supabase_flutter v2 through
/// the legacy [SharedPreferences] API over to [SharedPreferencesAsync].
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

  group('SharedPreferencesAuthAsyncStorage migration of a v2 session', () {
    const sessionKey = 'sb-test-auth-token';
    const testSessionValue = '{"key": "value"}';

    test('moves a session written by the legacy API over', () async {
      mockSharedPreferences(legacyValues: {sessionKey: testSessionValue});
      final storage = SharedPreferencesAuthAsyncStorage();

      expect(await storage.getItem(sessionKey), testSessionValue);
      expect(
        await SharedPreferencesAsync().getString(sessionKey),
        testSessionValue,
      );
    });

    test('removes the session from the legacy store', () async {
      mockSharedPreferences(legacyValues: {sessionKey: testSessionValue});
      final storage = SharedPreferencesAuthAsyncStorage();

      await storage.getItem(sessionKey);

      final legacyPreferences = await SharedPreferences.getInstance();
      expect(legacyPreferences.getString(sessionKey), isNull);
    });

    test('keeps the session of the new store when both have one', () async {
      mockSharedPreferences(legacyValues: {sessionKey: '{"key": "legacy"}'});
      await SharedPreferencesAsync().setString(sessionKey, testSessionValue);
      final storage = SharedPreferencesAuthAsyncStorage();

      expect(await storage.getItem(sessionKey), testSessionValue);
    });

    test('does not restore a session that was signed out of', () async {
      mockSharedPreferences(legacyValues: {sessionKey: testSessionValue});
      final storage = SharedPreferencesAuthAsyncStorage();
      await storage.getItem(sessionKey);
      await storage.removeItem(sessionKey);

      // A restart of the app, which reads the storage again.
      final newStorage = SharedPreferencesAuthAsyncStorage();

      expect(await newStorage.getItem(sessionKey), isNull);
    });

    test(
      'does not restore a signed-out session when both stores had one',
      () async {
        mockSharedPreferences(
          legacyValues: {sessionKey: '{"key": "legacy"}'},
        );
        await SharedPreferencesAsync().setString(sessionKey, testSessionValue);
        final storage = SharedPreferencesAuthAsyncStorage();
        await storage.getItem(sessionKey);
        await storage.removeItem(sessionKey);

        // A restart of the app, which reads the storage again.
        final newStorage = SharedPreferencesAuthAsyncStorage();

        expect(await newStorage.getItem(sessionKey), isNull);
        final legacyPreferences = await SharedPreferences.getInstance();
        expect(legacyPreferences.getString(sessionKey), isNull);
      },
    );

    test('runs once, so a resurrected legacy entry is ignored', () async {
      mockSharedPreferences(legacyValues: {sessionKey: testSessionValue});
      final storage = SharedPreferencesAuthAsyncStorage();
      await storage.getItem(sessionKey);
      await storage.removeItem(sessionKey);

      // Stands in for the platforms where a write through either API can bring
      // a deleted entry of the other one back.
      final legacyPreferences = await SharedPreferences.getInstance();
      await legacyPreferences.setString(sessionKey, testSessionValue);

      final newStorage = SharedPreferencesAuthAsyncStorage();

      expect(await newStorage.getItem(sessionKey), isNull);
    });

    test('keeps the session when the legacy entry cannot be deleted', () async {
      mockSharedPreferences();
      SharedPreferencesStorePlatform.instance = _ReadOnlyLegacyStore({
        'flutter.$sessionKey': testSessionValue,
      });
      final storage = SharedPreferencesAuthAsyncStorage();

      // The new store is written before the legacy entry is deleted, so a
      // failure to delete costs a leftover entry rather than the session.
      expect(await storage.getItem(sessionKey), testSessionValue);
      expect(
        await SharedPreferencesAsync().getString(sessionKey),
        testSessionValue,
      );
    });

    test('works even when the legacy store cannot be read', () async {
      mockSharedPreferences();
      SharedPreferencesStorePlatform.instance = _ThrowingLegacyStore();
      final storage = SharedPreferencesAuthAsyncStorage();

      expect(await storage.getItem(sessionKey), isNull);
      await storage.setItem(sessionKey, testSessionValue);
      expect(await storage.getItem(sessionKey), testSessionValue);
      await expectLater(storage.removeItem(sessionKey), completes);
    });
  });

  group('SharedPreferencesAuthAsyncStorage migration of a v2 verifier', () {
    const codeVerifierKey = 'supabase.auth.token-code-verifier';
    const codeVerifier = 'raw-code-verifier';

    test('moves a code verifier written by the legacy API over', () async {
      mockSharedPreferences(legacyValues: {codeVerifierKey: codeVerifier});
      final storage = SharedPreferencesAuthAsyncStorage();

      expect(await storage.getItem(codeVerifierKey), codeVerifier);
      expect(
        await SharedPreferencesAsync().getString(codeVerifierKey),
        codeVerifier,
      );
      final legacyPreferences = await SharedPreferences.getInstance();
      expect(legacyPreferences.getString(codeVerifierKey), isNull);
    });

    test('does not resurrect a verifier that was used up', () async {
      mockSharedPreferences(legacyValues: {codeVerifierKey: codeVerifier});
      final storage = SharedPreferencesAuthAsyncStorage();
      expect(await storage.getItem(codeVerifierKey), codeVerifier);

      await storage.removeItem(codeVerifierKey);

      expect(await storage.getItem(codeVerifierKey), isNull);
    });

    test('leaves no trace for a key the legacy store never had', () async {
      mockSharedPreferences();
      final storage = SharedPreferencesAuthAsyncStorage();

      await storage.getItem(codeVerifierKey);
      await storage.removeItem(codeVerifierKey);

      expect(await SharedPreferencesAsync().getKeys(), isEmpty);
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
