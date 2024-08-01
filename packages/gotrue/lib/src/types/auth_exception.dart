import 'package:gotrue/src/types/auth_error_codes.dart';

class AuthException implements Exception {
  final String message;
  final String? statusCode;
  final String? errorCode;

  const AuthException(this.message, {this.statusCode, this.errorCode});

  @override
  String toString() =>
      'AuthException(message: $message, statusCode: $statusCode, errorCode: $errorCode)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuthException &&
        other.message == message &&
        other.statusCode == statusCode &&
        other.errorCode == errorCode;
  }

  @override
  int get hashCode =>
      message.hashCode ^ statusCode.hashCode ^ errorCode.hashCode;
}

class AuthPKCEGrantCodeExchangeError extends AuthException {
  AuthPKCEGrantCodeExchangeError(String message) : super(message);
}

class AuthSessionMissingException extends AuthException {
  AuthSessionMissingException()
      : super(
          'Auth session missing!',
          statusCode: '400',
          errorCode: AuthErrorCode.sessionNotFound.code,
        );
}

class AuthRetryableFetchException extends AuthException {
  AuthRetryableFetchException({
    String message = 'AuthRetryableFetchException',
    super.statusCode,
    super.errorCode,
  }) : super(message);
}

class AuthApiException extends AuthException {
  AuthApiException(String message, {String? statusCode, String? errorCode})
      : super(message, statusCode: statusCode, errorCode: errorCode);
}

class AuthUnknownException extends AuthException {
  final Object originalError;

  AuthUnknownException({required String message, required this.originalError})
      : super(message);
}

class AuthWeakPasswordException extends AuthException {
  final List<String> reasons;

  AuthWeakPasswordException({
    required String message,
    required String statusCode,
    required String? errorCode,
    required this.reasons,
  }) : super(message, statusCode: statusCode, errorCode: errorCode);
}
