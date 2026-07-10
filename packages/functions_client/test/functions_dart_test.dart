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
      functionsCustomHttpClient = FunctionsClient(
        "",
        {},
        httpClient: customHttpClient,
      );
    });
    test('function throws', () async {
      await expectLater(
        functionsCustomHttpClient.invoke('error-function'),
        throwsA(
          isA<FunctionsHttpException>().having((e) => e.status, 'status', 420),
        ),
      );
    });

    test('a non-2xx response throws a FunctionsHttpException', () async {
      await expectLater(
        functionsCustomHttpClient.invoke('error-function'),
        throwsA(
          isA<FunctionsHttpException>()
              .having((e) => e.status, 'status', 420)
              .having(
                (e) => e.reasonPhrase,
                'reasonPhrase',
                'Enhance Your Calm',
              )
              .having((e) => e.details, 'details', {'key': 'Hello World'}),
        ),
      );
    });

    test('a relay error throws a FunctionsRelayException', () async {
      await expectLater(
        functionsCustomHttpClient.invoke('relay-error'),
        throwsA(
          isA<FunctionsRelayException>()
              .having((e) => e.status, 'status', 500)
              .having((e) => e.details, 'details', {'error': 'relay down'}),
        ),
      );
    });

    test('a transport failure throws a FunctionsFetchException', () async {
      await expectLater(
        functionsCustomHttpClient.invoke('network-error'),
        throwsA(
          isA<FunctionsFetchException>()
              .having((e) => e.status, 'status', 0)
              .having((e) => e.details, 'details', isA<ClientException>()),
        ),
      );
    });

    test('the subtypes remain catchable as FunctionException', () async {
      await expectLater(
        functionsCustomHttpClient.invoke('relay-error'),
        throwsA(isA<FunctionException>()),
      );
      await expectLater(
        functionsCustomHttpClient.invoke('network-error'),
        throwsA(isA<FunctionException>()),
      );
    });

    test(
      'error response with a streaming content type exposes the body',
      () async {
        // The error body must be drained and decoded into `details` rather than
        // handed back as an unconsumed stream (which also leaks the connection).
        await expectLater(
          functionsCustomHttpClient.invoke('error-sse'),
          throwsA(
            isA<FunctionException>()
                .having((e) => e.status, 'status', 500)
                .having((e) => e.details, 'details', 'error: boom'),
          ),
        );
      },
    );

    test(
      'error response labeled JSON with a non-JSON body reports the status',
      () async {
        await expectLater(
          functionsCustomHttpClient.invoke('invalid-json-error'),
          throwsA(
            isA<FunctionException>()
                .having((e) => e.status, 'status', 500)
                .having(
                  (e) => e.details,
                  'details',
                  '<html><body>502 Bad Gateway</body></html>',
                ),
          ),
        );
      },
    );

    test(
      'a success response labeled JSON with a non-JSON body still throws',
      () async {
        // On a 2xx the JSON label is a promise of structured data. A body that
        // doesn't parse is a real anomaly, so the FormatException must surface
        // rather than silently degrading to a raw String.
        await expectLater(
          functionsCustomHttpClient.invoke('success-invalid-json'),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'an upper-cased application/JSON content type is parsed as JSON',
      () async {
        final response = await functionsCustomHttpClient.invoke(
          'uppercase-json',
        );
        expect(response.data, {'key': 'Hello World'});
        expect(response.status, 200);
      },
    );

    test('function call', () async {
      final response = await functionsCustomHttpClient.invoke('function');
      expect(
        customHttpClient.receivedRequests.last.headers["Content-Type"],
        null,
      );
      expect(response.data, {'key': 'Hello World'});
      expect(response.status, 200);
    });

    test('function call with query parameters', () async {
      final response = await functionsCustomHttpClient.invoke(
        'function',
        queryParameters: {'key': 'value'},
      );

      final request = customHttpClient.receivedRequests.last;

      expect(request.url.queryParameters, {'key': 'value'});
      expect(response.data, {'key': 'Hello World'});
      expect(response.status, 200);
    });

    test('function call with files', () async {
      final fileName = "file.txt";
      final fileContent = "Hello World";
      final response = await functionsCustomHttpClient.invoke(
        'function',
        queryParameters: {'key': 'value'},
        files: [
          MultipartFile.fromString(fileName, fileContent),
        ],
      );

      final request = customHttpClient.receivedRequests.last;

      expect(request.url.queryParameters, {'key': 'value'});
      expect(request.headers['Content-Type'], contains('multipart/form-data'));
      expect(response.data, [
        {'name': fileName, 'content': fileContent},
      ]);
      expect(response.status, 200);
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
      final response = await client.invoke('function');
      expect(response.data, {'key': 'Hello World'});
    });

    test('Listen to SSE event', () async {
      final response = await functionsCustomHttpClient.invoke('sse');
      expect(
        response.data.transform(const Utf8Decoder()),
        emitsInOrder(
          ['a', 'b', 'c'],
        ),
      );
    });

    group('body encoding', () {
      test('integer properly encoded', () async {
        await functionsCustomHttpClient.invoke('function', body: 42);

        final request = customHttpClient.receivedRequests.last;
        expect(request, isA<Request>());

        request as Request;
        expect(request.body, '42');
        expect(request.headers["Content-Type"], contains("application/json"));
      });

      test('double is properly encoded', () async {
        await functionsCustomHttpClient.invoke('function', body: 42.9);

        final request = customHttpClient.receivedRequests.last;
        expect(request, isA<Request>());

        request as Request;
        expect(request.body, '42.9');
        expect(request.headers["Content-Type"], contains("application/json"));
      });

      test('string is properly encoded', () async {
        await functionsCustomHttpClient.invoke('function', body: 'ExampleText');

        final request = customHttpClient.receivedRequests.last;
        expect(request, isA<Request>());

        request as Request;
        expect(request.body, 'ExampleText');
        expect(request.headers["Content-Type"], contains("text/plain"));
      });

      test('list is properly encoded', () async {
        await functionsCustomHttpClient.invoke('function', body: [1, 2, 3]);

        final request = customHttpClient.receivedRequests.last;
        expect(request, isA<Request>());

        request as Request;
        expect(request.body, '[1,2,3]');
        expect(request.headers["Content-Type"], contains("application/json"));
      });

      test('map is properly encoded', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          body: {'thekey': 'thevalue'},
        );

        final request = customHttpClient.receivedRequests.last;
        expect(request, isA<Request>());

        request as Request;
        expect(request.body, '{"thekey":"thevalue"}');
        expect(request.headers["Content-Type"], contains("application/json"));
      });

      test('Uint8List is properly encoded as binary data', () async {
        final binaryData = Uint8List.fromList([1, 2, 3, 4, 5]);
        await functionsCustomHttpClient.invoke('function', body: binaryData);

        final request = customHttpClient.receivedRequests.last;
        expect(request, isA<Request>());

        request as Request;
        expect(request.bodyBytes, equals(binaryData));
        expect(
          request.headers["Content-Type"],
          equals("application/octet-stream"),
        );
      });

      test('null body sends no content-type', () async {
        await functionsCustomHttpClient.invoke('function');

        final request = customHttpClient.receivedRequests.last;
        expect(request, isA<Request>());

        request as Request;
        expect(request.body, '');
        expect(request.headers.containsKey("Content-Type"), isFalse);
      });
    });

    group('HTTP methods', () {
      test('GET method', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          method: HttpMethod.get,
        );

        final request = customHttpClient.receivedRequests.last;
        expect(request.method, 'GET');
      });

      test('PUT method', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          method: HttpMethod.put,
        );

        final request = customHttpClient.receivedRequests.last;
        expect(request.method, 'PUT');
      });

      test('DELETE method', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          method: HttpMethod.delete,
        );

        final request = customHttpClient.receivedRequests.last;
        expect(request.method, 'DELETE');
      });

      test('PATCH method', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          method: HttpMethod.patch,
        );

        final request = customHttpClient.receivedRequests.last;
        expect(request.method, 'PATCH');
      });
    });

    group('Headers', () {
      test('setAuth updates authorization header', () async {
        functionsCustomHttpClient.setAuth('new-token');

        await functionsCustomHttpClient.invoke('function');

        final request = customHttpClient.receivedRequests.last;
        expect(request.headers['Authorization'], 'Bearer new-token');
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

        final request = customHttpClient.receivedRequests.last;
        expect(request.headers['Content-Type'], 'custom/type');
      });

      test('custom lowercase content-type header overrides defaults', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          body: {'key': 'value'},
          headers: {'content-type': 'application/custom+json'},
        );

        final request = customHttpClient.receivedRequests.last;
        expect(request.headers['content-type'], 'application/custom+json');
      });

      test('custom headers merge with defaults', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          headers: {'X-Custom': 'value'},
        );

        final request = customHttpClient.receivedRequests.last;
        expect(request.headers['X-Custom'], 'value');
        expect(request.headers, contains('X-Client-Info'));
      });
    });

    group('Region support', () {
      test(
        'region parameter adds x-region header and forceFunctionRegion query param',
        () async {
          await functionsCustomHttpClient.invoke(
            'function',
            region: 'us-west-1',
          );

          final request = customHttpClient.receivedRequests.last;
          expect(request.headers['x-region'], 'us-west-1');
          expect(
            request.url.queryParameters['forceFunctionRegion'],
            'us-west-1',
          );
        },
      );

      test('region "any" does not add header or query param', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          region: 'any',
        );

        final request = customHttpClient.receivedRequests.last;
        expect(request.headers.containsKey('x-region'), isFalse);
        expect(
          request.url.queryParameters.containsKey('forceFunctionRegion'),
          isFalse,
        );
      });

      test(
        'client region is used when invoke region is not specified',
        () async {
          final client = FunctionsClient(
            "",
            {},
            httpClient: customHttpClient,
            region: 'eu-west-1',
          );

          await client.invoke('function');

          final request = customHttpClient.receivedRequests.last;
          expect(request.headers['x-region'], 'eu-west-1');
          expect(
            request.url.queryParameters['forceFunctionRegion'],
            'eu-west-1',
          );
        },
      );

      test('invoke region overrides client region', () async {
        final client = FunctionsClient(
          "",
          {},
          httpClient: customHttpClient,
          region: 'eu-west-1',
        );

        await client.invoke('function', region: 'us-east-1');

        final request = customHttpClient.receivedRequests.last;
        expect(request.headers['x-region'], 'us-east-1');
        expect(request.url.queryParameters['forceFunctionRegion'], 'us-east-1');
      });

      test('region works with other query parameters', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          region: 'ap-south-1',
          queryParameters: {'key': 'value', 'foo': 'bar'},
        );

        final request = customHttpClient.receivedRequests.last;
        expect(request.headers['x-region'], 'ap-south-1');
        expect(request.url.queryParameters, {
          'key': 'value',
          'foo': 'bar',
          'forceFunctionRegion': 'ap-south-1',
        });
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

        final request = customHttpClient.receivedRequests.last;
        expect(
          request.headers['Content-Type'],
          contains('multipart/form-data'),
        );
        expect(request, isA<MultipartRequest>());
      });

      test('multipart with only files', () async {
        await functionsCustomHttpClient.invoke(
          'function',
          files: [MultipartFile.fromString('file', 'content')],
        );

        final request = customHttpClient.receivedRequests.last;
        expect(
          request.headers['Content-Type'],
          contains('multipart/form-data'),
        );
        expect(request, isA<MultipartRequest>());
      });
    });

    group('Response content types', () {
      test('handles application/octet-stream response', () async {
        final response = await functionsCustomHttpClient.invoke('binary');

        expect(response.data, isA<Uint8List>());
        expect(response.data, equals(Uint8List.fromList([1, 2, 3, 4, 5])));
        expect(response.status, 200);
      });

      test('handles text/plain response', () async {
        final response = await functionsCustomHttpClient.invoke('text');

        expect(response.data, isA<String>());
        expect(response.data, 'Hello World');
        expect(response.status, 200);
      });

      test('handles empty JSON response', () async {
        final response = await functionsCustomHttpClient.invoke('empty-json');

        expect(response.data, '');
        expect(response.status, 200);
      });
    });

    group('Error handling', () {
      test('FunctionException contains all error details', () async {
        await expectLater(
          functionsCustomHttpClient.invoke('error-function'),
          throwsA(
            isA<FunctionException>()
                .having((e) => e.status, 'status', 420)
                .having((e) => e.details, 'details', isNotNull)
                .having((e) => e.reasonPhrase, 'reasonPhrase', isNotNull)
                .having((e) => e.toString(), 'toString()', contains('420')),
          ),
        );
      });
    });

    group('Edge cases', () {
      test(
        'multipart request with invalid body type throws assertion',
        () async {
          expect(
            () => functionsCustomHttpClient.invoke(
              'function',
              body: 42, // Invalid: should be Map<String, String> for multipart
              files: [MultipartFile.fromString('file', 'content')],
            ),
            throwsA(isA<AssertionError>()),
          );
        },
      );
    });
  });
}
