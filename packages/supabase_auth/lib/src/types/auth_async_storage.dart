/// Interface to provide async storage to store pkce tokens.
abstract class AuthAsyncStorage {
  /// Const constructor for subclasses.
  const AuthAsyncStorage();

  /// Retrieves an item asynchronously from the storage with the key.
  Future<String?> getItem({required String key});

  /// Stores the value asynchronously to the storage with the key.
  Future<void> setItem({
    required String key,
    required String value,
  });

  /// Removes an item asynchronously from the storage for the given key.
  Future<void> removeItem({required String key});
}

/// A [AuthAsyncStorage] that keeps the pkce code verifiers in memory only.
///
/// Everything it holds is lost when the process exits, so a pkce flow started
/// before a restart can no longer be completed. Use a persistent
/// implementation when the code exchange happens after the app was closed,
/// which is what `supabase_flutter` does with shared preferences.
class MemoryAuthAsyncStorage extends AuthAsyncStorage {
  final _items = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _items[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _items.remove(key);
  }
}
