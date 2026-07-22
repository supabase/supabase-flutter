import 'dart:convert';

import 'package:http/http.dart';

/// A mock HTTP client that simulates the `POST /token?grant_type=web3`
/// endpoint used for Web3 wallet authentication.
class Web3MockClient extends BaseClient {
  final String userId;
  final String accessToken;
  final String refreshToken;

  Uri? lastUri;
  Map<String, dynamic>? lastRequestBody;
  Map<String, String>? lastHeaders;

  Web3MockClient({
    this.userId = 'mock-user-id-web3',
    this.accessToken = 'mock-access-token',
    this.refreshToken = 'mock-refresh-token',
  });

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastUri = request.url;
    lastHeaders = request.headers;

    if (request is Request) {
      try {
        lastRequestBody = json.decode(request.body) as Map<String, dynamic>;
      } catch (_) {
        // Ignore non-JSON bodies.
      }
    }

    final now = DateTime.now().toIso8601String();

    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'access_token': accessToken,
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': refreshToken,
            'user': {
              'id': userId,
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': null,
              'phone': null,
              'confirmed_at': now,
              'last_sign_in_at': now,
              'created_at': now,
              'updated_at': now,
              'app_metadata': {
                'provider': 'web3',
                'providers': ['web3'],
              },
              'user_metadata': {
                'custom_claims': {
                  'address': lastRequestBody?['message'],
                },
              },
              'identities': [
                {
                  'id': userId,
                  'user_id': userId,
                  'identity_data': {'sub': userId},
                  'provider': 'web3',
                  'last_sign_in_at': now,
                  'created_at': now,
                  'updated_at': now,
                },
              ],
            },
          }),
        ),
      ),
      200,
      request: request,
    );
  }
}

/// A mock client that always fails the Web3 token exchange with the given
/// [statusCode] and [errorResponse], simulating an expired nonce or a bad
/// signature.
class Web3ErrorMockClient extends BaseClient {
  final int statusCode;
  final Map<String, dynamic> errorResponse;

  Web3ErrorMockClient({
    this.statusCode = 403,
    this.errorResponse = const {
      'code': 'bad_json',
      'message': 'Signature verification failed',
    },
  });

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(errorResponse))),
      statusCode,
      request: request,
    );
  }
}

/// A mock client that fails every request with a transport error, simulating a
/// dropped connection.
class Web3NetworkErrorMockClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    throw ClientException('Connection failed', request.url);
  }
}
