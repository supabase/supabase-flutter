import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/src/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './shared_preferences_storage_stub.dart'
    if (dart.library.js_interop) './shared_preferences_storage_web.dart'
    as web;

/// The [AuthAsyncStorage] that `Supabase.initialize` uses unless another one
/// is passed, holding the session and the pkce code verifiers.
///
/// Writes through the [SharedPreferencesAsync] API of `shared_preferences`,
/// except on web where it uses `window.localStorage` directly so the session
/// is shared with supabase-js under the same key.
///
/// A value written by supabase_flutter v2 through the legacy
/// [SharedPreferences] API is moved over to [SharedPreferencesAsync] the first
/// time it is read.
class SharedPreferencesAuthAsyncStorage extends AuthAsyncStorage {
  SharedPreferencesAuthAsyncStorage() {
    WidgetsFlutterBinding.ensureInitialized();
  }

  /// Created on first use, since the plugin it talks to is only registered
  /// once the bindings are initialized.
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static const _useWebLocalStorage =
      kIsWeb && bool.fromEnvironment('dart.library.js_interop');

  /// The keys whose legacy value has been looked up in this process. Nothing
  /// writes to the legacy store anymore, so a second lookup would find the
  /// same thing.
  final _legacyChecked = <String>{};

  /// The operation the next one has to wait for.
  ///
  /// A read that moves a legacy value over yields while it consults the legacy
  /// store. Were a write allowed to run in the meantime, the migration would
  /// finish by putting the legacy value over the value just written, or by
  /// bringing back a session that was just signed out of.
  Future<void> _operations = Future.value();

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<String?> getItem(String key) => _serialize(() => _getItem(key));

  @override
  Future<void> setItem(String key, String value) =>
      _serialize(() => _setItem(key, value));

  @override
  Future<void> removeItem(String key) => _serialize(() => _removeItem(key));

  Future<String?> _getItem(String key) async {
    if (_useWebLocalStorage) {
      return _webItem(key) ?? await _migrateLegacyWebItem(key);
    }
    return await _preferences.getString(key) ?? await _migrateLegacyItem(key);
  }

  Future<void> _setItem(String key, String value) async {
    if (_useWebLocalStorage) {
      web.setItem(key, value);
      return;
    }
    await _preferences.setString(key, value);
  }

  Future<void> _removeItem(String key) async {
    if (_useWebLocalStorage) {
      web.removeItem(key);
      await _retireLegacyWebItem(key);
      return;
    }
    await _preferences.remove(key);
    await _retireLegacyItem(key);
  }

  /// Reads [key] from `window.localStorage`.
  ///
  /// Code verifiers used to be written through [SharedPreferencesAsync], which
  /// on web JSON encodes the value under the very same key. Such a value is
  /// decoded and written back as is, so the flow it belongs to can complete.
  String? _webItem(String key) {
    final value = web.getItem(key);
    if (value == null || !value.startsWith('"')) {
      return value;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      return value;
    }
    if (decoded is! String) {
      return value;
    }
    web.setItem(key, decoded);
    return decoded;
  }

