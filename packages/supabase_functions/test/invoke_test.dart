import 'dart:convert';

import 'package:http/http.dart';
import 'package:supabase_functions/supabase_functions.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  late MockSupabaseHttpClient httpClient;
  late FunctionsClient functions;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    functions = FunctionsClient(
      'http://localhost/functions/v1',
      {},
      httpClient: httpClient,
    );
    addTearDown(functions.dispose);
  });

  group('response headers', () {
    test('are exposed on a successful response', () async {
      httpClient.stub(
        {'ok': true},
        path: '/functions/v1/hello',
        headers: {'x-total-count': '42'},
      );

      final response = await functions.invoke('hello');

      expect(response.headers, containsPair('x-total-count', '42'));
      expect(response.headers['content-type'], contains('application/json'));
    });

    test('are exposed on a streamed response', () async {
      httpClient.stubText(
        'data: hello\n\n',
        path: '/functions/v1/events',
        contentType: 'text/event-stream',
        headers: {'x-stream-id': 'stream-1'},
      );

      final response = await functions.invoke('events');

      expect(response.data, isA<ByteStream>());
      expect(response.headers, containsPair('x-stream-id', 'stream-1'));
      await (response.data as ByteStream).drain<void>();
    });
  });

  group('FunctionsRegion', () {
    test('a custom region is sent as given', () async {
      httpClient.stubEdgeFunction('hello');

      await functions.invoke(
        'hello',
        region: const FunctionsRegion.custom('me-central-1'),
      );

      final request = httpClient.requests.single;
      expect(request.headers['x-region'], 'me-central-1');
      expect(request.queryParameters['forceFunctionRegion'], 'me-central-1');
    });

    test('a custom region equal to a constant is that constant', () {
      expect(
        const FunctionsRegion.custom('eu-west-1'),
        FunctionsRegion.euWest1,
      );
      expect(FunctionsRegion.usEast1.value, 'us-east-1');
    });

    test('values lists every constant once', () {
      expect(FunctionsRegion.values, contains(FunctionsRegion.any));
      expect(FunctionsRegion.values, contains(FunctionsRegion.saEast1));
      expect(
        FunctionsRegion.values.toSet(),
        hasLength(FunctionsRegion.values.length),
      );
    });

    test('any overrides the client region and sends no region', () async {
      httpClient.stubEdgeFunction('hello');
      final client = FunctionsClient(
        'http://localhost/functions/v1',
        {},
        httpClient: httpClient,
        region: FunctionsRegion.euWest1,
      );
      addTearDown(client.dispose);

      await client.invoke('hello', region: FunctionsRegion.any);

      final request = httpClient.requests.single;
      expect(request.headers.containsKey('x-region'), isFalse);
      expect(request.queryParameters, isEmpty);
    });
  });

  group('query parameters', () {
    test('non-string values are sent as strings', () async {
      httpClient.stubEdgeFunction('search');

      await functions.invoke(
        'search',
        queryParameters: {
          'page': 2,
          'ratio': 0.5,
          'active': true,
          'tags': ['a', 1],
          'missing': null,
        },
      );

      final url = httpClient.requests.single.url;
      expect(url.queryParametersAll, {
        'page': ['2'],
        'ratio': ['0.5'],
        'active': ['true'],
        'tags': ['a', '1'],
      });
    });

    test('a map typed Map<String, dynamic> is accepted', () async {
      httpClient.stubEdgeFunction('search');
      final Map<String, dynamic> parameters = {'page': 3};

      await functions.invoke('search', queryParameters: parameters);

      expect(httpClient.requests.single.queryParameters, {'page': '3'});
    });
  });

  group('JSON responses', () {
    for (final contentType in [
      'application/problem+json',
      'application/vnd.api+json; charset=utf-8',
    ]) {
      test('$contentType is decoded', () async {
        httpClient.stubText(
          '{"key":"value"}',
          path: '/functions/v1/hello',
          contentType: contentType,
        );

        final response = await functions.invoke('hello');

        expect(response.data, {'key': 'value'});
      });
    }

    test('an empty JSON body is null', () async {
      httpClient.stubText(
        '',
        path: '/functions/v1/hello',
        contentType: 'application/json',
      );

      final response = await functions.invoke('hello');

      expect(response.data, isNull);
    });

    test('a +json error body is decoded into details', () async {
      httpClient.stubText(
        '{"title":"Not allowed"}',
        path: '/functions/v1/hello',
        statusCode: 403,
        contentType: 'application/problem+json',
      );

      await expectLater(
        functions.invoke('hello'),
        throwsA(
          isA<FunctionsApiException>().having(
            (exception) => exception.details,
            'details',
            {'title': 'Not allowed'},
          ),
        ),
      );
    });
  });

  group('request errors stay FunctionsExceptions', () {
    test('a JSON body that cannot be encoded', () async {
      await expectLater(
        functions.invoke('hello', body: {'value': Object()}),
        throwsA(
          isA<FunctionsFetchException>().having(
            (exception) => exception.cause,
            'cause',
            isA<JsonUnsupportedObjectError>(),
          ),
        ),
      );
      expect(httpClient.requests, isEmpty);
    });

    test('a multipart body that is not a map', () async {
      await expectLater(
        functions.invoke(
          'upload',
          body: ['not', 'a', 'map'],
          files: [MultipartFile.fromString('file', 'content')],
        ),
        throwsA(isA<FunctionsFetchException>()),
      );
      expect(httpClient.requests, isEmpty);
    });

    test('a multipart body with a non-string value', () async {
      await expectLater(
        functions.invoke(
          'upload',
          body: {'count': 1},
          files: [MultipartFile.fromString('file', 'content')],
        ),
        throwsA(isA<FunctionsFetchException>()),
      );
      expect(httpClient.requests, isEmpty);
    });

    test(
      'a multipart body typed Map<String, dynamic> holding strings',
      () async {
        httpClient.stubEdgeFunction('upload');
        final Map<String, dynamic> fields = {'name': 'avatar'};

        await functions.invoke(
          'upload',
          body: fields,
          files: [MultipartFile.fromString('file', 'content')],
        );

        final request = httpClient.requests.single.request as MultipartRequest;
        expect(request.fields, {'name': 'avatar'});
      },
    );
  });

  group('error messages', () {
    test('come from the message and code of a JSON body', () async {
      httpClient.stub(
        {'message': 'Quota exceeded', 'code': 'quota_exceeded'},
        path: '/functions/v1/hello',
        statusCode: 429,
      );

      await expectLater(
        functions.invoke('hello'),
        throwsA(
          isA<FunctionsApiException>()
              .having((e) => e.message, 'message', 'Quota exceeded')
              .having((e) => e.errorCode, 'errorCode', 'quota_exceeded'),
        ),
      );
    });

    test('fall back to the error and error_code of a JSON body', () async {
      httpClient.stub(
        {'error': 'Name is required', 'error_code': 'validation_failed'},
        path: '/functions/v1/hello',
        statusCode: 400,
      );

      await expectLater(
        functions.invoke('hello'),
        throwsA(
          isA<FunctionsApiException>()
              .having((e) => e.message, 'message', 'Name is required')
              .having((e) => e.errorCode, 'errorCode', 'validation_failed'),
        ),
      );
    });

    test('are used for a relay error too', () async {
      httpClient.stub(
        {'message': 'Function not found', 'code': 'NOT_FOUND'},
        path: '/functions/v1/hello',
        statusCode: 404,
        headers: {'x-relay-error': 'true'},
      );

      await expectLater(
        functions.invoke('hello'),
        throwsA(
          isA<FunctionsRelayException>()
              .having((e) => e.message, 'message', 'Function not found')
              .having((e) => e.errorCode, 'errorCode', 'NOT_FOUND'),
        ),
      );
    });

    test('fall back to the reason phrase for a non-JSON body', () async {
      httpClient.stubText(
        'Bad gateway',
        path: '/functions/v1/hello',
        statusCode: 502,
        reasonPhrase: 'Bad Gateway',
      );

      await expectLater(
        functions.invoke('hello'),
        throwsA(
          isA<FunctionsApiException>()
              .having((e) => e.message, 'message', 'Bad Gateway')
              .having((e) => e.errorCode, 'errorCode', isNull),
        ),
      );
    });

    test('fall back to the default without a reason phrase', () async {
      httpClient.stub(
        {'message': 42},
        path: '/functions/v1/hello',
        statusCode: 500,
      );

      await expectLater(
        functions.invoke('hello'),
        throwsA(
          isA<FunctionsApiException>().having(
            (e) => e.message,
            'message',
            'Edge Function returned a non-2xx status code',
          ),
        ),
      );
    });
  });

  group('a standalone client', () {
    test('closes the HTTP client it created in dispose', () async {
      final client = FunctionsClient('http://localhost:1/functions/v1', {});
      await client.dispose();

      await expectLater(
        client.invoke('hello'),
        throwsA(
          isA<FunctionsFetchException>().having(
            (exception) => exception.cause,
            'cause',
            isA<ClientException>().having(
              (error) => error.message,
              'message',
              contains('closed'),
            ),
          ),
        ),
      );
    });
  });
}
