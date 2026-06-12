import 'dart:convert';

import 'package:http/http.dart';

/// A mock HTTP client that simulates the passkey API of the GoTrue server.
class PasskeyMockClient extends BaseClient {
  static const userId = 'b13898bb-3b85-4d83-a447-841dc3232ea1';
  static const passkeyId = '4b52e9e2-7c1b-44e5-8b5b-d4769ce06f58';
  static const challengeId = 'f9e16464-9ce8-4eb4-b3b3-456a8e95dfa9';

  String? lastMethod;
  Uri? lastUrl;
  Map<String, dynamic>? lastRequestBody;
  Map<String, String>? lastHeaders;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastMethod = request.method;
    lastUrl = request.url;
    lastHeaders = request.headers;
    lastRequestBody = null;
    if (request is Request && request.body.isNotEmpty) {
      try {
        lastRequestBody = json.decode(request.body) as Map<String, dynamic>;
      } catch (_) {}
    }

    final path = request.url.path;
    final method = request.method;

    if (path.endsWith('/passkeys/registration/options') && method == 'POST') {
      return _jsonResponse({
        'challenge_id': challengeId,
        'options': _creationOptions(),
        'expires_at': 1735689900,
      });
    }

    if (path.endsWith('/passkeys/registration/verify') && method == 'POST') {
      return _jsonResponse(_passkeyJson(friendlyName: 'iCloud Keychain'));
    }

    if (path.endsWith('/passkeys/authentication/options') && method == 'POST') {
      return _jsonResponse({
        'challenge_id': challengeId,
        'options': _requestOptions(),
        'expires_at': 1735689900,
      });
    }

    if (path.endsWith('/passkeys/authentication/verify') && method == 'POST') {
      return _jsonResponse(_accessTokenResponse());
    }

    if (path.endsWith('/admin/users/$userId/passkeys') && method == 'GET') {
      return _jsonResponse([
        _passkeyJson(friendlyName: 'iCloud Keychain'),
        _passkeyJson(
          id: '600d2eb1-799d-44e6-a4a0-9e71a607fc9a',
          friendlyName: 'YubiKey',
        ),
      ]);
    }

    if (path.endsWith('/admin/users/$userId/passkeys/$passkeyId') &&
        method == 'DELETE') {
      return _emptyResponse(204);
    }

    if (path.endsWith('/passkeys') && method == 'GET') {
      return _jsonResponse([
        _passkeyJson(
          friendlyName: 'iCloud Keychain',
          lastUsedAt: '2025-01-02T03:04:05Z',
        ),
      ]);
    }

    if (path.endsWith('/passkeys/$passkeyId') && method == 'PATCH') {
      return _jsonResponse(
        _passkeyJson(friendlyName: lastRequestBody?['friendly_name']),
      );
    }

    if (path.endsWith('/passkeys/$passkeyId') && method == 'DELETE') {
      return _emptyResponse(204);
    }

    if (path.endsWith('/token') && method == 'POST') {
      return _jsonResponse(_accessTokenResponse(withFactors: true));
    }

    return StreamedResponse(
      Stream.value(
          utf8.encode(jsonEncode({'error': 'Unhandled mock request'}))),
      501,
      request: request,
    );
  }

  Map<String, dynamic> _passkeyJson({
    String id = passkeyId,
    String? friendlyName,
    String? lastUsedAt,
  }) {
    return {
      'id': id,
      if (friendlyName != null) 'friendly_name': friendlyName,
      'created_at': '2025-01-01T00:00:00Z',
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
    };
  }

  Map<String, dynamic> _creationOptions() {
    return {
      'rp': {'id': 'example.com', 'name': 'Example'},
      'user': {
        'id': 'YjEzODk4YmItM2I4NS00ZDgzLWE0NDctODQxZGMzMjMyZWEx',
        'name': 'user@example.com',
        'displayName': 'user@example.com',
      },
      'challenge': 'cmFuZG9tLWNoYWxsZW5nZQ',
      'pubKeyCredParams': [
        {'type': 'public-key', 'alg': -7},
      ],
      'timeout': 300000,
      'authenticatorSelection': {
        'residentKey': 'required',
        'userVerification': 'preferred',
      },
      'attestation': 'none',
    };
  }

  Map<String, dynamic> _requestOptions() {
    return {
      'challenge': 'cmFuZG9tLWNoYWxsZW5nZQ',
      'timeout': 300000,
      'rpId': 'example.com',
      'allowCredentials': [],
      'userVerification': 'preferred',
    };
  }

  Map<String, dynamic> _accessTokenResponse({bool withFactors = false}) {
    final now = DateTime.now().toIso8601String();
    return {
      'access_token': 'mock-access-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'mock-refresh-token',
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'user@example.com',
        'confirmed_at': now,
        'last_sign_in_at': now,
        'created_at': now,
        'updated_at': now,
        'app_metadata': {
          'provider': 'email',
          'providers': ['email'],
        },
        'user_metadata': {},
        'identities': [],
        if (withFactors)
          'factors': [
            {
              'id': '93c0d839-680e-4d2c-9c25-f0c00f105b8a',
              'friendly_name': 'iCloud Keychain',
              'factor_type': 'webauthn',
              'status': 'verified',
              'created_at': now,
              'updated_at': now,
            },
            {
              'id': 'cf5ea60c-d52b-46a6-a306-3a0c4b68dd0f',
              'friendly_name': 'Unverified key',
              'factor_type': 'webauthn',
              'status': 'unverified',
              'created_at': now,
              'updated_at': now,
            },
            {
              'id': '744c1f56-7e2f-46a2-b1cf-1c8e77e4b23d',
              'friendly_name': 'Authenticator app',
              'factor_type': 'totp',
              'status': 'verified',
              'created_at': now,
              'updated_at': now,
            },
          ],
      },
    };
  }

  StreamedResponse _jsonResponse(Object body) {
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
      headers: {'content-type': 'application/json'},
      request: null,
    );
  }

  StreamedResponse _emptyResponse(int statusCode) {
    return StreamedResponse(
      Stream.value(utf8.encode('')),
      statusCode,
      request: null,
    );
  }
}

/// A mock HTTP client that simulates the passkey feature being disabled on
/// the server.
class PasskeyDisabledMockClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'code': 'passkey_disabled',
        'msg': 'Passkey authentication is disabled',
      }))),
      404,
      headers: {'x-supabase-api-version': '2024-01-01'},
      request: request,
    );
  }
}
