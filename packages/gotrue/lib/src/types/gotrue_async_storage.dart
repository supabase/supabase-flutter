/// Interface to provide async storage to store pkce tokens.
abstract class GotrueAsyncStorage {
  const GotrueAsyncStorage();

  /// May be implemented to allow for initialization of the storage before use.
  Future<void> initialize() async {}

  /// Retrieves an item asynchronously from the storage with the key.
  Future<String?> getItem(String key);

  /// Stores the value asynchronously to the storage with the key.
  Future<void> setItem(String key, String value);

  /// Removes an item asynchronously from the storage for the given key.
  Future<void> removeItem(String key);
}
