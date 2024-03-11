class AuthException implements Exception {
  final String message;
  final String? statusCode;

  const AuthException(this.message, {this.statusCode});

  @override
  String toString() =>
      'AuthException(message: $message, statusCode: $statusCode)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuthException &&
        other.message == message &&
        other.statusCode == statusCode;
  }

  @override
  int get hashCode => message.hashCode ^ statusCode.hashCode;
}

class AuthPKCEGrantCodeExchangeError extends AuthException {
  AuthPKCEGrantCodeExchangeError(String message) : super(message);
}

class AuthSessionMissingError extends AuthException {
  AuthSessionMissingError() : super('Auth session missing!', statusCode: '400');
}

class AuthRetryableFetchError extends AuthException {
  AuthRetryableFetchError() : super('AuthRetryableFetchError');
}

class AuthApiError extends AuthException {
  AuthApiError(String message, {String? statusCode})
      : super(message, statusCode: statusCode);
}

class AuthUnknownError extends AuthException {
  final Object originalError;

  AuthUnknownError({required String message, required this.originalError})
      : super(message);
}

class AuthWeakPasswordError extends AuthException {
  final List<String> reasons;

  AuthWeakPasswordError({
    required String message,
    required String statusCode,
    required this.reasons,
  }) : super(message, statusCode: statusCode);
}
