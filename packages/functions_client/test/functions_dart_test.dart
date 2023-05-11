import 'package:functions_client/src/functions_client.dart';
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
    test('simple function call', () async {
      final res = await functionsCustomHttpClient.invoke('function');
      expect(res.status, 420);
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
      final res = await client.invoke('function');
      expect(res.data, {'key': 'Hello World'});
    });
  });
}
