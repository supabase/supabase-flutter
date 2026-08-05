import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

class TestException extends SupabaseException {
  const TestException(super.message, {super.statusCode, super.errorCode});
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

    test('defaults the status and error code to null', () {
      const exception = TestException('boom');

      expect(exception.message, 'boom');
      expect(exception.statusCode, isNull);
      expect(exception.errorCode, isNull);
    });

    test('toString names the concrete subtype and lists all fields', () {
      const exception = TestException(
        'boom',
        statusCode: 500,
        errorCode: 'server_error',
      );

      expect(
        exception.toString(),
        'TestException(message: boom, statusCode: 500, '
        'errorCode: server_error)',
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
}
