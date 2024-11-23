import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/src/supabase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './local_storage_stub.dart'
    if (dart.library.html) './local_storage_web.dart' as web;

/// Only used for migration from Hive to SharedPreferences. Not actually in use.
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

/// Combines the storage for pkce and session into one.
///
/// Previously the session got stored by [SupabaseAuth] and the pkce flow by
/// [GoTrueClient] in a separate storage and with different interface.
/// This combiens both into one.
///
/// This introduces another level of abstraction for the actual
/// session storage, but is necessary to prevent breaking changes.
class PkceAndSessionLocalStorage extends GotrueAsyncStorage {
  final LocalStorage sessionLocalStorage;
  final GotrueAsyncStorage pkceAsyncStorage;

  PkceAndSessionLocalStorage(this.sessionLocalStorage, this.pkceAsyncStorage);
  @override
  Future<void> initialize() async {
    await sessionLocalStorage.initialize();
    await pkceAsyncStorage.initialize();
    super.initialize();
  }

  @override
  Future<String?> getItem({required String key}) {
    if (key.endsWith("-code-verifier")) {
      return pkceAsyncStorage.getItem(key: key);
    } else {
      return sessionLocalStorage.accessToken();
    }
  }

  @override
  Future<void> removeItem({required String key}) async {
    if (key.endsWith("-code-verifier")) {
      await pkceAsyncStorage.removeItem(key: key);
    } else {
      await sessionLocalStorage.removePersistedSession();
    }
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    if (key.endsWith("-code-verifier")) {
      await pkceAsyncStorage.setItem(key: key, value: value);
    } else {
      await sessionLocalStorage.persistSession(value);
    }
  }
}
