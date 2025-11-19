import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final _log = Logger('supabase.local_storage');

  SharedPreferencesLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;
  static const _useWebLocalStorage =
      kIsWeb && bool.fromEnvironment("dart.library.js_interop");

  @override
  Future<void> initialize() async {
    _log.fine(
        'Initializing SharedPreferencesLocalStorage (key: $persistSessionKey, useWeb: $_useWebLocalStorage)');
    if (!_useWebLocalStorage) {
      WidgetsFlutterBinding.ensureInitialized();
      _prefs = await SharedPreferences.getInstance();
      _log.fine('SharedPreferences initialized');
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    if (_useWebLocalStorage) {
      final result = web.hasAccessToken(persistSessionKey);
      _log.finest('hasAccessToken (web): $result');
      return result;
    }
    final result = _prefs.containsKey(persistSessionKey);
    _log.finest('hasAccessToken: $result');
    return result;
  }

  @override
  Future<String?> accessToken() async {
    if (_useWebLocalStorage) {
      final token = await web.accessToken(persistSessionKey);
      _log.finest(
          'accessToken (web): ${token != null ? "found (${token.length} chars)" : "null"}');
      return token;
    }
    final token = _prefs.getString(persistSessionKey);
    _log.finest(
        'accessToken: ${token != null ? "found (${token.length} chars)" : "null"}');
    return token;
  }

  @override
  Future<void> removePersistedSession() async {
    _log.fine('Removing persisted session from storage');
    if (_useWebLocalStorage) {
      web.removePersistedSession(persistSessionKey);
    } else {
      await _prefs.remove(persistSessionKey);
    }
    _log.fine('Persisted session removed');
  }

  @override
  Future<void> persistSession(String persistSessionString) {
    _log.fine(
        'Persisting session to storage (${persistSessionString.length} chars)');
    if (_useWebLocalStorage) {
      return web.persistSession(persistSessionKey, persistSessionString);
    }
    return _prefs.setString(persistSessionKey, persistSessionString);
  }
}

/// local storage to store pkce flow code verifier.
class SharedPreferencesGotrueAsyncStorage extends GotrueAsyncStorage {
  final _log = Logger('supabase.async_storage');

  SharedPreferencesGotrueAsyncStorage() {
    _initialize();
  }

  final Completer<void> _initializationCompleter = Completer();

  late final SharedPreferences _prefs;

  Future<void> _initialize() async {
    _log.fine('Initializing SharedPreferencesGotrueAsyncStorage');
    WidgetsFlutterBinding.ensureInitialized();
    _prefs = await SharedPreferences.getInstance();
    _initializationCompleter.complete();
    _log.fine('SharedPreferencesGotrueAsyncStorage initialized');
  }

  @override
  Future<String?> getItem({required String key}) async {
    await _initializationCompleter.future;
    final value = _prefs.getString(key);
    _log.finest(
        'getItem($key): ${value != null ? "found (${value.length} chars)" : "null"}');
    return value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    await _initializationCompleter.future;
    _log.fine('removeItem($key)');
    await _prefs.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    await _initializationCompleter.future;
    _log.fine('setItem($key, ${value.length} chars)');
    await _prefs.setString(key, value);
  }
}
