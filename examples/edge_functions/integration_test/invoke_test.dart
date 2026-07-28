import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// End-to-end suite covering the full surface of `functions.invoke` against the
/// local stack.
///
/// It drives the `echo` test-support function, which reflects the request back
/// as JSON (or returns text, binary, an SSE stream or a chosen status code,
/// depending on its query parameters). Between them the tests exercise every
/// request option (method, query, headers, JSON / text / binary / multipart
/// bodies, region), every response type, custom status codes, the three
/// `FunctionException` variants and request aborting.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FunctionsClient functions;

  setUpAll(() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    functions = Supabase.instance.client.functions;
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  group('request', () {
    testWidgets('POST sends a JSON body that comes back decoded', (_) async {
      final response = await functions.invoke('echo', body: {'hello': 'world'});
      expect(response.status, 200);
      expect(response.data['method'], 'POST');
      expect(response.data['body'], {'hello': 'world'});
    });

    testWidgets('GET sends query parameters instead of a body', (_) async {
      final response = await functions.invoke(
        'echo',
        method: HttpMethod.get,
        queryParameters: {'a': '1', 'b': '2'},
      );
      expect(response.data['method'], 'GET');
      expect(response.data['query'], containsPair('a', '1'));
      expect(response.data['query'], containsPair('b', '2'));
    });

    testWidgets('every HTTP method reaches the function', (_) async {
      for (final method in HttpMethod.values) {
        final response = await functions.invoke(
          'echo',
          method: method,
          // GET and DELETE carry no body.
          body: method == HttpMethod.get || method == HttpMethod.delete
              ? null
              : {'value': 1},
        );
        expect(response.data['method'], method.name.toUpperCase());
      }
    });

    testWidgets('custom headers reach the function', (_) async {
      final response = await functions.invoke(
        'echo',
        headers: const {'x-custom-header': 'from-test'},
      );
      expect(response.data['header'], 'from-test');
    });

    testWidgets('a String body is sent as text/plain', (_) async {
      final response = await functions.invoke('echo', body: 'plain text body');
      expect(response.data['body'], 'plain text body');
    });

    testWidgets('a Uint8List body is sent as binary', (_) async {
      final response = await functions.invoke(
        'echo',
        body: Uint8List.fromList([1, 2, 3, 4]),
      );
      // The function reports how many bytes it received.
      expect(response.data['body'], 4);
    });

    testWidgets('files are sent as a multipart request', (_) async {
      final response = await functions.invoke(
        'echo',
        body: {'caption': 'hello'},
        files: [
          MultipartFile.fromString(
            'upload',
            'file contents',
            filename: 'a.txt',
          ),
        ],
      );
      expect(response.data['fields'], containsPair('caption', 'hello'));
      expect(response.data['files'], [
        {'name': 'a.txt', 'size': 'file contents'.length},
      ]);
    });

    testWidgets('a region adds the forceFunctionRegion query and x-region '
        'header', (_) async {
      final response = await functions.invoke('echo', region: 'us-east-1');
      expect(
        response.data['query'],
        containsPair('forceFunctionRegion', 'us-east-1'),
      );
      expect(response.data['region'], 'us-east-1');
    });
  });

  group('response', () {
    testWidgets('a JSON response decodes to a Map', (_) async {
      final response = await functions.invoke('echo');
      expect(response.data, isA<Map<String, dynamic>>());
    });

    testWidgets('a text/plain response is a String', (_) async {
      final response = await functions.invoke(
        'echo',
        queryParameters: {'format': 'text'},
      );
      expect(response.data, isA<String>());
      expect(response.data, 'echo');
    });

    testWidgets('an octet-stream response is a Uint8List', (_) async {
      final response = await functions.invoke(
        'echo',
        queryParameters: {'format': 'binary'},
      );
      expect(response.data, isA<Uint8List>());
      expect(response.data, [1, 2, 3, 4, 5]);
    });

    testWidgets('an event-stream response is a readable ByteStream', (_) async {
      final response = await functions.invoke(
        'echo',
        queryParameters: {'format': 'sse'},
      );
      expect(response.data, isA<ByteStream>());
      final body = await (response.data as ByteStream)
          .transform(const Utf8Decoder())
          .join();
      expect(body, contains('data: tick 1'));
      expect(body, contains('data: tick 3'));
    });

    testWidgets('the response exposes a non-200 success status', (_) async {
      final response = await functions.invoke(
        'echo',
        queryParameters: {'status': '201'},
      );
      expect(response.status, 201);
    });
  });

  group('errors', () {
    testWidgets('a non-2xx JSON response throws with a Map in details', (
      _,
    ) async {
      await expectLater(
        functions.invoke('echo', queryParameters: {'status': '422'}),
        throwsA(
          isA<FunctionsHttpException>()
              .having((error) => error.status, 'status', 422)
              .having(
                (error) => (error.details as Map)['error'],
                'details.error',
                'boom',
              ),
        ),
      );
    });

    testWidgets('a non-2xx text response throws with a String in details', (
      _,
    ) async {
      await expectLater(
        functions.invoke(
          'echo',
          queryParameters: {'status': '500', 'format': 'text'},
        ),
        throwsA(
          isA<FunctionsHttpException>()
              .having((error) => error.status, 'status', 500)
              .having((error) => error.details, 'details', 'boom'),
        ),
      );
    });

    testWidgets('an unreachable function throws a FunctionsFetchException', (
      _,
    ) async {
      // A client pointed at a closed port can never connect, so the request
      // fails before any response, surfacing as a fetch exception with status 0.
      final unreachable = FunctionsClient(
        'http://127.0.0.1:1/functions/v1',
        const {'apikey': supabasePublishableKey},
      );
      addTearDown(unreachable.dispose);
      await expectLater(
        unreachable.invoke('echo'),
        throwsA(
          isA<FunctionsFetchException>().having(
            (error) => error.status,
            'status',
            0,
          ),
        ),
      );
    });
  });

  group('abort', () {
    testWidgets('an already-completed abort signal cancels the request', (
      _,
    ) async {
      final signal = Completer<void>()..complete();
      await expectLater(
        functions.invoke(
          'echo',
          queryParameters: {'delay': '2000'},
          abortSignal: signal.future,
        ),
        throwsA(isA<RequestAbortedException>()),
      );
    });

    testWidgets('an abort signal acts as a request timeout', (_) async {
      await expectLater(
        functions.invoke(
          'echo',
          queryParameters: {'delay': '3000'},
          abortSignal: Future.delayed(const Duration(milliseconds: 300)),
        ),
        throwsA(isA<RequestAbortedException>()),
      );
    });
  });
}
