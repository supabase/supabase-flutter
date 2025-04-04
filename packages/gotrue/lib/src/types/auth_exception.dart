import 'package:gotrue/src/types/error_code.dart';

class AuthException implements Exception {
  /// Human readable error message associated with the error.
  final String message;

  /// HTTP status code that caused the error.
  final String? statusCode;

  /// Error code associated with the error. Most errors coming from
  /// HTTP responses will have a code, though some errors that occur
  /// before a response is received will not have one present.
  /// In that case [statusCode] will also be null.
  ///
  /// Find the full list of error codes in our documentation.
  /// https://supabase.com/docs/reference/dart/auth-error-codes
  final String? code;

  const AuthException(this.message, {this.statusCode, this.code});

  @override
  String toString() =>
      'AuthException(message: $message, statusCode: $statusCode, code: $code)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuthException &&
        other.message == message &&
        other.statusCode == statusCode &&
        other.code == code;
  }

  @override
  int get hashCode => message.hashCode ^ statusCode.hashCode ^ code.hashCode;
}

class AuthPKCEGrantCodeExchangeError extends AuthException {
  AuthPKCEGrantCodeExchangeError(super.message);
}

class AuthSessionMissingException extends AuthException {
  AuthSessionMissingException([String? message])
      : super(
          message ?? 'Auth session missing!',
          statusCode: '400',
        );
}

class AuthRetryableFetchException extends AuthException {
  AuthRetryableFetchException({
    String message = 'AuthRetryableFetchException',
    super.statusCode,
  }) : super(message);
}

class AuthApiException extends AuthException {
  AuthApiException(super.message, {super.statusCode, super.code});
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
    required super.statusCode,
    required this.reasons,
  }) : super(message, code: ErrorCode.weakPassword.code);
}
