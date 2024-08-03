import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/types/api_version.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

void main() {
  group('ApiVersion', () {
    test('should return non null object for valid header', () {
      final String validHeader = '2024-01-01';
      final Response response = Response('', 200, headers: {
        Constants.apiVersionHeaderName: validHeader,
      });
      final version = ApiVersion.fromResponse(response);
      expect(version?.date, DateTime(2024, 1, 1));
      expect(version?.asString, validHeader);
    });

    test('should return null object for invalid header', () {
      final List<String> invalidValues = [
        '',
        'notadate',
        'Sat Feb 24 2024 17:59:17 GMT+0100',
        '1990-01-01',
        '2024-01-32',
      ];

      for (final value in invalidValues) {
        final Response response = Response('', 200, headers: {
          Constants.apiVersionHeaderName: value,
        });
        final version = ApiVersion.fromResponse(response);
        expect(version, isNull);
      }
    });

    test('should return null object for no header', () {
      final Response response = Response('', 200);
      final version = ApiVersion.fromResponse(response);
      expect(version, isNull);
    });
  });
}
