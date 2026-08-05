import 'package:gotrue/src/types/error_code.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_common/supabase_common.dart';

/// Thrown when an auth operation fails.
///
/// Most errors coming from HTTP responses carry an `errorCode`, though some
/// errors that occur before a response is received will not have one present.
/// In that case `statusCode` will also be null.
///
/// Find the full list of error codes in our documentation.
/// https://supabase.com/docs/guides/auth/debugging/error-codes
class AuthException extends SupabaseException {
  const AuthException(super.message, {super.statusCode, super.errorCode});

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
  const AuthPKCEGrantCodeExchangeError(super.message);
}

class AuthSessionMissingException extends AuthException {
  AuthSessionMissingException([String? message])
    : super(
        message ?? 'Auth session missing!',
        statusCode: 400,
      );
}

class AuthRetryableFetchException extends AuthException {
  AuthRetryableFetchException({
    String message = 'AuthRetryableFetchException',
    super.statusCode,
  }) : super(message);
}

class AuthApiException extends AuthException {
  const AuthApiException(super.message, {super.statusCode, super.errorCode});
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
             ? originalError.statusCode
             : null,
       );

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode, '
      'errorCode: $errorCode, originalError: $originalError)';
}

class AuthWeakPasswordException extends AuthException {
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
  AuthInvalidJwtException(super.message)
    : super(
        statusCode: 400,
        errorCode: 'invalid_jwt',
      );
}
