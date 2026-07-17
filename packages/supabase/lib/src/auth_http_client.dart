import 'package:http/http.dart';
import 'package:supabase/src/api_key.dart';

class AuthHttpClient extends BaseClient {
  final Client _inner;

  final String _supabaseKey;
  final Future<String?> Function() _getAccessToken;

  /// When `true`, a new-format API key (`sb_publishable_...` / `sb_secret_...`)
  /// is never sent as an `Authorization: Bearer` token. A genuine session
  /// access token is still sent normally.
  final bool _omitNewApiKeyAsBearer;

  AuthHttpClient(
    this._supabaseKey,
    this._inner,
    this._getAccessToken, {
    bool omitNewApiKeyAsBearer = false,
  }) : _omitNewApiKeyAsBearer = omitNewApiKeyAsBearer;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final accessToken = await _getAccessToken();

    if (accessToken != null) {
      request.headers.putIfAbsent("Authorization", () => 'Bearer $accessToken');
    } else if (!(_omitNewApiKeyAsBearer && isNewApiKey(_supabaseKey))) {
      request.headers.putIfAbsent(
        "Authorization",
        () => 'Bearer $_supabaseKey',
      );
    }
    request.headers.putIfAbsent("apikey", () => _supabaseKey);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
