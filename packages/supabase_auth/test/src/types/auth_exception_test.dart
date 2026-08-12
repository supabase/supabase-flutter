import 'package:supabase_auth/src/types/auth_exception.dart';
import 'package:supabase_auth/src/types/error_code.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('AuthException', () {
    test('toString lists the message and the error code', () {
      expect(
        const AuthException(
          'Test error',
          errorCode: 'validation_failed',
        ).toString(),
        'AuthException(message: Test error, errorCode: validation_failed)',
      );
      expect(
        const AuthException('Test error').toString(),
        'AuthException(message: Test error, errorCode: null)',
      );
    });

    test('equality compares the message and the error code', () {
      const exception = AuthException('Test error', errorCode: 'bad_json');
      const same = AuthException('Test error', errorCode: 'bad_json');
      const otherMessage = AuthException('Other error', errorCode: 'bad_json');
      const otherCode = AuthException('Test error', errorCode: 'other');

      expect(exception, equals(same));
      expect(exception.hashCode, equals(same.hashCode));
      expect(exception, isNot(equals(otherMessage)));
      expect(exception, isNot(equals(otherCode)));
    });

    test('a subtype is never equal to the base it extends', () {
      const base = AuthException('Test error');
      const api = AuthApiException('Test error', statusCode: 400);

      expect(base, isNot(equals(api)));
      expect(api, isNot(equals(base)));
    });
  });

  group('AuthSessionMissingException', () {
    test('defaults the message and names the failure', () {
      final exception = AuthSessionMissingException();

      expect(exception.message, 'Auth session missing!');
      expect(exception.errorCode, ErrorCode.sessionMissing.code);
    });

    test('keeps the error code when given a custom message', () {
      final exception = AuthSessionMissingException('Custom session error');

      expect(exception.message, 'Custom session error');
      expect(exception.errorCode, ErrorCode.sessionMissing.code);
    });
  });

  group('AuthInvalidJwtException', () {
    test('names the failure', () {
      final exception = AuthInvalidJwtException('Invalid JWT structure');

      expect(exception.message, 'Invalid JWT structure');
      expect(exception.errorCode, 'invalid_jwt');
    });
  });

  group('AuthRetryableFetchException', () {
    test('defaults the message to its own name', () {
      expect(
        AuthRetryableFetchException().message,
        'AuthRetryableFetchException',
      );
    });

    test('equality compares the message', () {
      expect(
        AuthRetryableFetchException(message: 'Retry error'),
        equals(AuthRetryableFetchException(message: 'Retry error')),
      );
      expect(
        AuthRetryableFetchException(message: 'Retry error'),
        isNot(equals(AuthRetryableFetchException(message: 'Other error'))),
      );
    });
  });

  group('AuthRetryableApiException', () {
    test('equality compares the status code', () {
      final exception = AuthRetryableApiException(
        message: 'Bad Gateway',
        statusCode: 502,
      );

      expect(
        exception,
        equals(
          AuthRetryableApiException(message: 'Bad Gateway', statusCode: 502),
        ),
      );
      expect(
        exception,
        isNot(
          equals(
            AuthRetryableApiException(message: 'Bad Gateway', statusCode: 503),
          ),
        ),
      );
    });

    test('is never equal to the transport failure it extends', () {
      final api = AuthRetryableApiException(
        message: 'Bad Gateway',
        statusCode: 502,
      );
      final transport = AuthRetryableFetchException(message: 'Bad Gateway');

      expect(api, isNot(equals(transport)));
      expect(transport, isNot(equals(api)));
    });
  });

  group('AuthApiException', () {
    test('toString adds the status code to the shared fields', () {
      expect(
        const AuthApiException(
          'API error',
          statusCode: 422,
          errorCode: 'bad_json',
        ).toString(),
        'AuthApiException(message: API error, statusCode: 422, '
        'errorCode: bad_json)',
      );
    });

    test('equality compares the status code', () {
      const exception = AuthApiException('API error', statusCode: 400);

      expect(
        exception,
        equals(const AuthApiException('API error', statusCode: 400)),
      );
      expect(
        exception,
        isNot(equals(const AuthApiException('API error', statusCode: 401))),
      );
    });
  });

  group('AuthUnknownException', () {
    test('keeps the response, so the status stays reachable', () {
      final response = http.Response('Error body', 500);
      final exception = AuthUnknownException(
        message: 'Unknown error',
        originalError: response,
      );

      expect(exception.originalError, same(response));
    });

    test('toString adds the original error and reports no status', () {
      final exception = AuthUnknownException(
        message: 'Unknown error',
        originalError: http.Response('Error body', 404),
      );

      final string = exception.toString();

      expect(
        string,
        startsWith(
          'AuthUnknownException(message: Unknown error, errorCode: null, '
          'originalError:',
        ),
      );
      expect(string, isNot(contains('statusCode:')));
    });
  });

  group('AuthWeakPasswordException', () {
    test('always reports the weak_password error code', () {
      final exception = AuthWeakPasswordException(
        message: 'Password too weak',
        statusCode: 422,
        reasons: ['too_short'],
      );

      expect(exception.errorCode, ErrorCode.weakPassword.code);
    });

    test('toString adds the reasons', () {
      final exception = AuthWeakPasswordException(
        message: 'Password too weak',
        statusCode: 422,
        reasons: ['too_short', 'no_special_chars'],
      );

      expect(
        exception.toString(),
        'AuthWeakPasswordException(message: Password too weak, '
        'statusCode: 422, errorCode: weak_password, '
        'reasons: [too_short, no_special_chars])',
      );
    });
  });

  group('Exception hierarchy', () {
    test('only the response backed exceptions are SupabaseApiException', () {
      final List<SupabaseException> serviceAnswered = [
        const AuthApiException('api error', statusCode: 500),
        AuthRetryableApiException(message: 'retryable', statusCode: 503),
        AuthWeakPasswordException(
          message: 'weak password',
          statusCode: 422,
          reasons: ['too_short'],
        ),
      ];

      for (final exception in serviceAnswered) {
        expect(exception, isA<SupabaseApiException>());
      }

      final List<SupabaseException> clientOnly = [
        const AuthException('base error'),
        AuthPKCEGrantCodeExchangeError('pkce error'),
        AuthSessionMissingException(),
        AuthInvalidJwtException('invalid jwt'),
        AuthRetryableFetchException(),
        AuthUnknownException(
          message: 'unknown error',
          originalError: 'original',
        ),
      ];

      for (final exception in clientOnly) {
        expect(exception, isNot(isA<SupabaseApiException>()));
      }
    });
  });
}
