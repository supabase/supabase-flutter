import 'package:http/http.dart';
import 'package:supabase/supabase.dart';

class AuthHttpClient extends BaseClient {
  final Client _inner;
  final GoTrueClient _auth;
  final String _supabaseKey;

  AuthHttpClient(this._supabaseKey, this._inner, this._auth);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (_auth.currentSession?.isExpired ?? false) {
      try {
        await _auth.refreshSession();
      } catch (_) {}
    }
    final authBearer = _auth.currentSession?.accessToken ?? _supabaseKey;

    request.headers.putIfAbsent("Authorization", () => 'Bearer $authBearer');
    request.headers.putIfAbsent("apikey", () => _supabaseKey);
    return _inner.send(request);
  }
}
