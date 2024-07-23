import 'dart:convert';

import 'package:functions_client/src/functions_client.dart';
import 'package:functions_client/src/types.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

import 'custom_http_client.dart';

void main() {
  late FunctionsClient functionsCustomHttpClient;
  late CustomHttpClient customHttpClient;

  group("Custom http client", () {
    setUp(() {
      customHttpClient = CustomHttpClient();
      functionsCustomHttpClient =
          FunctionsClient("", {}, httpClient: customHttpClient);
    });
    test('function throws', () async {
      try {
        await functionsCustomHttpClient.invoke('error-function');
        fail('should throw');
      } on FunctionException catch (e) {
        expect(e.status, 420);
      }
    });

    test('function call', () async {
      final res = await functionsCustomHttpClient.invoke('function');
      expect(
          customHttpClient.receivedRequests.last.headers["Content-Type"], null);
      expect(res.data, {'key': 'Hello World'});
      expect(res.status, 200);
    });

    test('function call with query parameters', () async {
      final res = await functionsCustomHttpClient
          .invoke('function', queryParameters: {'key': 'value'});

      final request = customHttpClient.receivedRequests.last;

      expect(request.url.queryParameters, {'key': 'value'});
      expect(res.data, {'key': 'Hello World'});
      expect(res.status, 200);
    });

    test('function call with files', () async {
      final fileName = "file.txt";
      final fileContent = "Hello World";
      final res = await functionsCustomHttpClient.invoke(
        'function',
        queryParameters: {'key': 'value'},
        files: [
          MultipartFile.fromString(fileName, fileContent),
        ],
      );

      final request = customHttpClient.receivedRequests.last;

      expect(request.url.queryParameters, {'key': 'value'});
      expect(request.headers['Content-Type'], contains('multipart/form-data'));
      expect(res.data, [
        {'name': fileName, 'content': fileContent}
      ]);
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
      final res = await client.invoke('function');
      expect(res.data, {'key': 'Hello World'});
    });

    test('Listen to SSE event', () async {
      final res = await functionsCustomHttpClient.invoke('sse');
      expect(
          res.data.transform(const Utf8Decoder()),
          emitsInOrder(
            ['a', 'b', 'c'],
          ));
    });

    group('body encoding', () {
      test('integer properly encoded', () async {
        await functionsCustomHttpClient.invoke('function', body: 42);

        final req = customHttpClient.receivedRequests.last;
        expect(req, isA<Request>());

        req as Request;
        expect(req.body, '42');
        expect(req.headers["Content-Type"], contains("application/json"));
      });

      test('double is properly encoded', () async {
        await functionsCustomHttpClient.invoke('function', body: 42.9);

        final req = customHttpClient.receivedRequests.last;
        expect(req, isA<Request>());

        req as Request;
        expect(req.body, '42.9');
        expect(req.headers["Content-Type"], contains("application/json"));
      });

      test('string is properly encoded', () async {
        await functionsCustomHttpClient.invoke('function', body: 'ExampleText');

        final req = customHttpClient.receivedRequests.last;
        expect(req, isA<Request>());

        req as Request;
        expect(req.body, 'ExampleText');
        expect(req.headers["Content-Type"], contains("text/plain"));
      });

      test('list is properly encoded', () async {
        await functionsCustomHttpClient.invoke('function', body: [1, 2, 3]);

        final req = customHttpClient.receivedRequests.last;
        expect(req, isA<Request>());

        req as Request;
        expect(req.body, '[1,2,3]');
        expect(req.headers["Content-Type"], contains("application/json"));
      });

      test('map is properly encoded', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          body: {'thekey': 'thevalue'},
        );

        final req = customHttpClient.receivedRequests.last;
        expect(req, isA<Request>());

        req as Request;
        expect(req.body, '{"thekey":"thevalue"}');
        expect(req.headers["Content-Type"], contains("application/json"));
      });
    });
  });
}
