import 'package:gotrue/gotrue.dart';
import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/fetch.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';

const String _mockUrl = 'http://localhost';
void main() {
  group('GotrueFetch', () {
    test('without API version and error code', () async {
      final client = MockedHttpClient(
        {
          'code': 400,
          'msg': 'error_message',
          'error_code': 'weak_password',
        },
        statusCode: 400,
      );
      await _testFetchRequest(client);
    });

    test(
      'without API version and weak password error code with payload',
      () async {
        final client = MockedHttpClient(
          {
            'code': 400,
            'msg': 'error_message',
            'error_code': 'weak_password',
            'weak_password': {
              'reasons': ['characters'],
            },
          },
          statusCode: 400,
        );
        await _testFetchRequest(client);
      },
    );

    test(
      'without API version, no error code and weak_password payload',
      () async {
        final client = MockedHttpClient(
          {
            'msg': 'error_message',
            'weak_password': {
              'reasons': ['characters'],
            },
          },
          statusCode: 400,
        );
        await _testFetchRequest(client);
      },
    );

    test('with API version 2024-01-01 and error code', () async {
      final client = MockedHttpClient(
        {
          'code': 'weak_password',
          'message': 'error_message',
          'weak_password': {
            'reasons': ['characters'],
          },
        },
        headers: {
          Constants.apiVersionHeaderName: '2024-01-01',
        },
        statusCode: 400,
      );
      await _testFetchRequest(client);
    });
  });

  group('GotrueFetch server errors', () {
    test('preserves the server sent message on a JSON 5xx body', () async {
      final client = MockedHttpClient(
        {
          'code': 'unexpected_failure',
          'message': 'Error sending confirmation email',
        },
        headers: {
          Constants.apiVersionHeaderName: '2024-01-01',
        },
        statusCode: 500,
      );

      await _expectRetryableFetch(
        client,
        message: 'Error sending confirmation email',
        statusCode: '500',
      );
    });

    test(
      'preserves the server sent message on a JSON 5xx body without an API '
      'version',
      () async {
        final client = MockedHttpClient(
          {
            'code': 500,
            'error_code': 'unexpected_failure',
            'msg': 'Error sending confirmation email',
          },
          statusCode: 500,
        );

        await _expectRetryableFetch(
          client,
          message: 'Error sending confirmation email',
          statusCode: '500',
        );
      },
    );

    test('falls back to the reason phrase on a non-JSON 5xx body', () async {
      final client = RawBodyHttpClient(
        '<html><body><h1>502 Bad Gateway</h1></body></html>',
        statusCode: 502,
        reasonPhrase: 'Bad Gateway',
      );

      await _expectRetryableFetch(
        client,
        message: 'Bad Gateway',
        statusCode: '502',
      );
    });

    test(
      'falls back to the status code when there is no reason phrase',
      () async {
        final client = RawBodyHttpClient(
          '<html><body><h1>502 Bad Gateway</h1></body></html>',
          statusCode: 502,
        );

        await _expectRetryableFetch(
          client,
          message: 'HTTP 502',
          statusCode: '502',
        );
      },
    );

    test(
      'falls back to the status code when the reason phrase is empty',
      () async {
        final client = RawBodyHttpClient(
          '<html><body><h1>502 Bad Gateway</h1></body></html>',
          statusCode: 502,
          reasonPhrase: '',
        );

        await _expectRetryableFetch(
          client,
          message: 'HTTP 502',
          statusCode: '502',
        );
      },
    );

    test('falls back to the reason phrase on an empty 5xx body', () async {
      final client = RawBodyHttpClient(
        '',
        statusCode: 503,
        reasonPhrase: 'Service Unavailable',
      );

      await _expectRetryableFetch(
        client,
        message: 'Service Unavailable',
        statusCode: '503',
      );
    });

    test(
      'falls back to the status code on an empty 5xx body without a reason '
      'phrase',
      () async {
        final client = RawBodyHttpClient('', statusCode: 503);

        await _expectRetryableFetch(
          client,
          message: 'HTTP 503',
          statusCode: '503',
        );
      },
    );

    test('throws an unknown exception on a non-JSON 4xx body', () async {
      final client = RawBodyHttpClient(
        '<html><body><h1>400 Bad Request</h1></body></html>',
        statusCode: 400,
        reasonPhrase: 'Bad Request',
      );

      await expectLater(
        GotrueFetch(client).request(_mockUrl, RequestMethodType.get),
        throwsA(isA<AuthUnknownException>()),
      );
    });
  });
}

Future<void> _expectRetryableFetch(
  Client client, {
  required String message,
  required String statusCode,
}) async {
  await expectLater(
    GotrueFetch(client).request(_mockUrl, RequestMethodType.get),
    throwsA(
      isA<AuthRetryableFetchException>()
          .having((e) => e.message, 'message', message)
          .having((e) => e.statusCode, 'statusCode', statusCode),
    ),
  );
}

Future<void> _testFetchRequest(Client client) async {
  final GotrueFetch fetch = GotrueFetch(client);
  await expectLater(
    fetch.request(_mockUrl, RequestMethodType.get),
    throwsA(
      isA<AuthException>()
          .having((e) => e.code, 'code', 'weak_password')
          .having((e) => e.message, 'message', 'error_message'),
    ),
  );
}
