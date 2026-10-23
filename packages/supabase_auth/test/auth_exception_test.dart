import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

void main() {
  test('every auth exception names itself in toString', () {
    final exceptions = {
      'AuthException': const AuthException('boom'),
      'AuthPKCEGrantCodeExchangeError': const AuthPKCEGrantCodeExchangeError(
        'boom',
      ),
      'AuthSessionMissingException': AuthSessionMissingException(),
      'AuthRetryableFetchException': AuthRetryableFetchException(),
      'AuthRetryableApiException': AuthRetryableApiException(
        message: 'boom',
        statusCode: 503,
      ),
      'AuthApiException': const AuthApiException('boom', statusCode: 400),
      'AuthUnknownException': AuthUnknownException(
        message: 'boom',
        originalError: 'cause',
      ),
      'AuthWeakPasswordException': AuthWeakPasswordException(
        message: 'boom',
        statusCode: 422,
        reasons: const ['length'],
      ),
      'AuthInvalidJwtException': const AuthInvalidJwtException('boom'),
    };

    for (final MapEntry(key: name, value: exception) in exceptions.entries) {
      expect(exception.toString(), startsWith('$name('));
    }
  });
}
