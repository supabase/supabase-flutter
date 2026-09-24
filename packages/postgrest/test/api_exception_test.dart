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
        client.from('users').select(),
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
        client.from('users').select(),
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
        client.from('users').select().count(CountOption.exact),
        throwsA(
          isA<PostgrestApiException>().having(
            (e) => e.requestId,
            'requestId',
            'request-1',
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
        client.from('users').select(),
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
        client.from('users').select().maybeSingle(),
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
        client.from('users').select(),
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
