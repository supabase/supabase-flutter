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
}

Future<void> _testFetchRequest(Client client) async {
  final GotrueFetch fetch = GotrueFetch(client);
  await expectLater(
    () => fetch.request(_mockUrl, RequestMethodType.get),
    throwsA(
      isA<AuthException>()
          .having((e) => e.code, 'code', 'weak_password')
          .having((e) => e.message, 'message', 'error_message'),
    ),
  );
}
