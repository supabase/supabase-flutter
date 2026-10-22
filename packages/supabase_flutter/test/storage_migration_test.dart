@TestOn('!browser')
/// Tests for the migration of values written by supabase_flutter v2 through
/// the legacy [SharedPreferences] API over to [SharedPreferencesAsync].
///
/// On web the session is stored in `window.localStorage` under the same key as
/// it was in v2, so there is nothing to migrate there.
library;

import 'dart:convert';

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

    test(
      'does not restore a legacy session after a sign-out during which the '
      'legacy store could not be read',
      () async {
        mockSharedPreferences();
        SharedPreferencesStorePlatform.instance = _ThrowingLegacyStore();
        final storage = SharedPreferencesAuthAsyncStorage();
        await storage.setItem(sessionKey, testSessionValue);
        await storage.removeItem(sessionKey);

        // The legacy store is readable again and still holds a v2 session.
        SharedPreferences.setMockInitialValues({sessionKey: testSessionValue});
        final newStorage = SharedPreferencesAuthAsyncStorage();

        expect(await newStorage.getItem(sessionKey), isNull);
      },
    );
  });

  group('Supabase.initialize with a v2 session', () {
    const supabaseUrl = 'https://abcdefghij.supabase.co';

    tearDown(() async {
      await Supabase.instance.dispose();
    });

    test('restores the session supabase_flutter v2 persisted', () async {
      final expiresAt =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      final accessToken = unsignedTestJwt({
        'exp': expiresAt,
        'sub': testUserId,
        'role': 'authenticated',
      });
      // The value v2 wrote: `jsonEncode(session.toJson())` under the key it
      // derived from the project ref.
      final v2Session = jsonEncode({
        'access_token': accessToken,
        'expires_in': 3600,
        'expires_at': expiresAt,
        'refresh_token': 'v2-refresh-token',
        'token_type': 'bearer',
        'provider_token': null,
        'provider_refresh_token': null,
        'user': {
          'id': testUserId,
          'app_metadata': {
            'provider': 'email',
            'providers': ['email'],
          },
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'confirmation_sent_at': null,
          'recovery_sent_at': null,
          'email_change_sent_at': null,
          'new_email': null,
          'invited_at': null,
          'action_link': null,
          'email': 'v2@example.com',
          'phone': '',
          'created_at': '2024-05-01T12:00:00.000000Z',
          'confirmed_at': '2024-05-01T12:00:00.000000Z',
          'email_confirmed_at': '2024-05-01T12:00:00.000000Z',
          'phone_confirmed_at': null,
          'last_sign_in_at': '2024-05-02T08:30:00.000000Z',
          'role': 'authenticated',
          'updated_at': '2024-05-02T08:30:00.000000Z',
          'identities': [
            {
              'id': testUserId,
              'user_id': testUserId,
              'identity_data': {'email': 'v2@example.com', 'sub': testUserId},
              'identity_id': '6b1f5c2e-7a52-4d0b-9a1e-0f3f4c1d2e3a',
              'provider': 'email',
              'created_at': '2024-05-01T12:00:00.000000Z',
              'last_sign_in_at': '2024-05-02T08:30:00.000000Z',
              'updated_at': '2024-05-02T08:30:00.000000Z',
            },
          ],
          'factors': null,
          'is_anonymous': false,
        },
      });
      mockSharedPreferences(
        legacyValues: {'sb-abcdefghij-auth-token': v2Session},
      );

      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: '',
        httpClient: MockSupabaseHttpClient(),
        authOptions: const FlutterAuthClientOptions(
          detectSessionInUri: false,
        ),
      );

      final session = Supabase.instance.client.auth.currentSession;
      expect(session?.accessToken, accessToken);
      expect(session?.refreshToken, 'v2-refresh-token');
      expect(session?.user.id, testUserId);
      expect(session?.user.email, 'v2@example.com');
      expect(
        await SharedPreferencesAsync().getString('sb-abcdefghij-auth-token'),
        isNotNull,
      );
    });
  });

  group('SharedPreferencesAuthAsyncStorage operation order', () {
    const sessionKey = 'sb-test-auth-token';

    test(
      'a write during a legacy migration wins over the legacy value',
      () async {
        mockSharedPreferences();
        SharedPreferencesStorePlatform.instance = _SlowLegacyStore({
          'flutter.$sessionKey': '{"key": "legacy"}',
        });
        final storage = SharedPreferencesAuthAsyncStorage();

        final read = storage.getItem(sessionKey);
        await storage.setItem(sessionKey, '{"key": "new"}');

        expect(await read, '{"key": "legacy"}');
        expect(await storage.getItem(sessionKey), '{"key": "new"}');
      },
    );

    test('a removal during a legacy migration is not undone', () async {
      mockSharedPreferences();
      SharedPreferencesStorePlatform.instance = _SlowLegacyStore({
        'flutter.$sessionKey': '{"key": "legacy"}',
      });
      final storage = SharedPreferencesAuthAsyncStorage();

      final read = storage.getItem(sessionKey);
      await storage.removeItem(sessionKey);

      expect(await read, '{"key": "legacy"}');
      expect(await storage.getItem(sessionKey), isNull);
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

/// Stands in for a legacy store that takes a while to answer, so that another
/// operation can be started while a migration is still reading it.
class _SlowLegacyStore extends SharedPreferencesStorePlatform {
  _SlowLegacyStore(this._data);

  final Map<String, Object> _data;

  @override
  Future<bool> clear() => throw UnimplementedError();

  @override
  Future<Map<String, Object>> getAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return Map.of(_data);
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    _data[key] = value;
    return true;
  }
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