  /// Moves a value written by supabase_flutter v2 through the legacy
  /// [SharedPreferences] API over to the plain [key] in `window.localStorage`.
  ///
  /// That API keeps its values under a prefixed key, so a code verifier
  /// written by v2 is not found under [key] until it is moved. Both keys live
  /// in the same `window.localStorage`, so a deleted entry cannot come back
  /// and no marker is needed.
  Future<String?> _migrateLegacyWebItem(String key) async {
    if (_legacyChecked.contains(key)) {
      return null;
    }
    try {
      final legacyPreferences = await SharedPreferences.getInstance();
      final value = legacyPreferences.getString(key);
      _legacyChecked.add(key);
      if (value == null) {
        return null;
      }
      web.setItem(key, value);
      await _removeLegacyItem(legacyPreferences, key);
      return value;
    } catch (error, stackTrace) {
      flutterLogger.warning(
        'Could not read the legacy store',
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// Deletes the value the legacy [SharedPreferences] API holds for [key], so
  /// that a later read cannot move a value over that was removed on purpose.
  Future<void> _retireLegacyWebItem(String key) async {
    if (_legacyChecked.contains(key)) {
      return;
    }
    try {
      final legacyPreferences = await SharedPreferences.getInstance();
      _legacyChecked.add(key);
      if (legacyPreferences.containsKey(key)) {
        await _removeLegacyItem(legacyPreferences, key);
      }
    } catch (error, stackTrace) {
      flutterLogger.warning(
        'Could not read the legacy store',
        error,
        stackTrace,
      );
    }
  }

  /// Records that the legacy value of [key] has been dealt with, so that it is
  /// moved over once.
  ///
  /// Deleting the legacy entry is not enough to make this a one-time move. On
  /// the platforms where both APIs rewrite one file from their own cache, a
  /// later write through either API can bring the deleted entry back, and a
  /// resurrected session would sign a user in again after they signed out.
  static String _migratedKey(String key) => '$key-legacy-migrated';

  /// Whether the legacy value of [key] has not been looked at yet, neither in
  /// this process nor, going by the marker, in an earlier one.
  Future<bool> _isLegacyItemPending(String key) async =>
      !_legacyChecked.contains(key) &&
      !await _preferences.containsKey(_migratedKey(key));

  /// Moves the value the legacy [SharedPreferences] API holds for [key] over to
  /// [SharedPreferencesAsync] and returns it.
  ///
  /// The two APIs do not share a store on every platform, and on the platforms
  /// where they do the legacy one prefixes its keys, so a value written by
  /// supabase_flutter v2 is invisible to [SharedPreferencesAsync].
  ///
  /// A failure to read the legacy store costs the user a sign-in, so it is
  /// logged rather than thrown: throwing here would take `Supabase.initialize`
  /// with it and leave the app unable to start over a session it may not even
  /// have.
  Future<String?> _migrateLegacyItem(String key) async {
    if (!await _isLegacyItemPending(key)) {
      return null;
    }
    try {
      final legacyPreferences = await SharedPreferences.getInstance();
      final value = legacyPreferences.getString(key);
      if (value == null) {
        _legacyChecked.add(key);
        return null;
      }
      // The new store is written first, so that an interruption before the
      // legacy entry is gone leaves the value in one store or the other rather
      // than in neither.
      await _preferences.setString(key, value);
      await _preferences.setBool(_migratedKey(key), true);
      _legacyChecked.add(key);
      await _removeLegacyItem(legacyPreferences, key);
      return value;
    } catch (error, stackTrace) {
      flutterLogger.warning(
        'Could not read the legacy store',
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// Makes sure a legacy value for [key] is not moved over after the value
  /// was removed, which would bring back a session the user signed out of.
  ///
  /// The marker is only written when the legacy store holds the key, so the
  /// keys of pkce flows that never existed in v2 leave no trace behind. When
  /// the legacy store cannot be read it is written regardless: not knowing
  /// whether a stale session is in there must not let one come back later.
  Future<void> _retireLegacyItem(String key) async {
    if (!await _isLegacyItemPending(key)) {
      return;
    }
    final SharedPreferences legacyPreferences;
    try {
      legacyPreferences = await SharedPreferences.getInstance();
    } catch (error, stackTrace) {
      flutterLogger.warning(
        'Could not read the legacy store',
        error,
        stackTrace,
      );
      await _preferences.setBool(_migratedKey(key), true);
      _legacyChecked.add(key);
      return;
    }
    _legacyChecked.add(key);
    if (!legacyPreferences.containsKey(key)) {
      return;
    }
    await _preferences.setBool(_migratedKey(key), true);
    await _removeLegacyItem(legacyPreferences, key);
  }

  /// Deletes the legacy entry so a stale token is not left lying around.
  ///
  /// Picks up what was written through the other API first. Without it the
  /// legacy cache is a pre-migration snapshot, and on the platforms where the
  /// two share a file the next legacy write by the app would rewrite the file
  /// from that snapshot, taking the migrated value with it.
  ///
  /// A failure to delete only costs a leftover entry, since the value has
  /// been written to the new store and marked as moved by then.
  Future<void> _removeLegacyItem(
    SharedPreferences legacyPreferences,
    String key,
  ) async {
    try {
      await legacyPreferences.reload();
      await legacyPreferences.remove(key);
    } catch (error, stackTrace) {
      flutterLogger.warning(
        'Could not delete the legacy entry',
        error,
        stackTrace,
      );
    }
  }
}
