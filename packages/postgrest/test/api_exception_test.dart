import 'package:http/http.dart' show ClientException, RequestAbortedException;
import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

const _requestIdHeaders = {'sb-request-id': 'request-1'};

PostgrestClient _buildClient(MockSupabaseHttpClient httpClient) =>
    PostgrestClient('http://localhost:3000', httpClient: httpClient);

void main() {
  group('PostgrestApiException', () {
    test('toString and toJson list every field', () {
      const exception = PostgrestApiException(
        message: 'boom',
        statusCode: 400,
        errorCode: 'PGRST100',
        requestId: 'request-1',
        details: 'unexpected token',
        hint: 'check the filter',
      );

      expect(
        exception.toString(),
        'PostgrestApiException(message: boom, statusCode: 400, '
        'errorCode: PGRST100, requestId: request-1, '
        'details: unexpected token, hint: check the filter)',
      );
      expect(exception.toJson(), {
        'message': 'boom',
        'statusCode': 400,
        'errorCode': 'PGRST100',
        'requestId': 'request-1',
        'details': 'unexpected token',
        'hint': 'check the filter',
      });
    });

    test('fromJson keeps the request id alongside the body fields', () {
      final exception = PostgrestApiException.fromJson(
        {'message': 'boom', 'code': 'PGRST100'},
        statusCode: 400,
        requestId: 'request-1',
      );

      expect(exception.errorCode, 'PGRST100');
      expect(exception.requestId, 'request-1');
    });
  });

  group('response context', () {
    test('an error response carries its headers and body', () async {
      final client = _buildClient(
        MockSupabaseHttpClient()..stub(
          {'message': 'boom', 'code': 'PGRST100'},
          statusCode: 400,
          headers: _requestIdHeaders,
        ),
      );

      await expectLater(
        () => client.from('users').select(),
        throwsA(
          isA<PostgrestApiException>()
              .having(
                (error) => error.headers['sb-request-id'],
                'request id header',
                'request-1',
              )
              .having(
                (error) => error.body,
                'body',
                '{"message":"boom","code":"PGRST100"}',
              ),
        ),
      );
    });

    test('a non-JSON error response keeps the raw body', () async {
      final client = _buildClient(
        MockSupabaseHttpClient()
          ..stubText('<html>502 Bad Gateway</html>', statusCode: 502),
      );

      await expectLater(
        () => client.from('users').select(),
        throwsA(
          isA<PostgrestApiException>().having(
            (error) => error.body,
            'body',
            '<html>502 Bad Gateway</html>',
          ),
        ),
      );
    });

    test('an exception built by hand has no headers or body', () {
      const exception = PostgrestApiException(message: 'boom', statusCode: 400);

      expect(exception.headers, isEmpty);
      expect(exception.body, isNull);
    });
  });

  group('PostgrestTransportException', () {
    test('wraps a request that got no response', () async {
      final client = _buildClient(
        MockSupabaseHttpClient()..stubError(ClientException('Offline')),
      );

      await expectLater(
        () => client.from('users').select(),
        throwsA(
          isA<PostgrestTransportException>()
              .having((error) => error.cause, 'cause', isA<ClientException>())
              .having((error) => error.message, 'message', contains('Offline')),
        ),
      );
    });

    test('passes an exception the HTTP client classified through', () async {
      final client = _buildClient(
        MockSupabaseHttpClient()
          ..stubError(const PostgrestException('session expired')),
      );

      await expectLater(
        () => client.from('users').select(),
        throwsA(
          allOf(
            isA<PostgrestException>().having(
              (error) => error.message,
              'message',
              'session expired',
            ),
            isNot(isA<PostgrestTransportException>()),
          ),
        ),
      );
    });

    test('is a PostgrestException and a SupabaseTransportException', () {
      const SupabaseException exception = PostgrestTransportException(
        'offline',
      );

      expect(exception, isA<PostgrestException>());
      expect(exception, isA<SupabaseTransportException>());
      expect(exception, isNot(isA<SupabaseApiException>()));
      expect(
        exception.toString(),
        'PostgrestTransportException(message: offline, errorCode: null, '
        'requestId: null, cause: null)',
      );
    });

    test('an abort is not wrapped', () async {
      final client = _buildClient(
        MockSupabaseHttpClient()..stubError(RequestAbortedException()),
      );

      await expectLater(
        () => client.from('users').select(),
        throwsA(isA<RequestAbortedException>()),
      );
    });
  });

  group('request id', () {
    test('is read from the response of a JSON error body', () async {
      final client = _buildClient(
        MockSupabaseHttpClient()..stub(
          {'message': 'boom', 'code': 'PGRST100'},
          statusCode: 400,
          headers: _requestIdHeaders,
        ),
      );

      await expectLater(
        () => client.from('users').select(),
        throwsA(
          isA<PostgrestApiException>()
              .having((e) => e.errorCode, 'errorCode', 'PGRST100')
              .having((e) => e.requestId, 'requestId', 'request-1'),
        ),
      );
    });

    test('is read from the response of a non-JSON error body', () async {
      final client = _buildClient(
        MockSupabaseHttpClient()..stubText(
          '<html>502 Bad Gateway</html>',
          statusCode: 502,
          headers: _requestIdHeaders,
        ),
      );

      await expectLater(
        () => client.from('users').select(),
        throwsA(
          isA<PostgrestApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having((e) => e.requestId, 'requestId', 'request-1'),
        ),
      );
    });

    test('is read from the response of a HEAD error', () async {
      final client = _buildClient(
        MockSupabaseHttpClient()
          ..stub(null, statusCode: 400, headers: _requestIdHeaders),
      );

      await expectLater(
        () => client.from('users').count(),
        throwsA(
          isA<PostgrestApiException>()
              .having((e) => e.requestId, 'requestId', 'request-1')
              .having(
                (e) => e.details,
                'details',
                'Error in Postgrest response for method HEAD',
              ),
        ),
      );
    });

    test('is read from a success response that is not JSON', () async {
      final client = _buildClient(
        MockSupabaseHttpClient()..stubText(
          '<html>maintenance</html>',
          statusCode: 200,
          headers: _requestIdHeaders,
        ),
      );

      await expectLater(
        () => client.from('users').select(),
        throwsA(
          isA<PostgrestApiException>()
              .having((e) => e.statusCode, 'statusCode', 200)
              .having((e) => e.requestId, 'requestId', 'request-1'),
        ),
      );
    });

    test('is read from the response maybeSingle rejects', () async {
      final client = _buildClient(
        MockSupabaseHttpClient()..stub(
          [
            {'id': 1},
            {'id': 2},
          ],
          headers: _requestIdHeaders,
        ),
      );

      await expectLater(
        () => client.from('users').select().maybeSingle(),
        throwsA(
          isA<PostgrestApiException>()
              .having((e) => e.errorCode, 'errorCode', 'PGRST116')
              .having((e) => e.requestId, 'requestId', 'request-1'),
        ),
      );
    });

    test('is null when the response carries none', () async {
      final client = _buildClient(
        MockSupabaseHttpClient()
          ..stub({'message': 'boom', 'code': 'PGRST100'}, statusCode: 400),
      );

      await expectLater(
        () => client.from('users').select(),
        throwsA(
          isA<PostgrestApiException>().having(
            (e) => e.requestId,
            'requestId',
            isNull,
          ),
        ),
      );
    });
  });
}
