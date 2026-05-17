import 'dart:convert';

import 'package:http/http.dart';

/// A mock HTTP client that simulates OTP-related API responses.
class OtpMockClient extends BaseClient {
  final String phoneNumber;
  final String email;
  final String userId;
  final String accessToken;
  final String refreshToken;

  OtpMockClient({
    this.phoneNumber = '+11234567890',
    this.email = 'test@example.com',
    this.userId = 'mock-user-id-123',
    this.accessToken = 'mock-access-token',
    this.refreshToken = 'mock-refresh-token',
  });

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final url = request.url.toString();
    final method = request.method;

    // Extract request body if it's a POST request
    Map<String, dynamic>? requestBody;
    if (request is Request) {
      try {
        requestBody = json.decode(request.body) as Map<String, dynamic>;
      } catch (_) {
        // If body is not valid JSON, ignore the error
      }
    }

    // Simulate OTP request (send OTP)
    if (url.contains('/otp') && method == 'POST') {
      return _handleOtpRequest(requestBody);
    }

    // Simulate OTP verification
    if (url.contains('/verify') && method == 'POST') {
      return _handleVerifyRequest(requestBody);
    }

    // Simulate phone number signup
    if (url.contains('/signup') &&
        method == 'POST' &&
        requestBody?['phone'] != null) {
      return _handlePhoneSignup(requestBody);
    }

    // Simulate token endpoint for password auth with phone
    if (url.contains('/token') &&
        method == 'POST' &&
        requestBody?['phone'] != null) {
      return _handlePhoneSignInWithPassword(requestBody);
    }

    // Simulate reauthentication
    if (url.contains('/reauthenticate') && method == 'GET') {
      return _handleReauthenticate();
    }

    // Simulate resend
    if (url.contains('/resend') && method == 'POST') {
      return _handleResend(requestBody);
    }

    // Default response for unhandled requests
    return StreamedResponse(
      Stream.value(
          utf8.encode(jsonEncode({'error': 'Unhandled mock request'}))),
      501,
      request: request,
    );
  }

  StreamedResponse _handleOtpRequest(Map<String, dynamic>? requestBody) {
    // Check if it's a phone OTP request
    if (requestBody?['phone'] != null) {
      return StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'message': 'OTP sent to phone',
          'message_id': 'mock-message-id-phone',
        }))),
        200,
        request: null,
      );
    }

    // Check if it's an email OTP request
    if (requestBody?['email'] != null) {
      return StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'message': 'OTP sent to email',
          'message_id': 'mock-message-id-email',
        }))),
        200,
        request: null,
      );
    }

    // Invalid OTP request
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'error': 'Invalid OTP request',
        'message': 'Email or phone number required',
      }))),
      400,
      request: null,
    );
  }

  StreamedResponse _handleVerifyRequest(Map<String, dynamic>? requestBody) {
    final now = DateTime.now().toIso8601String();

    // OTP token verification response
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'access_token': accessToken,
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': refreshToken,
        'user': {
          'id': userId,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': requestBody?['email'] ?? email,
          'phone': requestBody?['phone'] ?? phoneNumber,
          'phone_confirmed_at': now,
          'confirmed_at': now,
          'last_sign_in_at': now,
          'created_at': now,
          'updated_at': now,
          'app_metadata': {
            'provider': requestBody?['email'] != null ? 'email' : 'phone',
            'providers': [requestBody?['email'] != null ? 'email' : 'phone'],
          },
          'user_metadata': {},
          'identities': [
            {
              'id': userId,
              'user_id': userId,
              'identity_data': {
                'sub': userId,
                'email': requestBody?['email'] ?? email,
                'phone': requestBody?['phone'] ?? phoneNumber,
              },
              'provider': requestBody?['email'] != null ? 'email' : 'phone',
              'last_sign_in_at': now,
              'created_at': now,
              'updated_at': now,
            }
          ],
        }
      }))),
      200,
      request: null,
    );
  }

  StreamedResponse _handlePhoneSignup(Map<String, dynamic>? requestBody) {
    final now = DateTime.now().toIso8601String();

    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'access_token': accessToken,
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': refreshToken,
        'user': {
          'id': userId,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': null,
          'phone': requestBody?['phone'] ?? phoneNumber,
          'phone_confirmed_at': now,
          'confirmed_at': now,
          'last_sign_in_at': now,
          'created_at': now,
          'updated_at': now,
          'app_metadata': {
            'provider': 'phone',
            'providers': ['phone'],
          },
          'user_metadata': requestBody?['data'] ?? {},
          'identities': [
            {
              'id': userId,
              'user_id': userId,
              'identity_data': {
                'sub': userId,
                'phone': requestBody?['phone'] ?? phoneNumber,
              },
              'provider': 'phone',
              'last_sign_in_at': now,
              'created_at': now,
              'updated_at': now,
            }
          ],
        }
      }))),
      200,
      request: null,
    );
  }

  StreamedResponse _handlePhoneSignInWithPassword(
      Map<String, dynamic>? requestBody) {
    final now = DateTime.now().toIso8601String();

    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'access_token': accessToken,
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': refreshToken,
        'user': {
          'id': userId,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': null,
          'phone': requestBody?['phone'] ?? phoneNumber,
          'phone_confirmed_at': now,
          'confirmed_at': now,
          'last_sign_in_at': now,
          'created_at': now,
          'updated_at': now,
          'app_metadata': {
            'provider': 'phone',
            'providers': ['phone'],
          },
          'user_metadata': {},
          'identities': [
            {
              'id': userId,
              'user_id': userId,
              'identity_data': {
                'sub': userId,
                'phone': requestBody?['phone'] ?? phoneNumber,
              },
              'provider': 'phone',
              'last_sign_in_at': now,
              'created_at': now,
              'updated_at': now,
            }
          ],
        }
      }))),
      200,
      request: null,
    );
  }

  StreamedResponse _handleReauthenticate() {
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'message': 'Reauthentication succeeded',
      }))),
      200,
      request: null,
    );
  }

  StreamedResponse _handleResend(Map<String, dynamic>? requestBody) {
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'message': 'OTP resent',
        'message_id': 'mock-message-id-resend',
      }))),
      200,
      request: null,
    );
  }
}

