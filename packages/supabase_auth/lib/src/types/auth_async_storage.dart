/// Key-value storage the auth client keeps its session and pkce code
/// verifiers in.
///
/// The session is written under `AuthClient.storageKey` whenever it changes
/// and read back when a client is created, so that it outlives the process.
/// Code verifiers are stored under keys prefixed with the same key while
/// their pkce flow is pending.
abstract class AuthAsyncStorage {
  const AuthAsyncStorage();

  /// Returns the value stored under [key], or `null` when there is none.
  Future<String?> getItem(String key);

  /// Stores [value] under [key], replacing any earlier value.
  Future<void> setItem(String key, String value);

  /// Removes the value stored under [key], if any.
  Future<void> removeItem(String key);
}

/// An [AuthAsyncStorage] that keeps everything in memory only.
///
/// Everything it holds is lost when the process exits, so a session is not
/// restored after a restart and a pkce flow started before one can no longer
/// be completed. Use a persistent implementation when either needs to outlive
/// the process, which is what `supabase_flutter` does with shared preferences.
class MemoryAuthAsyncStorage extends AuthAsyncStorage {
  final _items = <String, String>{};

  @override
  Future<String?> getItem(String key) async => _items[key];

  @override
  Future<void> setItem(String key, String value) async {
    _items[key] = value;
  }

  @override
  Future<void> removeItem(String key) async {
    _items.remove(key);
  }
}
