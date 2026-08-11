import 'dart:convert';

import 'package:gotrue/gotrue.dart';
import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/fetch.dart';
import 'package:gotrue/src/types/fetch_options.dart';
import 'package:http/http.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

import 'custom_http_client.dart';

/// Records the headers of the last request so they can be asserted on.
class RequestCapturingHttpClient extends BaseClient {
  Map<String, String>? lastHeaders;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastHeaders = request.headers;
    return StreamedResponse(
      Stream.value(utf8.encode('{}')),
      200,
      request: request,
    );
  }
}

const String _mockUrl = 'http://localhost';
void main() {
  group('GotrueFetch', () {
    test('reads the error code without an API version header', () async {
      final client = MockedHttpClient(
        {
          'code': 'weak_password',
          'message': 'error_message',
          'weak_password': {
            'reasons': ['characters'],
          },
        },
        statusCode: 400,
      );
      await _testFetchRequest(client);
    });

    test('ignores the legacy error_code field', () async {
      final client = MockedHttpClient(
        {
          'code': 400,
          'msg': 'error_message',
          'error_code': 'weak_password',
        },
        statusCode: 400,
      );
      await _expectUncodedApiException(client);
    });

    test('ignores a weak_password payload without an error code', () async {
      final client = MockedHttpClient(
        {
          'msg': 'error_message',
          'weak_password': {
            'reasons': ['characters'],
          },
        },
        statusCode: 400,
      );
      await _expectUncodedApiException(client);
    });

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

  group('GotrueFetch API version header', () {
    test('sends the supported API version', () async {
      final client = RequestCapturingHttpClient();

      await GotrueFetch(client).request(_mockUrl, HttpMethod.get);

      expect(
        client.lastHeaders?[Constants.apiVersionHeaderName],
        Constants.apiVersion,
      );
    });

    test('overrides a caller supplied API version', () async {
      final client = RequestCapturingHttpClient();

      await GotrueFetch(client).request(
        _mockUrl,
        HttpMethod.get,
        options: GotrueRequestOptions(
          headers: {Constants.apiVersionHeaderName: '2023-01-01'},
        ),
      );

      expect(
        client.lastHeaders?[Constants.apiVersionHeaderName],
        Constants.apiVersion,
      );
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
        GotrueFetch(client).request(_mockUrl, HttpMethod.get),
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
    GotrueFetch(client).request(_mockUrl, HttpMethod.get),
    throwsA(
      isA<AuthRetryableFetchException>()
          .having((e) => e.message, 'message', message)
          .having((e) => e.statusCode, 'statusCode', statusCode),
    ),
  );
}

Future<void> _expectUncodedApiException(Client client) async {
  await expectLater(
    GotrueFetch(client).request(_mockUrl, HttpMethod.get),
    throwsA(
      isA<AuthApiException>()
          .having((e) => e.code, 'code', isNull)
          .having((e) => e.message, 'message', 'error_message'),
    ),
  );
}

Future<void> _testFetchRequest(Client client) async {
  final GotrueFetch fetch = GotrueFetch(client);
  await expectLater(
    fetch.request(_mockUrl, HttpMethod.get),
    throwsA(
      isA<AuthWeakPasswordException>()
          .having((e) => e.code, 'code', 'weak_password')
          .having((e) => e.message, 'message', 'error_message')
          .having((e) => e.reasons, 'reasons', ['characters']),
    ),
  );
}
