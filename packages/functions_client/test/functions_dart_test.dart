import 'package:functions_client/src/functions_client.dart';
import 'package:functions_client/src/types.dart';
import 'package:test/test.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

import 'custom_http_client.dart';

void main() {
  late FunctionsClient functionsCustomHttpClient;

  group("Custom http client", () {
    setUp(() {
      functionsCustomHttpClient =
          FunctionsClient("", {}, httpClient: CustomHttpClient());
    });
    test('function throws', () async {
      try {
        await functionsCustomHttpClient.invoke('function');
        fail('should throw');
      } on FunctionException catch (e) {
        expect(e.status, 420);
      }
    });

    test('function call', () async {
      final res = await functionsCustomHttpClient.invoke('function1');
      expect(res.data, {'key': 'Hello World'});
      expect(res.status, 200);
    });

    test('dispose isolate', () async {
      await functionsCustomHttpClient.dispose();
      expect(functionsCustomHttpClient.invoke('function'), throwsStateError);
    });

    test('do not dispose custom isolate', () async {
      final client = FunctionsClient(
        "",
        {},
        isolate: YAJsonIsolate(),
        httpClient: CustomHttpClient(),
      );

      await client.dispose();
      final res = await client.invoke('function1');
      expect(res.data, {'key': 'Hello World'});
    });
  });
}
