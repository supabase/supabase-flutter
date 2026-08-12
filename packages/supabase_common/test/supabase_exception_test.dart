import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

class TestException extends SupabaseException {
  const TestException(super.message, {super.errorCode});
}

class TestApiException extends SupabaseException with SupabaseApiException {
  @override
  final int statusCode;

  const TestApiException(
    super.message, {
    required this.statusCode,
    super.errorCode,
  });
}

class DetailedException extends SupabaseException {
  final String details;

  const DetailedException(super.message, {required this.details});

  @override
  String toString() => '$runtimeType(message: $message, details: $details)';
}

void main() {
  group('SupabaseException', () {
    test('is an Exception', () {
      expect(const TestException('boom'), isA<Exception>());
    });

    test('defaults the error code to null', () {
      const exception = TestException('boom');

      expect(exception.message, 'boom');
      expect(exception.errorCode, isNull);
    });

    test('is not a SupabaseApiException', () {
      const SupabaseException exception = TestException('boom');

      expect(exception, isNot(isA<SupabaseApiException>()));
    });

    test('toString names the concrete subtype and lists all fields', () {
      const exception = TestException('boom', errorCode: 'server_error');

      expect(
        exception.toString(),
        'TestException(message: boom, errorCode: server_error)',
      );
    });

    test('subtypes can extend toString with their own fields', () {
      const exception = DetailedException('boom', details: 'stack');

      expect(
        exception.toString(),
        'DetailedException(message: boom, details: stack)',
      );
    });
  });

  group('SupabaseApiException', () {
    test('is a SupabaseException', () {
      expect(
        const TestApiException('boom', statusCode: 500),
        isA<SupabaseException>(),
      );
    });

    test('carries the status code alongside the shared fields', () {
      const exception = TestApiException(
        'boom',
        statusCode: 500,
        errorCode: 'server_error',
      );

      expect(exception.message, 'boom');
      expect(exception.statusCode, 500);
      expect(exception.errorCode, 'server_error');
    });

    test('toString names the concrete subtype and lists all fields', () {
      const exception = TestApiException(
        'boom',
        statusCode: 500,
        errorCode: 'server_error',
      );

      expect(
        exception.toString(),
        'TestApiException(message: boom, statusCode: 500, '
        'errorCode: server_error)',
      );
    });
  });
}
