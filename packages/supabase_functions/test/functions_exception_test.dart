import 'package:http/http.dart';
import 'package:supabase_functions/supabase_functions.dart';
import 'package:test/test.dart';

void main() {
  test('every functions exception names itself in toString', () {
    final exceptions = <String, FunctionsException>{
      'FunctionsFetchException': const FunctionsFetchException(),
      'FunctionsApiException': const FunctionsApiException(statusCode: 500),
      'FunctionsRelayException': const FunctionsRelayException(
        statusCode: 500,
      ),
    };

    for (final MapEntry(key: name, value: exception) in exceptions.entries) {
      expect(exception.toString(), startsWith('$name('));
    }
  });

  test('toString keeps the request query out of the cause', () {
    final cause = ClientException(
      'Connection refused',
      Uri.parse('https://example.com/functions/v1/hello?token=secret-token'),
    );
    final exceptions = [
      FunctionsFetchException(cause: cause),
      FunctionsApiException(statusCode: 500, details: cause),
    ];

    for (final exception in exceptions) {
      expect(
        exception.toString(),
        allOf(
          contains('https://example.com/functions/v1/hello'),
          isNot(contains('secret-token')),
        ),
      );
    }
  });
}
