import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/src/supabase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './local_storage_stub.dart'
    if (dart.library.js_interop) './local_storage_web.dart' as web;

/// Only used for migration from Hive to SharedPreferences. Not actually in use.
const supabasePersistSessionKey = 'SUPABASE_PERSIST_SESSION_KEY';

/// LocalStorage is used to persist the user session in the device.
///
/// See also:
///
///   * [SupabaseAuth], the instance used to manage authentication
///   * [EmptyLocalStorage], used to disable session persistence
///   * [SharedPreferencesLocalStorage], that implements SharedPreferences as storage method
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

  /// Shared preferences already use the local storage on web, but the package
  /// adds an additional prefix to the key.
  /// To support integrating with a session stored by the supabase-js client,
  /// we need to access the local storage directly on web, and use the shared
  /// preferences on other platforms.
  static const _useWebLocalStorage =
      kIsWeb && bool.fromEnvironment("dart.library.js_interop");

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

/// A [GotrueAsyncStorage] implementation that implements SharedPreferences as
/// the storage method.
class SharedPreferencesGotrueAsyncStorage extends GotrueAsyncStorage {
  late final SharedPreferences _prefs;

  /// Shared preferences already use the local storage on web, but the package
  /// adds an additional prefix to the key.
  /// To support integrating with a session/pkce token stored by the supabase-js
  /// client, we need to access the local storage directly on web, and use the
  /// shared preferences on other platforms.
  static const _useWebLocalStorage =
      kIsWeb && bool.fromEnvironment("dart.library.js_interop");

  @override
  Future<void> initialize() async {
    if (!_useWebLocalStorage) {
      WidgetsFlutterBinding.ensureInitialized();
      _prefs = await SharedPreferences.getInstance();
    }
  }

  @override
  Future<String?> getItem(String key) async {
    if (_useWebLocalStorage) {
      // Despite its name, it just accesses the local storage with the given key
      return web.accessToken(key);
    }
    return _prefs.getString(key);
  }

  @override
  Future<void> removeItem(String key) async {
    if (_useWebLocalStorage) {
      // Despite its name, it just removes the item from local storage with the
      // given key
      return web.removePersistedSession(key);
    }
    await _prefs.remove(key);
  }

  @override
  Future<void> setItem(String key, String value) async {
    if (_useWebLocalStorage) {
      // Despite its name, it just sets the item in local storage with the given
      // key and value
      return web.persistSession(key, value);
    }
    await _prefs.setString(key, value);
  }
}

/// Combines the storage for pkce and session into one.
///
/// Previously the session got stored by [SupabaseAuth] and the pkce flow by
/// [GoTrueClient] in a separate storage and with different interface.
/// This combines both into one.
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
  Future<String?> getItem(String key) {
    if (key.endsWith("-code-verifier")) {
      return pkceAsyncStorage.getItem(key);
    } else {
      return sessionLocalStorage.accessToken();
    }
  }

  @override
  Future<void> removeItem(String key) async {
    if (key.endsWith("-code-verifier")) {
      await pkceAsyncStorage.removeItem(key);
    } else {
      await sessionLocalStorage.removePersistedSession();
    }
  }

  @override
  Future<void> setItem(String key, String value) async {
    if (key.endsWith("-code-verifier")) {
      await pkceAsyncStorage.setItem(key, value);
    } else {
      await sessionLocalStorage.persistSession(value);
    }
  }
}
