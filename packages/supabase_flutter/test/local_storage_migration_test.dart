@TestOn('!browser')
/// Tests for the migration of a v2 session over to [SharedPreferencesAsync].
///
/// On web the session is stored in `window.localStorage` under the same key as
/// it was in v2, so there is nothing to migrate there.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  });
}
