import 'dart:convert';
import 'dart:typed_data';

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

      test('Uint8List is properly encoded as binary data', () async {
        final binaryData = Uint8List.fromList([1, 2, 3, 4, 5]);
        await functionsCustomHttpClient.invoke('function', body: binaryData);

        final req = customHttpClient.receivedRequests.last;
        expect(req, isA<Request>());

        req as Request;
        expect(req.bodyBytes, equals(binaryData));
        expect(req.headers["Content-Type"], equals("application/octet-stream"));
      });

      test('null body sends no content-type', () async {
        await functionsCustomHttpClient.invoke('function');

        final req = customHttpClient.receivedRequests.last;
        expect(req, isA<Request>());

        req as Request;
        expect(req.body, '');
        expect(req.headers.containsKey("Content-Type"), isFalse);
      });
    });

    group('HTTP methods', () {
      test('GET method', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          method: HttpMethod.get,
        );

        final req = customHttpClient.receivedRequests.last;
        expect(req.method, 'get');
      });

      test('PUT method', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          method: HttpMethod.put,
        );

        final req = customHttpClient.receivedRequests.last;
        expect(req.method, 'put');
      });

      test('DELETE method', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          method: HttpMethod.delete,
        );

        final req = customHttpClient.receivedRequests.last;
        expect(req.method, 'delete');
      });

      test('PATCH method', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          method: HttpMethod.patch,
        );

        final req = customHttpClient.receivedRequests.last;
        expect(req.method, 'patch');
      });
    });

    group('Headers', () {
      test('setAuth updates authorization header', () async {
        functionsCustomHttpClient.setAuth('new-token');

        await functionsCustomHttpClient.invoke('function');

        final req = customHttpClient.receivedRequests.last;
        expect(req.headers['Authorization'], 'Bearer new-token');
      });

      test('headers getter returns current headers', () {
        functionsCustomHttpClient.setAuth('test-token');

        final headers = functionsCustomHttpClient.headers;
        expect(headers['Authorization'], 'Bearer test-token');
        expect(headers, contains('X-Client-Info'));
      });

      test('custom headers override defaults', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          headers: {'Content-Type': 'custom/type'},
        );

        final req = customHttpClient.receivedRequests.last;
        expect(req.headers['Content-Type'], 'custom/type');
      });

      test('custom headers merge with defaults', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          headers: {'X-Custom': 'value'},
        );

        final req = customHttpClient.receivedRequests.last;
        expect(req.headers['X-Custom'], 'value');
        expect(req.headers, contains('X-Client-Info'));
      });
    });

    group('Constructor variations', () {
      test('constructor with all parameters', () {
        final isolate = YAJsonIsolate();
        final httpClient = CustomHttpClient();
        final client = FunctionsClient(
          'https://example.com',
          {'X-Test': 'value'},
          httpClient: httpClient,
          isolate: isolate,
        );

        expect(client.headers['X-Test'], 'value');
        expect(client.headers, contains('X-Client-Info'));
      });

      test('constructor with minimal parameters', () {
        final client = FunctionsClient('https://example.com', {});

        expect(client.headers, contains('X-Client-Info'));
      });
    });

    group('Multipart requests', () {
      test('multipart with both files and fields', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          body: {'field1': 'value1', 'field2': 'value2'},
          files: [
            MultipartFile.fromString('file1', 'content1'),
            MultipartFile.fromString('file2', 'content2'),
          ],
        );

        final req = customHttpClient.receivedRequests.last;
        expect(req.headers['Content-Type'], contains('multipart/form-data'));
        expect(req, isA<MultipartRequest>());
      });

      test('multipart with only files', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          files: [MultipartFile.fromString('file', 'content')],
        );

        final req = customHttpClient.receivedRequests.last;
        expect(req.headers['Content-Type'], contains('multipart/form-data'));
        expect(req, isA<MultipartRequest>());
      });
    });

    group('Response content types', () {
      test('handles application/octet-stream response', () async {
        final res = await functionsCustomHttpClient.invoke('binary');

        expect(res.data, isA<Uint8List>());
        expect(res.data, equals(Uint8List.fromList([1, 2, 3, 4, 5])));
        expect(res.status, 200);
      });

      test('handles text/plain response', () async {
        final res = await functionsCustomHttpClient.invoke('text');

        expect(res.data, isA<String>());
        expect(res.data, 'Hello World');
        expect(res.status, 200);
      });

      test('handles empty JSON response', () async {
        final res = await functionsCustomHttpClient.invoke('empty-json');

        expect(res.data, '');
        expect(res.status, 200);
      });
    });

    group('Error handling', () {
      test('FunctionException contains all error details', () async {
        try {
          await functionsCustomHttpClient.invoke('error-function');
          fail('should throw');
        } on FunctionException catch (e) {
          expect(e.status, 420);
          expect(e.details, isNotNull);
          expect(e.reasonPhrase, isNotNull);
          expect(e.toString(), contains('420'));
        }
      });
    });

    group('Edge cases', () {
      test('multipart request with invalid body type throws assertion',
          () async {
        expect(
          () => functionsCustomHttpClient.invoke(
            'function',
            body: 42, // Invalid: should be Map<String, String> for multipart
            files: [MultipartFile.fromString('file', 'content')],
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });
  });
}
