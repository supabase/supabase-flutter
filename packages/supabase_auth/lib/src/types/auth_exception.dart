import 'package:supabase_auth/src/types/error_code.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_common/supabase_common.dart';

/// Thrown when an auth operation fails.
///
/// A plain [AuthException] is a failure the client raised on its own, such as a
/// missing session. A failure the auth service reported is an
/// [AuthApiException].
///
/// Find the full list of error codes in our documentation.
/// https://supabase.com/docs/guides/auth/debugging/error-codes
class AuthException extends SupabaseException {
  const AuthException(super.message, {super.errorCode, super.requestId});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuthException &&
        other.runtimeType == runtimeType &&
        other.message == message &&
        other.errorCode == errorCode &&
        other.requestId == requestId;
  }

  @override
  int get hashCode => Object.hash(runtimeType, message, errorCode, requestId);
}

/// Thrown when a PKCE flow deep link is missing the `code` query parameter
/// needed to exchange it for a session.
class AuthPKCEGrantCodeExchangeError extends AuthException {
  const AuthPKCEGrantCodeExchangeError(super.message);
}

/// Thrown when required session data is unavailable, such as when no session
/// is active or a required access or refresh token is empty.
class AuthSessionMissingException extends AuthException {
  AuthSessionMissingException([String? message])
    : super(
        message ?? 'Auth session missing!',
        errorCode: ErrorCode.sessionMissing.code,
      );
}

/// Thrown when a request never reached the auth service, for example on a
/// network failure, and is worth retrying.
///
/// A retryable 5xx is an [AuthRetryableApiException]. Catch this type to cover
/// both.
class AuthRetryableFetchException extends AuthException {
  AuthRetryableFetchException({
    String message = 'AuthRetryableFetchException',
    super.requestId,
  }) : super(message);
}

/// Thrown when the auth service answered with a 5xx status, which is worth
/// retrying.
class AuthRetryableApiException extends AuthRetryableFetchException
    with SupabaseApiException {
  AuthRetryableApiException({
    required super.message,
    required this.statusCode,
    super.requestId,
  });
  @override
  final int statusCode;

  @override
  bool operator ==(Object other) =>
      other is AuthRetryableApiException &&
      super == other &&
      other.statusCode == statusCode;

  @override
  int get hashCode => Object.hash(super.hashCode, statusCode);
}

/// Thrown when the auth service answered with an error.
class AuthApiException extends AuthException with SupabaseApiException {
  const AuthApiException(
    super.message, {
    required this.statusCode,
    super.errorCode,
    super.requestId,
  });
  @override
  final int statusCode;

  @override
  bool operator ==(Object other) =>
      other is AuthApiException &&
      super == other &&
      other.statusCode == statusCode;

  @override
  int get hashCode => Object.hash(super.hashCode, statusCode);
}

/// Thrown when a response could not be interpreted as an auth error, either
/// because it carried no body or because the body was not JSON.
///
/// It reports no status code of its own; read it from [originalError] when that
/// is a response.
class AuthUnknownException extends AuthException {
  AuthUnknownException({
    required String message,
    required this.originalError,
    super.requestId,
  }) : super(message);

  /// May contain a non 2xx [http.Response] object or the original thrown error.
  final Object originalError;

  @override
  String toString() =>
      '$runtimeType(message: $message, errorCode: $errorCode, '
      'requestId: $requestId, originalError: $originalError)';
}

/// Thrown when a password fails the project's strength requirements.
class AuthWeakPasswordException extends AuthApiException {
  AuthWeakPasswordException({
    required String message,
    required super.statusCode,
    required this.reasons,
    super.requestId,
  }) : super(message, errorCode: ErrorCode.weakPassword.code);

  /// Why the password was rejected, for example `'characters'`.
  final List<String> reasons;

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode, '
      'errorCode: $errorCode, requestId: $requestId, reasons: $reasons)';
}

/// Thrown when a JWT could not be parsed or verified, for example by
/// `AuthClient.getClaims`.
class AuthInvalidJwtException extends AuthException {
  const AuthInvalidJwtException(super.message)
    : super(errorCode: 'invalid_jwt');
}
