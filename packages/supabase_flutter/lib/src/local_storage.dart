import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './local_storage_stub.dart'
    if (dart.library.js_interop) './local_storage_web.dart'
    as web;

/// LocalStorage is used to persist the user session in the device.
///
/// See also:
///
///   * [SupabaseAuth], the instance used to manage authentication
///   * [EmptyLocalStorage], used to disable session persistence
///   * [SharedPreferencesLocalStorage], that implements SharedPreferencesAsync
///     as storage method
abstract class LocalStorage {
  const LocalStorage();

  /// Initialize the storage to persist session.
  Future<void> initialize();

  /// Check if there is a persisted session.
  Future<bool> hasAccessToken();

  /// Get the access token from the current persisted session.
  Future<String?> accessToken();

  /// Remove the current persisted session.
  Future<void> removePersistedSession();

  /// Persist a session in the device.
  Future<void> persistSession(String persistSessionString);
}

/// A [LocalStorage] implementation that does nothing. Use this to
/// disable persistence.
class EmptyLocalStorage extends LocalStorage {
  /// Creates a [LocalStorage] instance that disables persistence
  const EmptyLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => Future.value(false);

  @override
  Future<String?> accessToken() => Future.value();

  @override
  Future<void> removePersistedSession() async {}

  @override
  Future<void> persistSession(persistSessionString) async {}
}

/// A [LocalStorage] implementation that implements [SharedPreferencesAsync] as
/// the storage method.
///
/// A session persisted by supabase_flutter v2, which used the legacy
/// [SharedPreferences] API, is moved over to [SharedPreferencesAsync] on
/// [initialize].
class SharedPreferencesLocalStorage extends LocalStorage {
  late final SharedPreferencesAsync _preferences;

  SharedPreferencesLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;
  static const _useWebLocalStorage =
      kIsWeb && bool.fromEnvironment("dart.library.js_interop");

  @override
  Future<void> initialize() async {
    if (!_useWebLocalStorage) {
      WidgetsFlutterBinding.ensureInitialized();
      _preferences = SharedPreferencesAsync();
      await _migrateLegacySession();
    }
  }

  /// Records that [_migrateLegacySession] has run, so that it runs once.
  String get _legacyMigrationKey => '$persistSessionKey-legacy-migrated';

  /// Moves a session written by the legacy [SharedPreferences] API over to
  /// [SharedPreferencesAsync].
  ///
  /// The two APIs do not share a store on every platform, and on the platforms
  /// where they do the legacy one prefixes its keys, so a session written by
  /// supabase_flutter v2 is invisible to [SharedPreferencesAsync].
  ///
  /// Deleting the legacy entry is not enough to make this a one-time move. On
  /// the platforms where both APIs rewrite one file from their own cache, a
  /// later write through either API can bring the deleted entry back, and a
  /// resurrected session would sign a user in again after they signed out.
  /// [_legacyMigrationKey] is what makes the move happen once, and the delete
  /// is only there to keep a stale token from lying around.
  ///
  /// An entry that comes back afterwards is left where it is. It is never read
  /// again, and deleting it would mean a legacy write on every launch: that
  /// write rewrites the whole store even when the key is absent, which on those
  /// same platforms is what drops values the other API wrote.
  Future<void> _migrateLegacySession() async {
    if (await _preferences.containsKey(_legacyMigrationKey)) {
      return;
    }
    final legacyPreferences = await SharedPreferences.getInstance();
    // The instance is shared with the app, which may have loaded it before the
    // session was last written.
    await legacyPreferences.reload();
    final legacySession = legacyPreferences.getString(persistSessionKey);
    await legacyPreferences.remove(persistSessionKey);
    if (legacySession != null &&
        !await _preferences.containsKey(persistSessionKey)) {
      await _preferences.setString(persistSessionKey, legacySession);
    }
    await _preferences.setBool(_legacyMigrationKey, true);
  }

  @override
  Future<bool> hasAccessToken() async {
    if (_useWebLocalStorage) {
      return web.hasAccessToken(persistSessionKey);
    }
    return _preferences.containsKey(persistSessionKey);
  }

  @override
  Future<String?> accessToken() async {
    if (_useWebLocalStorage) {
      return web.accessToken(persistSessionKey);
    }
    return _preferences.getString(persistSessionKey);
  }

  @override
  Future<void> removePersistedSession() async {
    if (_useWebLocalStorage) {
      web.removePersistedSession(persistSessionKey);
    } else {
      await _preferences.remove(persistSessionKey);
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    if (_useWebLocalStorage) {
      web.persistSession(persistSessionKey, persistSessionString);
      return;
    }
    await _preferences.setString(persistSessionKey, persistSessionString);
  }
}

/// local storage to store pkce flow code verifier.
class SharedPreferencesGotrueAsyncStorage extends GotrueAsyncStorage {
  SharedPreferencesGotrueAsyncStorage();

  /// Created on first use, since the plugin it talks to is only registered
  /// once the bindings are initialized.
  late final SharedPreferencesAsync _preferences = _createPreferences();

  static SharedPreferencesAsync _createPreferences() {
    WidgetsFlutterBinding.ensureInitialized();
    return SharedPreferencesAsync();
  }

  @override
  Future<String?> getItem({required String key}) => _preferences.getString(key);

  @override
  Future<void> removeItem({required String key}) => _preferences.remove(key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      _preferences.setString(key, value);
}
