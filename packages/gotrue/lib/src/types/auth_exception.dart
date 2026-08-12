import 'package:gotrue/src/types/error_code.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_common/supabase_common.dart';

/// Thrown when an auth operation fails.
///
/// A plain [AuthException] is a failure the client raised on its own, such as a
/// missing session, and carries only a [message] and, when the client can name
/// the failure, an [errorCode]. A failure the auth service reported is an
/// [AuthApiException] and also carries the response's status code.
///
/// Find the full list of error codes in our documentation.
/// https://supabase.com/docs/guides/auth/debugging/error-codes
class AuthException extends SupabaseException {
  const AuthException(super.message, {super.errorCode});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuthException &&
        other.runtimeType == runtimeType &&
        other.message == message &&
        other.errorCode == errorCode;
  }

  @override
  int get hashCode => Object.hash(runtimeType, message, errorCode);
}

class AuthPKCEGrantCodeExchangeError extends AuthException {
  const AuthPKCEGrantCodeExchangeError(super.message);
}

class AuthSessionMissingException extends AuthException {
  AuthSessionMissingException([String? message])
    : super(
        message ?? 'Auth session missing!',
        errorCode: ErrorCode.sessionMissing.code,
      );
}

/// Thrown when a request to the auth service failed in a way that is worth
/// retrying, either because it never reached the service or because the service
/// answered with a 5xx status.
class AuthRetryableFetchException extends AuthException {
  /// HTTP status code of the response that caused the error.
  ///
  /// `null` when the request failed before a response was received, for
  /// example on a network failure.
  final int? statusCode;

  AuthRetryableFetchException({
    String message = 'AuthRetryableFetchException',
    this.statusCode,
  }) : super(message);

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode, '
      'errorCode: $errorCode)';

  @override
  bool operator ==(Object other) =>
      other is AuthRetryableFetchException &&
      super == other &&
      other.statusCode == statusCode;

  @override
  int get hashCode => Object.hash(super.hashCode, statusCode);
}

/// Thrown when the auth service answered with an error.
class AuthApiException extends AuthException with SupabaseApiException {
  @override
  final int statusCode;

  const AuthApiException(
    super.message, {
    required this.statusCode,
    super.errorCode,
  });

  @override
  bool operator ==(Object other) =>
      other is AuthApiException &&
      super == other &&
      other.statusCode == statusCode;

  @override
  int get hashCode => Object.hash(super.hashCode, statusCode);
}

class AuthUnknownException extends AuthException {
  /// May contain a non 2xx [http.Response] object or the original thrown error.
  final Object originalError;

  /// HTTP status code of the response that caused the error.
  ///
  /// `null` when [originalError] is not a response.
  final int? statusCode;

  AuthUnknownException({
    required String message,
    required this.originalError,
  }) : statusCode = originalError is http.Response
           ? originalError.statusCode
           : null,
       super(message);

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode, '
      'errorCode: $errorCode, originalError: $originalError)';

  @override
  bool operator ==(Object other) =>
      other is AuthUnknownException &&
      super == other &&
      other.statusCode == statusCode;

  @override
  int get hashCode => Object.hash(super.hashCode, statusCode);
}

class AuthWeakPasswordException extends AuthApiException {
  final List<String> reasons;

  AuthWeakPasswordException({
    required String message,
    required super.statusCode,
    required this.reasons,
  }) : super(message, errorCode: ErrorCode.weakPassword.code);

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode, '
      'errorCode: $errorCode, reasons: $reasons)';
}

class AuthInvalidJwtException extends AuthException {
  AuthInvalidJwtException(super.message) : super(errorCode: 'invalid_jwt');
}