/// A mock HTTP client that captures the channel parameter for testing
class ChannelMockClient extends BaseClient {
  String? lastChannelUsed;
  Map<String, dynamic>? lastRequestBody;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (request is Request) {
      try {
        lastRequestBody = json.decode(request.body) as Map<String, dynamic>;
        lastChannelUsed = lastRequestBody?['channel'];
      } catch (_) {
        // If body is not valid JSON, ignore the error
      }
    }

    final url = request.url.toString();
    final method = request.method;

    // Special handling for verify OTP endpoint
    if (url.contains('/verify') && method == 'POST') {
      final now = DateTime.now().toIso8601String();

      return StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'access_token': 'mock-access-token',
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'mock-refresh-token',
          'user': {
            'id': 'mock-user-id',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'test@example.com',
            'phone': '+11234567890',
            'phone_confirmed_at': now,
            'confirmed_at': now,
            'last_sign_in_at': now,
            'created_at': now,
            'updated_at': now,
            'app_metadata': {
              'provider': 'phone',
              'providers': ['phone'],
            },
            'user_metadata': {},
            'identities': [],
          }
        }))),
        200,
        request: request,
      );
    }

    // Default response for other requests
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'message': 'OTP sent',
        'message_id': 'mock-message-id',
      }))),
      200,
      request: request,
    );
  }
}

class ErrorMockClient extends BaseClient {
  final int statusCode;
  final Map<String, dynamic> errorResponse;

  ErrorMockClient({
    this.statusCode = 400,
    this.errorResponse = const {
      'error': 'Invalid OTP',
      'message': 'The OTP provided is invalid or has expired',
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

/// Client that returns empty arrays for certain keys to test null-safety
class EmptyResponseClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({}))),
      200,
      request: request,
    );
  }
}

/// Client that returns specific error codes based on the request
class ConditionalErrorClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final url = request.url.toString();
    final method = request.method;

    if (url.contains('/verify') && method == 'POST') {
      // Simulate expired OTP
      return StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'error': 'expired_token',
          'message': 'The OTP has expired',
        }))),
        401,
        request: request,
      );
    }

    if (url.contains('/token') && method == 'POST') {
      // Simulate wrong password
      return StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'error': 'invalid_grant',
          'message': 'Invalid login credentials',
        }))),
        401,
        request: request,
      );
    }

    if (url.contains('/signup') && method == 'POST') {
      Map<String, dynamic>? body;
      if (request is Request) {
        try {
          body = json.decode(request.body) as Map<String, dynamic>;
        } catch (_) {}
      }

      if (body?['phone'] != null) {
        // Simulate phone number already exists
        return StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'error': 'phone_taken',
            'message': 'Phone number is already registered',
          }))),
          400,
          request: request,
        );
      }
    }

    // Simulate unknown error for other requests
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'error': 'internal_error',
        'message': 'An unknown error occurred',
      }))),
      500,
      request: request,
    );
  }
}

/// Custom HTTP client for testing server errors
class CustomServerErrorClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    return StreamedResponse(
      Stream.value(utf8.encode('')),
      500,
      request: request,
    );
  }
}

/// Custom HTTP client for testing null session
class NullSessionClient extends BaseClient {
  final String email;

  NullSessionClient(this.email);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'user': {
          'id': 'user-id',
          'email': email,
        },
      }))),
      200,
      request: request,
    );
  }
}
