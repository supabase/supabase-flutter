import 'package:supabase_functions/supabase_functions.dart';
import 'package:test/test.dart';

void main() {
  test('every functions exception names itself in toString', () {
    final exceptions = <String, FunctionException>{
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
}
