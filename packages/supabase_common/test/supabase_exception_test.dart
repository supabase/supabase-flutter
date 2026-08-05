import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

class _TestException extends SupabaseException {
  const _TestException(super.message, {super.statusCode, super.errorCode});
}

class _DetailedException extends SupabaseException {
  final String details;

  const _DetailedException(super.message, {required this.details});

  @override
  String toString() => '$runtimeType(message: $message, details: $details)';
}

void main() {
  group('SupabaseException', () {
    test('is an Exception', () {
      expect(const _TestException('boom'), isA<Exception>());
    });

    test('defaults the status and error code to null', () {
      const exception = _TestException('boom');

      expect(exception.message, 'boom');
      expect(exception.statusCode, isNull);
      expect(exception.errorCode, isNull);
    });

    test('toString names the concrete subtype and lists all fields', () {
      const exception = _TestException(
        'boom',
        statusCode: 500,
        errorCode: 'server_error',
      );

      expect(
        exception.toString(),
        '_TestException(message: boom, statusCode: 500, '
        'errorCode: server_error)',
      );
    });

    test('subtypes can extend toString with their own fields', () {
      const exception = _DetailedException('boom', details: 'stack');

      expect(
        exception.toString(),
        '_DetailedException(message: boom, details: stack)',
      );
    });
  });
}
