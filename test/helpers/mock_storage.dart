import 'package:supabase_flutter/supabase_flutter.dart';

class MockAsyncStorage extends GotrueAsyncStorage {
  static const pkceHiveBoxName = 'supabase.pkce';

  final Map<String, String> _map = {};

  @override
  Future<String?> getItem({required String key}) async {
    return _map[key];
  }

  @override
  Future<void> removeItem({required String key}) async {
    _map.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _map[key] = value;
  }
}
