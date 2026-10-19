import 'package:meta/meta.dart';
import 'package:supabase/supabase.dart';

/// Keeps the records of resumable uploads in the [AuthAsyncStorage] that
/// holds the session, so they survive a restart wherever the session does.
@internal
class AuthAsyncResumableUploadStorage extends ResumableUploadStorage {
  const AuthAsyncResumableUploadStorage(this._storage);

  final AuthAsyncStorage _storage;

  @override
  Future<String?> getItem(String key) => _storage.getItem(key);

  @override
  Future<void> setItem(String key, String value) =>
      _storage.setItem(key, value);

  @override
  Future<void> removeItem(String key) => _storage.removeItem(key);
}
