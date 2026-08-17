import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './local_storage_stub.dart'
    if (dart.library.js_interop) './local_storage_web.dart'
    as web;

final _log = Logger('supabase.supabase_flutter');

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
  ///
  /// A failure to read the legacy store costs the user a sign-in, so it is
  /// logged rather than thrown: throwing here would take `Supabase.initialize`
  /// with it and leave the app unable to start over a session it may not even
  /// have.
  Future<void> _migrateLegacySession() async {
    final stored = await _preferences.getAll(
      allowList: {persistSessionKey, _legacyMigrationKey},
    );
    if (stored.containsKey(_legacyMigrationKey)) {
      return;
    }
    try {
      final legacyPreferences = await SharedPreferences.getInstance();
      final legacySession = legacyPreferences.getString(persistSessionKey);
      // The new store is written first, so that an interruption before the
      // legacy entry is gone leaves the session in one store or the other
      // rather than in neither.
      if (legacySession != null && !stored.containsKey(persistSessionKey)) {
        await _preferences.setString(persistSessionKey, legacySession);
      }
      await _preferences.setBool(_legacyMigrationKey, true);
      if (legacySession != null) {
        // Picks up what was just written through the other API. Without it the
        // legacy cache is a pre-migration snapshot, and on the platforms where
        // the two share a file the next legacy write by the app would rewrite
        // the file from that snapshot, taking the migrated session with it.
        await legacyPreferences.reload();
        await legacyPreferences.remove(persistSessionKey);
      }
    } catch (error, stackTrace) {
      _log.warning('Could not migrate the session', error, stackTrace);
    }
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
class SharedPreferencesAuthAsyncStorage extends AuthAsyncStorage {
  SharedPreferencesAuthAsyncStorage() {
    WidgetsFlutterBinding.ensureInitialized();
  }

  /// Created on first use, since the plugin it talks to is only registered
  /// once the bindings are initialized.
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<String?> getItem({required String key}) async {
    return await _preferences.getString(key) ?? await _legacyItem(key);
  }

  /// Moves a value written by the legacy [SharedPreferences] API over to
  /// [SharedPreferencesAsync].
  ///
  /// A code verifier outlives the launch that wrote it: a magic link or a
  /// password reset can be opened long after the app updated, and the flow it
  /// belongs to cannot be completed without the verifier that started it.
  Future<String?> _legacyItem(String key) async {
    try {
      final legacyPreferences = await SharedPreferences.getInstance();
      final value = legacyPreferences.getString(key);
      if (value == null) {
        return null;
      }
      await _preferences.setString(key, value);
      await legacyPreferences.reload();
      await legacyPreferences.remove(key);
      return value;
    } catch (error, stackTrace) {
      _log.warning('Could not read the legacy store', error, stackTrace);
      return null;
    }
  }

  @override
  Future<void> removeItem({required String key}) => _preferences.remove(key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      _preferences.setString(key, value);
}
