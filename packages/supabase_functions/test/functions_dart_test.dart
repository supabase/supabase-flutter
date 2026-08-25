import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_functions/src/functions_client.dart';
import 'package:supabase_functions/src/types.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:supabase_common/supabase_common.dart';
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
          isA<FunctionsApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            420,
          ),
        ),
      );
    });

    test('a non-2xx response throws a FunctionsApiException', () async {
      await expectLater(
        functionsCustomHttpClient.invoke('error-function'),
        throwsA(
          isA<FunctionsApiException>()
              .having((e) => e.statusCode, 'statusCode', 420)
              .having((e) => e.message, 'message', 'Enhance Your Calm')
              .having((e) => e.details, 'details', {'key': 'Hello World'}),
        ),
      );
    });

    test('a relay error throws a FunctionsRelayException', () async {
      await expectLater(
        functionsCustomHttpClient.invoke('relay-error'),
        throwsA(
          isA<FunctionsRelayException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.details, 'details', {'error': 'relay down'}),
        ),
      );
    });

    test('a transport failure throws a FunctionsFetchException', () async {
      await expectLater(
        functionsCustomHttpClient.invoke('network-error'),
        throwsA(
          allOf(
            isA<FunctionsFetchException>()
                .having(
                  (e) => e.message,
                  'message',
                  'Failed to send a request to the Edge Function',
                )
                .having((e) => e.details, 'details', isA<ClientException>()),
            isNot(isA<SupabaseApiException>()),
          ),
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

    test('exhaustive switch over FunctionException subtypes', () {
      String describeError(FunctionException exception) {
        return switch (exception) {
          FunctionsFetchException(:final message) => 'fetch: $message',
          FunctionsRelayException(:final statusCode) => 'relay: $statusCode',
          FunctionsApiException(:final statusCode) => 'api: $statusCode',
        };
      }

      const fetchError = FunctionsFetchException(message: 'Connection failed');
      const relayError = FunctionsRelayException(statusCode: 500);
      const apiError = FunctionsApiException(statusCode: 400);

      expect(describeError(fetchError), 'fetch: Connection failed');
      expect(describeError(relayError), 'relay: 500');
      expect(describeError(apiError), 'api: 400');
    });

    test(
      'error response with a streaming content type exposes the body',
      () async {
        // The error body must be drained and decoded into `details` rather than
        // handed back as an unconsumed stream (which also leaks the
        // connection).
        await expectLater(
          functionsCustomHttpClient.invoke('error-sse'),
          throwsA(
            isA<FunctionsApiException>()
                .having((e) => e.statusCode, 'statusCode', 500)
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
            isA<FunctionsApiException>()
                .having((e) => e.statusCode, 'statusCode', 500)
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
        expect(response.statusCode, 200);
      },
    );

    test('the logs redact credential headers', () async {
      final messages = <String>[];
      final previousLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord.listen(
        (record) => messages.add(record.message),
      );
      addTearDown(() async {
        await subscription.cancel();
        Logger.root.level = previousLevel;
      });

      final client = FunctionsClient(
        "",
        {
          'Authorization': 'Bearer super-secret-token',
          'apikey': 'the-anon-key',
          'x-region': 'eu-west-2',
        },
        httpClient: CustomHttpClient(),
      );
      await client.invoke('function');

      // No log at all, whether from the constructor or the request, may carry
      // the values.
      expect(messages, isNotEmpty);
      for (final message in messages) {
        expect(message, isNot(contains('super-secret-token')));
        expect(message, isNot(contains('the-anon-key')));
      }

      final initializeLog = messages.singleWhere(
        (message) => message.startsWith('Initialize with headers:'),
      );
      expect(initializeLog, contains('<redacted>'));

      final requestLog = messages.singleWhere(
        (message) => message.startsWith('Request:'),
      );
      expect(requestLog, contains('<redacted>'));
      // Every name, and any header that is not a credential, stays readable.
      expect(requestLog, contains('Authorization'));
      expect(requestLog, contains('apikey'));
      expect(requestLog, contains('eu-west-2'));
    });

    test('function call', () async {
      final response = await functionsCustomHttpClient.invoke('function');
      expect(
        customHttpClient.receivedRequests.last.headers["Content-Type"],
        null,
      );
      expect(response.data, {'key': 'Hello World'});
      expect(response.statusCode, 200);
    });

    test('function call with query parameters', () async {
      final response = await functionsCustomHttpClient.invoke(
        'function',
        queryParameters: {'key': 'value'},
      );

      final request = customHttpClient.receivedRequests.last;

      expect(request.url.queryParameters, {'key': 'value'});
      expect(response.data, {'key': 'Hello World'});
      expect(response.statusCode, 200);
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
      expect(response.statusCode, 200);
    });

    test('dispose the JSON codec it created itself', () async {
      await functionsCustomHttpClient.dispose();
      expect(functionsCustomHttpClient.invoke('function'), throwsStateError);
    });

    test('do not dispose a supplied JSON codec', () async {
      final client = FunctionsClient(
        "",
        {},
        jsonCodec: YAJsonIsolate(),
        httpClient: CustomHttpClient(),
      );

      await client.dispose();
      final response = await client.invoke('function');
      expect(response.data, {'key': 'Hello World'});
    });

    test('encodes and decodes through a supplied JSON codec', () async {
      final jsonCodec = _RecordingJsonCodec();
      final client = FunctionsClient(
        "",
        {},
        jsonCodec: jsonCodec,
        httpClient: CustomHttpClient(),
      );
      addTearDown(client.dispose);

      final response = await client.invoke(
        'function',
        body: {'name': 'Supabase'},
      );

      expect(response.data, {'key': 'Hello World'});
      expect(jsonCodec.encodedValues, [
        {'name': 'Supabase'},
      ]);
      expect(jsonCodec.decodedPayloads, 1);
      expect(jsonCodec.isDisposed, isFalse);
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
        expect(
          request.headers["Content-Type"],
          equals("text/plain; charset=utf-8"),
        );
      });

      test(
        'string body is encoded with the charset the caller asked for',
        () async {
          await functionsCustomHttpClient.invoke(
            'function',
            headers: {'Content-Type': 'text/plain; charset=iso-8859-1'},
            body: 'Ærlig',
          );

          final request = customHttpClient.receivedRequests.last;
          expect(request, isA<Request>());

          request as Request;
          expect(request.bodyBytes, latin1.encode('Ærlig'));
          expect(
            request.headers["Content-Type"],
            equals("text/plain; charset=iso-8859-1"),
          );
        },
      );

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
      test('headers getter returns the constructor headers merged with the '
          'defaults', () {
        final client = FunctionsClient("", {'apikey': 'foo'});

        expect(client.headers['apikey'], 'foo');
        expect(client.headers, contains('X-Client-Info'));
      });

      test('headers cannot be mutated in place', () {
        final client = FunctionsClient("", {'apikey': 'foo'});

        expect(
          () => client.headers['apikey'] = 'bar',
          throwsUnsupportedError,
        );
        expect(client.headers['apikey'], 'foo');
      });

      test('setHeader adds a header to subsequent invocations', () async {
        final httpClient = CustomHttpClient();
        final client = FunctionsClient(
          'http://localhost',
          {'apikey': 'foo'},
          httpClient: httpClient,
        );
        addTearDown(client.dispose);

        expect(
          identical(client.setHeader('x-custom-header', 'value'), client),
          isTrue,
        );
        await client.invoke('function');

        expect(
          httpClient.receivedRequests.last.headers['x-custom-header'],
          'value',
        );
      });

      test('a header passed to invoke wins over setHeader', () async {
        final httpClient = CustomHttpClient();
        final client = FunctionsClient(
          'http://localhost',
          {'apikey': 'foo'},
          httpClient: httpClient,
        );
        addTearDown(client.dispose);

        client.setHeader('x-custom-header', 'value');
        await client.invoke(
          'function',
          headers: {'x-custom-header': 'per-call'},
        );

        expect(
          httpClient.receivedRequests.last.headers['x-custom-header'],
          'per-call',
        );
        expect(client.headers['x-custom-header'], 'value');
      });

      test('accessToken is resolved before every invocation', () async {
        var calls = 0;
        final client = FunctionsClient(
          "",
          {},
          httpClient: customHttpClient,
          accessToken: () async => 'token-${calls++}',
        );

        await client.invoke('function');
        await client.invoke('function');

        expect(
          customHttpClient.receivedRequests
              .map((request) => request.headers['Authorization'])
              .toList(),
          ['Bearer token-0', 'Bearer token-1'],
        );
      });

      test('a header passed to invoke wins over accessToken', () async {
        final client = FunctionsClient(
          "",
          {},
          httpClient: customHttpClient,
          accessToken: () async => 'resolved',
        );

        await client.invoke(
          'function',
          headers: {'Authorization': 'Bearer per-call'},
        );

        expect(
          customHttpClient.receivedRequests.last.headers['Authorization'],
          'Bearer per-call',
        );
      });

      test('accessToken sends nothing when it resolves to null', () async {
        final client = FunctionsClient(
          "",
          {},
          httpClient: customHttpClient,
          accessToken: () async => null,
        );

        await client.invoke('function');

        expect(
          customHttpClient.receivedRequests.last.headers,
          isNot(contains('Authorization')),
        );
      });

      test('accessToken together with an Authorization header asserts', () {
        expect(
          () => FunctionsClient(
            "",
            {'Authorization': 'Bearer static'},
            accessToken: () async => 'resolved',
          ),
          throwsA(isA<AssertionError>()),
        );
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
        'region parameter adds x-region header and forceFunctionRegion query '
        'param',
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
        final httpClient = CustomHttpClient();
        final client = FunctionsClient(
          'https://example.com',
          {'X-Test': 'value'},
          httpClient: httpClient,
          jsonCodec: YAJsonIsolate(),
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

    group('Request cancellation', () {
      test('aborts an in-flight request via abortSignal', () async {
        final abortSignal = Completer<void>();
        Timer(const Duration(milliseconds: 50), abortSignal.complete);

        await expectLater(
          functionsCustomHttpClient.invoke(
            'slow',
            abortSignal: abortSignal.future,
          ),
          throwsA(isA<RequestAbortedException>()),
        );
      });

      test('aborts a multipart request via abortSignal', () async {
        final abortSignal = Completer<void>();
        Timer(const Duration(milliseconds: 50), abortSignal.complete);

        await expectLater(
          functionsCustomHttpClient.invoke(
            'slow',
            files: [MultipartFile.fromString('file', 'content')],
            abortSignal: abortSignal.future,
          ),
          throwsA(isA<RequestAbortedException>()),
        );
      });

      test('completes normally when the signal never fires', () async {
        final abortSignal = Completer<void>();

        final response = await functionsCustomHttpClient.invoke(
          'function',
          abortSignal: abortSignal.future,
        );

        expect(response.statusCode, 200);
        expect(response.data, {'key': 'Hello World'});
      });
    });

    group('Response content types', () {
      test('handles application/octet-stream response', () async {
        final response = await functionsCustomHttpClient.invoke('binary');

        expect(response.data, isA<Uint8List>());
        expect(response.data, equals(Uint8List.fromList([1, 2, 3, 4, 5])));
        expect(response.statusCode, 200);
      });

      test('handles text/plain response', () async {
        final response = await functionsCustomHttpClient.invoke('text');

        expect(response.data, isA<String>());
        expect(response.data, 'Hello World');
        expect(response.statusCode, 200);
      });

      test('handles empty JSON response', () async {
        final response = await functionsCustomHttpClient.invoke('empty-json');

        expect(response.data, '');
        expect(response.statusCode, 200);
      });
    });

    group('Error handling', () {
      test('FunctionException contains all error details', () async {
        await expectLater(
          functionsCustomHttpClient.invoke('error-function'),
          throwsA(
            isA<FunctionsApiException>()
                .having((e) => e.statusCode, 'statusCode', 420)
                .having((e) => e.details, 'details', isNotNull)
                .having((e) => e.message, 'message', 'Enhance Your Calm')
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

/// An [AsyncJsonCodec] that works inline and records what it was asked to
/// process, so a test can assert that the client routes its JSON through the
/// codec it was given and leaves its disposal to the caller.
class _RecordingJsonCodec implements AsyncJsonCodec {
  final List<Object?> encodedValues = [];
  int decodedPayloads = 0;
  bool isDisposed = false;

  @override
  Future<dynamic> decode(String json) async {
    decodedPayloads++;
    return jsonDecode(json);
  }

  @override
  Future<dynamic> decodeBytes(Uint8List encodedJson) async {
    decodedPayloads++;
    return jsonDecode(utf8.decode(encodedJson));
  }

  @override
  Future<String> encode(Object? json) async {
    encodedValues.add(json);
    return jsonEncode(json);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }
}
