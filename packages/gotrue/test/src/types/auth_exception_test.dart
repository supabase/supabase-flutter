import 'package:gotrue/src/types/auth_exception.dart';
import 'package:gotrue/src/types/error_code.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('AuthException', () {
    group('constructor', () {
      test('creates exception with message only', () {
        const exception = AuthException('Test error message');

        expect(exception.message, equals('Test error message'));
        expect(exception.statusCode, isNull);
        expect(exception.code, isNull);
      });

      test('creates exception with message and statusCode', () {
        const exception = AuthException(
          'Test error message',
          statusCode: '400',
        );

        expect(exception.message, equals('Test error message'));
        expect(exception.statusCode, equals('400'));
        expect(exception.code, isNull);
      });

      test('creates exception with all parameters', () {
        const exception = AuthException(
          'Test error message',
          statusCode: '400',
          code: 'validation_failed',
        );

        expect(exception.message, equals('Test error message'));
        expect(exception.statusCode, equals('400'));
        expect(exception.code, equals('validation_failed'));
      });
    });

    group('toString', () {
      test('includes all properties in string representation', () {
        const exception = AuthException(
          'Test error message',
          statusCode: '400',
          code: 'validation_failed',
        );

        final string = exception.toString();

        expect(string, contains('AuthException('));
        expect(string, contains('message: Test error message'));
        expect(string, contains('statusCode: 400'));
        expect(string, contains('code: validation_failed'));
      });

      test('handles null values correctly', () {
        const exception = AuthException('Test error message');

        final string = exception.toString();

        expect(string, contains('AuthException('));
        expect(string, contains('message: Test error message'));
        expect(string, contains('statusCode: null'));
        expect(string, contains('code: null'));
      });
    });

    group('equality and hashCode', () {
      test('returns true for identical exceptions', () {
        const exception1 = AuthException(
          'Test error message',
          statusCode: '400',
          code: 'validation_failed',
        );

        const exception2 = AuthException(
          'Test error message',
          statusCode: '400',
          code: 'validation_failed',
        );

        expect(exception1, equals(exception2));
        expect(exception1.hashCode, equals(exception2.hashCode));
      });

      test('returns false for exceptions with different messages', () {
        const exception1 = AuthException('Error message 1');
        const exception2 = AuthException('Error message 2');

        expect(exception1, isNot(equals(exception2)));
        expect(exception1.hashCode, isNot(equals(exception2.hashCode)));
      });

      test('returns false for exceptions with different status codes', () {
        const exception1 = AuthException('Test error', statusCode: '400');
        const exception2 = AuthException('Test error', statusCode: '401');

        expect(exception1, isNot(equals(exception2)));
      });

      test('returns false for exceptions with different codes', () {
        const exception1 =
            AuthException('Test error', code: 'validation_failed');
        const exception2 = AuthException('Test error', code: 'bad_json');

        expect(exception1, isNot(equals(exception2)));
      });

      test('handles null values correctly in equality', () {
        const exception1 = AuthException('Test error');
        const exception2 =
            AuthException('Test error', statusCode: null, code: null);

        expect(exception1, equals(exception2));
      });

      test('returns true for reference equality', () {
        const exception = AuthException('Test error');

        expect(exception, same(exception));
      });
    });

    group('implements Exception', () {
      test('is an instance of Exception', () {
        const exception = AuthException('Test error');

        expect(exception, isA<Exception>());
      });
    });
  });

  group('AuthPKCEGrantCodeExchangeError', () {
    test('extends AuthException', () {
      final exception = AuthPKCEGrantCodeExchangeError('PKCE error');

      expect(exception, isA<AuthException>());
      expect(exception.message, equals('PKCE error'));
      expect(exception.statusCode, isNull);
      expect(exception.code, isNull);
    });

    test('has correct toString format', () {
      final exception = AuthPKCEGrantCodeExchangeError('PKCE error');

      final string = exception.toString();

      expect(string, contains('AuthException('));
      expect(string, contains('message: PKCE error'));
    });
  });

  group('AuthSessionMissingException', () {
    test('extends AuthException', () {
      final exception = AuthSessionMissingException();

      expect(exception, isA<AuthException>());
    });

    test('uses default message when none provided', () {
      final exception = AuthSessionMissingException();

      expect(exception.message, equals('Auth session missing!'));
      expect(exception.statusCode, equals('400'));
    });

    test('uses custom message when provided', () {
      final exception = AuthSessionMissingException('Custom session error');

      expect(exception.message, equals('Custom session error'));
      expect(exception.statusCode, equals('400'));
    });

    test('has correct toString format', () {
      final exception = AuthSessionMissingException('Session error');

      final string = exception.toString();

      expect(string, contains('AuthSessionMissingException('));
      expect(string, contains('message: Session error'));
      expect(string, contains('statusCode: 400'));
    });
  });

  group('AuthRetryableFetchException', () {
    test('extends AuthException', () {
      final exception = AuthRetryableFetchException();

      expect(exception, isA<AuthException>());
    });

    test('uses default message when none provided', () {
      final exception = AuthRetryableFetchException();

      expect(exception.message, equals('AuthRetryableFetchException'));
      expect(exception.statusCode, isNull);
    });

    test('uses custom message and statusCode when provided', () {
      final exception = AuthRetryableFetchException(
        message: 'Network timeout',
        statusCode: '408',
      );

      expect(exception.message, equals('Network timeout'));
      expect(exception.statusCode, equals('408'));
    });

    test('has correct toString format', () {
      final exception = AuthRetryableFetchException(
        message: 'Retry error',
        statusCode: '500',
      );

      final string = exception.toString();

      expect(string, contains('AuthRetryableFetchException('));
      expect(string, contains('message: Retry error'));
      expect(string, contains('statusCode: 500'));
    });
  });

  group('AuthApiException', () {
    test('extends AuthException', () {
      final exception = AuthApiException('API error');

      expect(exception, isA<AuthException>());
    });

    test('creates exception with message only', () {
      final exception = AuthApiException('API error');

      expect(exception.message, equals('API error'));
      expect(exception.statusCode, isNull);
      expect(exception.code, isNull);
    });

    test('creates exception with all parameters', () {
      final exception = AuthApiException(
        'API error',
        statusCode: '422',
        code: 'validation_failed',
      );

      expect(exception.message, equals('API error'));
      expect(exception.statusCode, equals('422'));
      expect(exception.code, equals('validation_failed'));
    });

    test('has correct toString format', () {
      final exception = AuthApiException(
        'API error',
        statusCode: '422',
        code: 'bad_json',
      );

      final string = exception.toString();

      expect(string, contains('AuthApiException('));
      expect(string, contains('message: API error'));
      expect(string, contains('statusCode: 422'));
      expect(string, contains('code: bad_json'));
    });
  });

  group('AuthUnknownException', () {
    test('extends AuthException', () {
      final exception = AuthUnknownException(
        message: 'Unknown error',
        originalError: 'Original error',
      );

      expect(exception, isA<AuthException>());
    });

    test('creates exception with string original error', () {
      final exception = AuthUnknownException(
        message: 'Unknown error',
        originalError: 'Original error string',
      );

      expect(exception.message, equals('Unknown error'));
      expect(exception.originalError, equals('Original error string'));
      expect(exception.statusCode, isNull);
    });

    test('extracts status code from http.Response original error', () {
      final response = http.Response('Error body', 500);
      final exception = AuthUnknownException(
        message: 'Unknown error',
        originalError: response,
      );

      expect(exception.message, equals('Unknown error'));
      expect(exception.originalError, equals(response));
      expect(exception.statusCode, equals('500'));
    });

    test('handles non-http.Response objects', () {
      final originalError = Exception('Some other exception');
      final exception = AuthUnknownException(
        message: 'Unknown error',
        originalError: originalError,
      );

      expect(exception.message, equals('Unknown error'));
      expect(exception.originalError, equals(originalError));
      expect(exception.statusCode, isNull);
    });

    test('has correct toString format', () {
      final response = http.Response('Error body', 404);
      final exception = AuthUnknownException(
        message: 'Unknown error',
        originalError: response,
      );

      final string = exception.toString();

      expect(string, contains('AuthUnknownException('));
      expect(string, contains('message: Unknown error'));
      expect(string, contains('originalError:'));
      expect(string, contains('statusCode: 404'));
    });
  });

  group('AuthWeakPasswordException', () {
    test('extends AuthException', () {
      final exception = AuthWeakPasswordException(
        message: 'Password too weak',
        statusCode: '422',
        reasons: ['too_short'],
      );

      expect(exception, isA<AuthException>());
    });

    test('creates exception with all required parameters', () {
      final exception = AuthWeakPasswordException(
        message: 'Password is too weak',
        statusCode: '422',
        reasons: ['too_short', 'no_uppercase', 'no_numbers'],
      );

      expect(exception.message, equals('Password is too weak'));
      expect(exception.statusCode, equals('422'));
      expect(exception.code, equals(ErrorCode.weakPassword.code));
      expect(exception.reasons,
          equals(['too_short', 'no_uppercase', 'no_numbers']));
    });

    test('automatically sets code to weak_password', () {
      final exception = AuthWeakPasswordException(
        message: 'Password too weak',
        statusCode: '422',
        reasons: ['too_short'],
      );

      expect(exception.code, equals('weak_password'));
    });

    test('handles empty reasons list', () {
      final exception = AuthWeakPasswordException(
        message: 'Password too weak',
        statusCode: '422',
        reasons: [],
      );

      expect(exception.reasons, isEmpty);
    });

    test('has correct toString format', () {
      final exception = AuthWeakPasswordException(
        message: 'Password too weak',
        statusCode: '422',
        reasons: ['too_short', 'no_special_chars'],
      );

      final string = exception.toString();

      expect(string, contains('AuthWeakPasswordException('));
      expect(string, contains('message: Password too weak'));
      expect(string, contains('statusCode: 422'));
      expect(string, contains('reasons: [too_short, no_special_chars]'));
    });

    test('maintains equality based on parent class and reasons', () {
      final exception1 = AuthWeakPasswordException(
        message: 'Password too weak',
        statusCode: '422',
        reasons: ['too_short'],
      );

      final exception2 = AuthWeakPasswordException(
        message: 'Password too weak',
        statusCode: '422',
        reasons: ['too_short'],
      );

      final exception3 = AuthWeakPasswordException(
        message: 'Password too weak',
        statusCode: '422',
        reasons: ['no_uppercase'],
      );

      expect(exception1.message, equals(exception2.message));
      expect(exception1.statusCode, equals(exception2.statusCode));
      expect(exception1.code, equals(exception2.code));
      expect(exception1.reasons, equals(exception2.reasons));

      expect(exception1.reasons, isNot(equals(exception3.reasons)));
    });
  });

  group('Exception hierarchy', () {
    test('all exception types implement Exception', () {
      final authException = const AuthException('error');
      final pkceException = AuthPKCEGrantCodeExchangeError('error');
      final sessionException = AuthSessionMissingException();
      final retryException = AuthRetryableFetchException();
      final apiException = AuthApiException('error');
      final unknownException = AuthUnknownException(
        message: 'error',
        originalError: 'original',
      );
      final weakPasswordException = AuthWeakPasswordException(
        message: 'error',
        statusCode: '422',
        reasons: [],
      );

      expect(authException, isA<Exception>());
      expect(pkceException, isA<Exception>());
      expect(sessionException, isA<Exception>());
      expect(retryException, isA<Exception>());
      expect(apiException, isA<Exception>());
      expect(unknownException, isA<Exception>());
      expect(weakPasswordException, isA<Exception>());
    });

    test('all exception types extend AuthException', () {
      final pkceException = AuthPKCEGrantCodeExchangeError('error');
      final sessionException = AuthSessionMissingException();
      final retryException = AuthRetryableFetchException();
      final apiException = AuthApiException('error');
      final unknownException = AuthUnknownException(
        message: 'error',
        originalError: 'original',
      );
      final weakPasswordException = AuthWeakPasswordException(
        message: 'error',
        statusCode: '422',
        reasons: [],
      );

      expect(pkceException, isA<AuthException>());
      expect(sessionException, isA<AuthException>());
      expect(retryException, isA<AuthException>());
      expect(apiException, isA<AuthException>());
      expect(unknownException, isA<AuthException>());
      expect(weakPasswordException, isA<AuthException>());
    });

    test('can catch all auth exceptions as AuthException', () {
      final exceptions = <AuthException>[
        const AuthException('base error'),
        AuthPKCEGrantCodeExchangeError('pkce error'),
        AuthSessionMissingException(),
        AuthRetryableFetchException(),
        AuthApiException('api error'),
        AuthUnknownException(
            message: 'unknown error', originalError: 'original'),
        AuthWeakPasswordException(
          message: 'weak password',
          statusCode: '422',
          reasons: ['too_short'],
        ),
      ];

      for (final exception in exceptions) {
        expect(exception, isA<AuthException>());
        expect(exception.message, isNotEmpty);
      }
    });
  });

  group('Error handling scenarios', () {
    test('handles network timeout scenario', () {
      final exception = AuthRetryableFetchException(
        message: 'Request timeout',
        statusCode: '408',
      );

      expect(exception.message, equals('Request timeout'));
      expect(exception.statusCode, equals('408'));
    });

    test('handles validation error scenario', () {
      final exception = AuthApiException(
        'Validation failed',
        statusCode: '422',
        code: 'validation_failed',
      );

      expect(exception.message, equals('Validation failed'));
      expect(exception.statusCode, equals('422'));
      expect(exception.code, equals('validation_failed'));
    });

    test('handles authentication error scenario', () {
      final exception = AuthApiException(
        'Invalid credentials',
        statusCode: '401',
        code: 'bad_jwt',
      );

      expect(exception.message, equals('Invalid credentials'));
      expect(exception.statusCode, equals('401'));
      expect(exception.code, equals('bad_jwt'));
    });

    test('handles weak password scenario', () {
      final exception = AuthWeakPasswordException(
        message: 'Password does not meet requirements',
        statusCode: '422',
        reasons: [
          'Password must be at least 8 characters',
          'Password must contain uppercase letters',
          'Password must contain numbers',
        ],
      );

      expect(exception.message, equals('Password does not meet requirements'));
      expect(exception.statusCode, equals('422'));
      expect(exception.code, equals('weak_password'));
      expect(exception.reasons.length, equals(3));
    });

    test('handles unknown HTTP error scenario', () {
      final response = http.Response('Internal Server Error', 500);
      final exception = AuthUnknownException(
        message: 'An unexpected error occurred',
        originalError: response,
      );

      expect(exception.message, equals('An unexpected error occurred'));
      expect(exception.statusCode, equals('500'));
      expect(exception.originalError, equals(response));
    });

    test('handles PKCE code exchange error scenario', () {
      final exception = AuthPKCEGrantCodeExchangeError(
        'Invalid code verifier provided',
      );

      expect(exception.message, equals('Invalid code verifier provided'));
      expect(exception, isA<AuthException>());
    });
  });

  group('AuthClientDisposedException', () {
    test('extends AuthException', () {
      final exception = AuthClientDisposedException();
      expect(exception, isA<AuthException>());
    });

    test('creates with default message when no parameters provided', () {
      final exception = AuthClientDisposedException();

      expect(exception.message, equals('Auth client has been disposed'));
      expect(exception.code, equals('client_disposed'));
      expect(exception.operation, isNull);
      expect(exception.statusCode, isNull);
    });

    test('creates with custom message', () {
      final exception = AuthClientDisposedException(
        message: 'Custom disposed message',
      );

      expect(exception.message, equals('Custom disposed message'));
      expect(exception.code, equals('client_disposed'));
    });

    test('creates with operation context', () {
      final exception = AuthClientDisposedException(
        operation: 'token refresh',
      );

      expect(
        exception.message,
        equals('Auth client has been disposed during token refresh'),
      );
      expect(exception.operation, equals('token refresh'));
      expect(exception.code, equals('client_disposed'));
    });

    test('creates with custom message and operation context', () {
      final exception = AuthClientDisposedException(
        message: 'Client was terminated',
        operation: 'session recovery',
      );

      expect(
        exception.message,
        equals('Client was terminated during session recovery'),
      );
      expect(exception.operation, equals('session recovery'));
    });

    test('toString includes operation when provided', () {
      final exception = AuthClientDisposedException(
        operation: 'test operation',
      );

      final string = exception.toString();
      expect(string, contains('AuthClientDisposedException'));
      expect(string, contains('operation: test operation'));
    });

    test('toString handles null operation', () {
      final exception = AuthClientDisposedException();

      final string = exception.toString();
      expect(string, contains('AuthClientDisposedException'));
      expect(string, contains('operation: null'));
    });
  });
}
