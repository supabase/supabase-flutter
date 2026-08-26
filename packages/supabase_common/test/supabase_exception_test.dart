import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

class TestException extends SupabaseException {
  const TestException(super.message, {super.errorCode});
}

class TestApiException extends SupabaseException with SupabaseApiException {
  const TestApiException(
    super.message, {
    required this.statusCode,
    super.errorCode,
  });
  @override
  final int statusCode;
}

class DetailedException extends SupabaseException {
  const DetailedException(super.message, {required this.details});
  final String details;

  @override
  String toString() => '$runtimeType(message: $message, details: $details)';
}

void main() {
  test('toString names the concrete subtype and lists the shared fields', () {
    const exception = TestException('boom', errorCode: 'server_error');

    expect(
      exception.toString(),
      'TestException(message: boom, errorCode: server_error)',
    );
  });

  test('the api mixin adds the status code to toString', () {
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

  test('subtypes can replace toString with their own fields', () {
    const exception = DetailedException('boom', details: 'stack');

    expect(
      exception.toString(),
      'DetailedException(message: boom, details: stack)',
    );
  });
}
