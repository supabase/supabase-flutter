import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './local_storage_stub.dart'
    if (dart.library.html) './local_storage_web.dart' as web;

const _hiveBoxName = 'supabase_authentication';
const supabasePersistSessionKey = 'SUPABASE_PERSIST_SESSION_KEY';

/// LocalStorage is used to persist the user session in the device.
///
/// See also:
///
///   * [SupabaseAuth], the instance used to manage authentication
///   * [EmptyLocalStorage], used to disable session persistence
///   * [HiveLocalStorage], that implements Hive as storage method
///   * [SharedPreferencesLocalStorage], that implements SharedPreferences as storage method
///   * [MigrationLocalStorage], to migrate from Hive to SharedPreferences
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

/// A [LocalStorage] implementation that implements Hive as the
/// storage method.
class HiveLocalStorage extends LocalStorage {
  /// Creates a LocalStorage instance that implements the Hive Database
  const HiveLocalStorage();

  /// The encryption key used by Hive. If null, the box is not encrypted
  ///
  /// This value should not be redefined in runtime, otherwise the user may
  /// not be fetched correctly
  ///
  /// See also:
  ///
  ///   * <https://docs.hivedb.dev/#/advanced/encrypted_box?id=encrypted-box>
  static String? encryptionKey;

  @override
  Future<void> initialize() async {
    HiveCipher? encryptionCipher;
    if (encryptionKey != null) {
      encryptionCipher = HiveAesCipher(base64Url.decode(encryptionKey!));
    }
    await Hive.initFlutter('auth');
    await Hive.openBox(_hiveBoxName, encryptionCipher: encryptionCipher);
  }

  @override
  Future<bool> hasAccessToken() {
    return Future.value(
      Hive.box(_hiveBoxName).containsKey(
        supabasePersistSessionKey,
      ),
    );
  }

  @override
  Future<String?> accessToken() {
    return Future.value(
      Hive.box(_hiveBoxName).get(supabasePersistSessionKey) as String?,
    );
  }

  @override
  Future<void> removePersistedSession() {
    return Hive.box(_hiveBoxName).delete(supabasePersistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) {
    // Flush after X amount of writes
    return Hive.box(_hiveBoxName)
        .put(supabasePersistSessionKey, persistSessionString);
  }
}

/// A [LocalStorage] implementation that implements SharedPreferences as the
/// storage method.
class SharedPreferencesLocalStorage extends LocalStorage {
  late final SharedPreferences _prefs;

  SharedPreferencesLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;
  static const _useWebLocalStorage =
      kIsWeb && bool.fromEnvironment("dart.library.html");

  @override
  Future<void> initialize() async {
    if (!_useWebLocalStorage) {
      WidgetsFlutterBinding.ensureInitialized();
      _prefs = await SharedPreferences.getInstance();
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    if (_useWebLocalStorage) {
      return web.hasAccessToken(persistSessionKey);
    }
    return _prefs.containsKey(persistSessionKey);
  }

  @override
  Future<String?> accessToken() async {
    if (_useWebLocalStorage) {
      return web.accessToken(persistSessionKey);
    }
    return _prefs.getString(persistSessionKey);
  }

  @override
  Future<void> removePersistedSession() async {
    if (_useWebLocalStorage) {
      web.removePersistedSession(persistSessionKey);
    } else {
      await _prefs.remove(persistSessionKey);
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) {
    if (_useWebLocalStorage) {
      return web.persistSession(persistSessionKey, persistSessionString);
    }
    return _prefs.setString(persistSessionKey, persistSessionString);
  }
}

class MigrationLocalStorage extends LocalStorage {
  final SharedPreferencesLocalStorage sharedPreferencesLocalStorage;
  late final HiveLocalStorage hiveLocalStorage;

  MigrationLocalStorage({required String persistSessionKey})
      : sharedPreferencesLocalStorage =
            SharedPreferencesLocalStorage(persistSessionKey: persistSessionKey);

  @override
  Future<void> initialize() async {
    await Hive.initFlutter('auth');
    hiveLocalStorage = const HiveLocalStorage();
    await sharedPreferencesLocalStorage.initialize();
    await migrate();
  }

  @visibleForTesting
  Future<void> migrate() async {
    // Migrate from Hive to SharedPreferences
    if (await Hive.boxExists(_hiveBoxName)) {
      await hiveLocalStorage.initialize();

      final hasHive = await hiveLocalStorage.hasAccessToken();
      if (hasHive) {
        final accessToken = await hiveLocalStorage.accessToken();
        final session =
            Session.fromJson(jsonDecode(accessToken!)['currentSession']);
        if (session == null) {
          return;
        }
        await sharedPreferencesLocalStorage
            .persistSession(jsonEncode(session.toJson()));
        await hiveLocalStorage.removePersistedSession();
      }
      if (Hive.box(_hiveBoxName).isEmpty) {
        final boxPath = Hive.box(_hiveBoxName).path;
        await Hive.deleteBoxFromDisk(_hiveBoxName);

        //Delete `auth` folder if it's empty
        if (!kIsWeb && boxPath != null) {
          final boxDir = File(boxPath).parent;
          final dirIsEmpty = await boxDir.list().length == 0;
          if (dirIsEmpty) {
            await boxDir.delete();
          }
        }
      }
    }
  }

  @override
  Future<String?> accessToken() {
    return sharedPreferencesLocalStorage.accessToken();
  }

  @override
  Future<bool> hasAccessToken() {
    return sharedPreferencesLocalStorage.hasAccessToken();
  }

  @override
  Future<void> persistSession(String persistSessionString) {
    return sharedPreferencesLocalStorage.persistSession(persistSessionString);
  }

  @override
  Future<void> removePersistedSession() {
    return sharedPreferencesLocalStorage.removePersistedSession();
  }
}

/// local storage to store pkce flow code verifier.
class SharedPreferencesGotrueAsyncStorage extends GotrueAsyncStorage {
  SharedPreferencesGotrueAsyncStorage() {
    _initialize();
  }

  final Completer<void> _initializationCompleter = Completer();

  late final SharedPreferences _prefs;

  Future<void> _initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    _prefs = await SharedPreferences.getInstance();
    _initializationCompleter.complete();
  }

  @override
  Future<String?> getItem({required String key}) async {
    await _initializationCompleter.future;
    return _prefs.getString(key);
  }

  @override
  Future<void> removeItem({required String key}) async {
    await _initializationCompleter.future;
    await _prefs.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    await _initializationCompleter.future;
    await _prefs.setString(key, value);
  }
}
