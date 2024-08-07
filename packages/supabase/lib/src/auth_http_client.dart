import 'package:http/http.dart';

class AuthHttpClient extends BaseClient {
  final Client _inner;

  final String _supabaseKey;
  final Future<String?> Function() _getAccessToken;
  AuthHttpClient(this._supabaseKey, this._inner, this._getAccessToken);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final accessToken = await _getAccessToken();
    final authBearer = accessToken ?? _supabaseKey;

    request.headers.putIfAbsent("Authorization", () => 'Bearer $authBearer');
    request.headers.putIfAbsent("apikey", () => _supabaseKey);
    return _inner.send(request);
  }
}
