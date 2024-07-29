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
  AuthPKCEGrantCodeExchangeError(super.message);
}

class AuthSessionMissingException extends AuthException {
  AuthSessionMissingException()
      : super('Auth session missing!', statusCode: '400');
}

class AuthRetryableFetchException extends AuthException {
  AuthRetryableFetchException({
    String message = 'AuthRetryableFetchException',
    super.statusCode,
  }) : super(message);
}

class AuthApiException extends AuthException {
  AuthApiException(super.message, {super.statusCode});
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
  }) : super(message, statusCode: statusCode);
}
