import 'package:hive_flutter/hive_flutter.dart';

const _hiveBoxName = 'supabase_authentication';
const supabasePersistSessionKey = 'SUPABASE_PERSIST_SESSION_KEY';

Future<void> _defInitialize() async {
  await Hive.initFlutter('auth');
  await Hive.openBox(_hiveBoxName);
}

Future<bool> _defHasAccessToken() {
  return Future.value(
      Hive.box(_hiveBoxName).containsKey(supabasePersistSessionKey));
}

Future<String?> _defAccessToken() {
  return Future.value(
      Hive.box(_hiveBoxName).get(supabasePersistSessionKey) as String?);
}

Future<void> _defRemovePersistedSession() {
  return Hive.box(_hiveBoxName).delete(supabasePersistSessionKey);
}

Future<void> _defPersistSession(String persistSessionString) {
  return Hive.box(_hiveBoxName)
      .put(supabasePersistSessionKey, persistSessionString);
}

/// LocalStorage is used to persist the user session in the device.
///
/// By default, the package `hive` is used to save the user info on
/// the device. However, you can use any other plugin to do so.
///
/// For example, we can use `flutter_secure_storage` plugin to store
/// user session in a secure storage.
///
/// ```dart
/// final localStorage = LocalStorage(
///   hasAccessToken: () {
///     const storage = FlutterSecureStorage();
///     return storage.containsKey(key: supabasePersistSessionKey);
///   }, accessToken: () {
///     const storage = FlutterSecureStorage();
///     return storage.read(key: supabasePersistSessionKey);
///   }, removePersistedSession: () {
///     const storage = FlutterSecureStorage();
///     return storage.delete(key: supabasePersistSessionKey);
///   }, persistSession: (String value) {
///     const storage = FlutterSecureStorage();
///     return storage.write(key: supabasePersistSessionKey, value: value);
///   });
/// ```
///
/// To use the `LocalStorage` instance, pass it to `localStorage` when initializing
/// the [Supabase] instance:
///
/// ```dart
/// Supabase.initialize(
///  ...
///  localStorage: localStorage,
/// );
/// ```
///
/// See also:
///
///   * [SupabaseAuth], the instance used to manage authentication
abstract class LocalStorage {
  const LocalStorage({
    required this.initialize,
    required this.hasAccessToken,
    required this.accessToken,
    required this.persistSession,
    required this.removePersistedSession,
  });

  /// Initialize the storage to persist session.
  final Future<void> Function() initialize;

  /// Check if there is a persisted session.
  final Future<bool> Function() hasAccessToken;

  /// Get the access token from the current persisted session.
  final Future<String?> Function() accessToken;

  /// Remove the current persisted session.
  final Future<void> Function() removePersistedSession;

  /// Persist a session in the device.
  final Future<void> Function(String) persistSession;
}

class HiveLocalStorage extends LocalStorage {
  /// Creates a LocalStorage instance that implements the Hive Database
  const HiveLocalStorage()
      : super(
          initialize: _defInitialize,
          hasAccessToken: _defHasAccessToken,
          accessToken: _defAccessToken,
          removePersistedSession: _defRemovePersistedSession,
          persistSession: _defPersistSession,
        );
}
