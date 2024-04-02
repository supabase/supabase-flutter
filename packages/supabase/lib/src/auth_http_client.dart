import 'package:http/http.dart';
import 'package:supabase/supabase.dart';

class AuthHttpClient extends BaseClient {
  final Client _inner;
  final GoTrueClient _auth;
  final String _supabaseKey;

  AuthHttpClient(this._supabaseKey, this._inner, this._auth);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    String? accessToken = _auth.currentSession?.accessToken;
    if (_auth.currentSession?.isExpired ?? false) {
      try {
        final res = await _auth.refreshSession();
        accessToken = res.session?.accessToken;
      } catch (error) {
        // Make a request with the Supabase key instead of an expired JWT to
        // align the behavior with the JS client.
        accessToken = _supabaseKey;
      }
    }
    final authBearer = accessToken ?? _supabaseKey;

    request.headers.putIfAbsent("Authorization", () => 'Bearer $authBearer');
    request.headers.putIfAbsent("apikey", () => _supabaseKey);
    return _inner.send(request);
  }
}
