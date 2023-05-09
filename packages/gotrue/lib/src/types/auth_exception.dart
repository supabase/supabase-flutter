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
