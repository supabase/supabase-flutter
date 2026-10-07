import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

class TestException extends SupabaseException {
  const TestException(super.message, {super.errorCode, super.requestId});
}

class TestApiException extends SupabaseException with SupabaseApiException {
  const TestApiException(
    super.message, {
    required this.statusCode,
    super.errorCode,
    super.requestId,
    this.headers = const {},
    this.body,
  });
  @override
  final int statusCode;
  @override
  final Map<String, String> headers;
  @override
  final String? body;
}

class TestTransportException extends SupabaseException
    with SupabaseTransportException {
  const TestTransportException(super.message, {this.cause});
  @override
  final Object? cause;
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
      'TestException(message: boom, errorCode: server_error, requestId: null)',
    );
  });

  test('toString lists the request id when the response carried one', () {
    const exception = TestException(
      'boom',
      errorCode: 'server_error',
      requestId: '01a0d2ea-2094-72da-ae7f-a390251e6909',
    );

    expect(exception.requestId, '01a0d2ea-2094-72da-ae7f-a390251e6909');
    expect(
      exception.toString(),
      'TestException(message: boom, errorCode: server_error, '
      'requestId: 01a0d2ea-2094-72da-ae7f-a390251e6909)',
    );
  });

  test('the api mixin adds the status code to toString', () {
    const exception = TestApiException(
      'boom',
      statusCode: 500,
      errorCode: 'server_error',
      requestId: 'request-1',
    );

    expect(
      exception.toString(),
      'TestApiException(message: boom, statusCode: 500, '
      'errorCode: server_error, requestId: request-1)',
    );
  });

  test('the api mixin carries the response headers and body', () {
    const exception = TestApiException(
      'boom',
      statusCode: 500,
      headers: {'content-type': 'text/plain'},
      body: 'boom',
    );

    expect(exception.headers, {'content-type': 'text/plain'});
    expect(exception.body, 'boom');
    expect(const TestApiException('boom', statusCode: 500).headers, isEmpty);
    expect(const TestApiException('boom', statusCode: 500).body, isNull);
  });

  test('the transport mixin adds the cause to toString', () {
    const exception = TestTransportException('offline', cause: 'no route');

    expect(exception.cause, 'no route');
    expect(
      exception.toString(),
      'TestTransportException(message: offline, errorCode: null, '
      'requestId: null, cause: no route)',
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
