import 'package:gotrue/src/types/error_code.dart';

class AuthException implements Exception {
  /// Human readable error message associated with the error.
  final String message;

  /// HTTP status code that caused the error.
  final String? statusCode;

  /// Error code associated with the error. Most errors coming from
  /// HTTP responses will have a code, though some errors that occur
  /// before a response is received will not have one present.
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
  AuthPKCEGrantCodeExchangeError(super.message);
}

class AuthSessionMissingException extends AuthException {
  AuthSessionMissingException([String? message])
      : super(
          message ?? 'Auth session missing!',
          statusCode: '400',
          errorCode: ErrorCode.sessionNotFound.code,
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
  AuthApiException(super.message, {super.statusCode, super.errorCode});
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
    required this.reasons,
    String? errorCode,
  }) : super(message, statusCode: statusCode, errorCode: errorCode);
}
