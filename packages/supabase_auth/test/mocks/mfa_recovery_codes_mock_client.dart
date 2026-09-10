import 'dart:convert';

import 'package:http/http.dart';
import 'package:supabase_test/supabase_test.dart';

/// A mock HTTP client that simulates the MFA recovery codes API of the
/// Supabase Auth server.
class MfaRecoveryCodesMockClient extends BaseClient {
  static const userId = 'b13898bb-3b85-4d83-a447-841dc3232ea1';
  static const factorId = '99999999-8888-7777-6666-555555555555';
  static const totpFactorId = '744c1f56-7e2f-46a2-b1cf-1c8e77e4b23d';
  static const codes = [
    'k4m6x7qp2ab5ht3z',
    'wze6r5npd4cmq7vt',
    'nq5v7xk2m6tp4wzs',
    'h3kqw2m7xt4rpn6b',
    'p7tz4mq2k6xn5wrb',
    'b3d6fh2jkm4npq5r',
    'r5t7vwx2z3a4b6cd',
    'c6d7efg2h3j4k5mn',
    'm6n7pq2r3s4t5vwx',
    'w6x7yz2a3b4c5def',
  ];

  String? lastMethod;
  Uri? lastUrl;
  String? lastBody;
  Map<String, String>? lastHeaders;

  /// When set, every request is answered with this error instead of the
  /// regular mock response.
  ({int statusCode, String code})? errorResponse;

  /// Builds a signed access token carrying [aal] and the given [amr] methods.
  static String accessToken({
    String aal = 'aal1',
    List<String> amr = const ['password'],
  }) {
    final issuedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return signedTestJwt({
      'aud': 'authenticated',
      'role': 'authenticated',
      'aal': aal,
      'amr': [
        for (final method in amr) {'method': method, 'timestamp': issuedAt},
      ],
      'exp': issuedAt + 3600,
      'sub': userId,
    }, secret: 'test-secret');
  }

  static Map<String, dynamic> sessionJson({
    String? accessToken,
    bool withFactors = false,
  }) {
    final now = '2026-01-01T00:00:00.000Z';
    return {
      'access_token': accessToken ?? MfaRecoveryCodesMockClient.accessToken(),
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'mock-refresh-token',
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'recovery-codes-user@example.com',
        'created_at': now,
        'updated_at': now,
        'app_metadata': {
          'provider': 'email',
          'providers': ['email'],
        },
        'user_metadata': <String, dynamic>{},
        'identities': [],
        if (withFactors)
          'factors': [
            {
              'id': totpFactorId,
              'friendly_name': 'Authenticator app',
              'factor_type': 'totp',
              'status': 'verified',
              'created_at': now,
              'updated_at': now,
            },
            {
              'id': factorId,
              'friendly_name': 'Recovery codes',
              'factor_type': 'recovery_code',
              'status': 'verified',
              'created_at': now,
              'updated_at': now,
            },
            {
              'id': 'cf5ea60c-d52b-46a6-a306-3a0c4b68dd0f',
              'friendly_name': 'Future factor',
              'factor_type': 'future_factor_type',
              'status': 'verified',
              'created_at': now,
              'updated_at': now,
            },
          ],
      },
    };
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastMethod = request.method;
    lastUrl = request.url;
    lastHeaders = request.headers;
    lastBody = request is Request ? request.body : null;

    final errorResponse = this.errorResponse;
    if (errorResponse != null) {
      return _jsonResponse(
        {'code': errorResponse.code, 'msg': 'mock error'},
        statusCode: errorResponse.statusCode,
      );
    }

    final path = request.url.path;
    final method = request.method;

    if (path.endsWith('/factors/recovery-codes') && method == 'GET') {
      return _jsonResponse({
        'id': factorId,
        'type': 'recovery_code',
        'total': 10,
        'remaining': 7,
      });
    }

    if (path.endsWith('/factors/recovery-codes') && method == 'POST') {
      final body = lastBody == null || lastBody!.isEmpty
          ? const <String, dynamic>{}
          : json.decode(lastBody!) as Map<String, dynamic>;
      return _jsonResponse({
        'id': factorId,
        'type': 'recovery_code',
        'friendly_name': body['friendly_name'] ?? 'Recovery codes',
        'total': 10,
        'codes': codes,
      });
    }

    if (path.endsWith('/factors/recovery-codes/regenerate') &&
        method == 'POST') {
      return _jsonResponse({
        'id': factorId,
        'type': 'recovery_code',
        'friendly_name': 'Recovery codes',
        'total': 10,
        'codes': codes.reversed.toList(),
      });
    }

    if (path.endsWith('/factors/recovery-codes/verify') && method == 'POST') {
      return _jsonResponse(
        sessionJson(
          accessToken: accessToken(
            aal: 'aal2',
            amr: ['password', 'mfa/recovery_code'],
          ),
          withFactors: true,
        ),
      );
    }

    if (path.endsWith('/factors/recovery-codes') && method == 'DELETE') {
      return _jsonResponse({'id': factorId});
    }

    if (path.endsWith('/token') && method == 'POST') {
      return _jsonResponse(sessionJson(withFactors: true));
    }

    return _jsonResponse({'error': 'Unhandled mock request'}, statusCode: 501);
  }

  StreamedResponse _jsonResponse(Object body, {int statusCode = 200}) {
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      statusCode,
      headers: {
        'content-type': 'application/json',
        'x-supabase-api-version': '2024-01-01',
      },
      request: null,
    );
  }
}
