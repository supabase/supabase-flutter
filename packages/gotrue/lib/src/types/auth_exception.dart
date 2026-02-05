import 'package:gotrue/src/types/error_code.dart';
import 'package:http/http.dart' as http;

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
  /// https://supabase.com/docs/guides/auth/debugging/error-codes
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
  @override
  String toString() =>
      'AuthSessionMissingException(message: $message, statusCode: $statusCode)';
}

class AuthRetryableFetchException extends AuthException {
  AuthRetryableFetchException({
    String message = 'AuthRetryableFetchException',
    super.statusCode,
  }) : super(message);

  @override
  String toString() =>
      'AuthRetryableFetchException(message: $message, statusCode: $statusCode)';
}

class AuthApiException extends AuthException {
  AuthApiException(super.message, {super.statusCode, super.code});

  @override
  String toString() =>
      'AuthApiException(message: $message, statusCode: $statusCode, code: $code)';
}

class AuthUnknownException extends AuthException {
  /// May contain a non 2xx [http.Response] object or the original thrown error.
  final Object originalError;

  AuthUnknownException({
    required String message,
    required this.originalError,
  }) : super(
          message,
          statusCode: originalError is http.Response
              ? originalError.statusCode.toString()
              : null,
        );

  @override
  String toString() =>
      'AuthUnknownException(message: $message, originalError: $originalError, statusCode: $statusCode)';
}

class AuthWeakPasswordException extends AuthException {
  final List<String> reasons;

  AuthWeakPasswordException({
    required String message,
    required super.statusCode,
    required this.reasons,
  }) : super(message, code: ErrorCode.weakPassword.code);

  @override
  String toString() =>
      'AuthWeakPasswordException(message: $message, statusCode: $statusCode, reasons: $reasons)';
}

class AuthInvalidJwtException extends AuthException {
  AuthInvalidJwtException(super.message)
      : super(
          statusCode: '400',
          code: 'invalid_jwt',
        );

  @override
  String toString() =>
      'AuthInvalidJwtException(message: $message, statusCode: $statusCode, code: $code)';
}

/// Exception thrown when an auth operation is attempted on a disposed client.
class AuthClientDisposedException extends AuthException {
  /// The operation that was in progress when the client was disposed.
  final String? operation;

  AuthClientDisposedException({
    String message = 'Auth client has been disposed',
    this.operation,
  }) : super(
          operation != null ? '$message during $operation' : message,
          code: 'client_disposed',
        );

  @override
  String toString() =>
      'AuthClientDisposedException(message: $message, operation: $operation)';
}
