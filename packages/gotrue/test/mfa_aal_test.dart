import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:gotrue/gotrue.dart';
import 'package:test/test.dart';

/// Builds a signed JWT for [claims] so we can craft access tokens that are
/// missing optional claims like `amr`.
String _accessToken(Map<String, dynamic> claims) {
  return JWT(claims, subject: 'user-id').sign(SecretKey('test-secret'));
}

Map<String, dynamic> _session(String accessToken) => {
      'access_token': accessToken,
      'token_type': 'bearer',
      'refresh_token': 'refresh-token',
      'expires_in': 3600,
      'user': {
        'id': 'user-id',
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2023-04-01T09:38:59.784028Z',
      },
    };

void main() {
  test('getAuthenticatorAssuranceLevel does not throw when amr is absent',
      () async {
    final exp =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    // An access token that carries `aal` but no `amr` claim.
    final accessToken = _accessToken({'exp': exp, 'aal': 'aal1'});

    final client = GoTrueClient(
      url: 'http://localhost',
      autoRefreshToken: false,
      flowType: AuthFlowType.implicit,
    );
    addTearDown(client.dispose);

    await client.recoverSession(jsonEncode(_session(accessToken)));

    final res = client.mfa.getAuthenticatorAssuranceLevel();

    expect(res.currentLevel, AuthenticatorAssuranceLevels.aal1);
    expect(res.currentAuthenticationMethods, isEmpty);
  });
}
