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
///
/// Since it covers both, it reports no status code. When the service did
/// answer, [message] carries what it said: its own error message, or the
/// response's reason phrase, or `HTTP <status>` when the response had neither.
class AuthRetryableFetchException extends AuthException {
  AuthRetryableFetchException({
    String message = 'AuthRetryableFetchException',
  }) : super(message);
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

/// Thrown when a response could not be interpreted as an auth error, either
/// because it carried no body or because the body was not JSON.
///
/// It reports no status code of its own; read it from [originalError] when that
/// is a response.
class AuthUnknownException extends AuthException {
  /// May contain a non 2xx [http.Response] object or the original thrown error.
  final Object originalError;

  AuthUnknownException({
    required String message,
    required this.originalError,
  }) : super(message);

  @override
  String toString() =>
      '$runtimeType(message: $message, errorCode: $errorCode, '
      'originalError: $originalError)';
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
