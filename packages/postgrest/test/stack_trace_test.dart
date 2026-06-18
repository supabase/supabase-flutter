import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

_ResponseFactory _errorStatus(int code) =>
    (req) => Future.value(StreamedResponse(
          Stream.value(
              Uint8List.fromList('{"message":"err","code":"$code"}'.codeUnits)),
          code,
          request: req,
          headers: {'content-type': 'application/json'},
        ));

typedef _ResponseFactory = Future<StreamedResponse> Function(BaseRequest);

class _MockClient extends BaseClient {
  final _ResponseFactory _response;
  _MockClient(this._response);

  @override
  Future<StreamedResponse> send(BaseRequest request) => _response(request);
}

PostgrestClient _buildClient(_MockClient mock) =>
    PostgrestClient('http://localhost:3000', httpClient: mock);

void main() {
  group('stack trace', () {
    test('includes caller frame when PostgrestException is thrown', () async {
      final client = _buildClient(_MockClient(_errorStatus(400)));

      StackTrace? capturedTrace;

      Future<void> theCallerFunction() async {
        try {
          await client.from('users').select();
        } catch (_, trace) {
          capturedTrace = trace;
          rethrow;
        }
      }

      await expectLater(
        theCallerFunction(),
        throwsA(isA<PostgrestException>()),
      );

      expect(
        capturedTrace.toString(),
        contains('theCallerFunction'),
        reason: 'Stack trace should include the caller frame',
      );
    });

    test('includes caller frame when using .then() with onError', () async {
      final client = _buildClient(_MockClient(_errorStatus(400)));

      StackTrace? capturedTrace;

      Future<void> anotherCallerFunction() async {
        await client.from('users').select().then(
          (_) {},
          onError: (Object error, StackTrace trace) {
            capturedTrace = trace;
            throw error;
          },
        );
      }

      await expectLater(
        anotherCallerFunction(),
        throwsA(isA<PostgrestException>()),
      );

      expect(
        capturedTrace.toString(),
        contains('anotherCallerFunction'),
        reason: 'Stack trace passed to onError should include the caller frame',
      );
    });

    test('includes caller frame when using single-arg onError that re-throws',
        () async {
      final client = _buildClient(_MockClient(_errorStatus(400)));

      StackTrace? capturedTrace;

      Future<void> singleArgCallerFunction() async {
        try {
          await client.from('users').select().then(
                (_) {},
                onError: (Object error) => throw error,
              );
        } catch (_, trace) {
          capturedTrace = trace;
          rethrow;
        }
      }

      await expectLater(
        singleArgCallerFunction(),
        throwsA(isA<PostgrestException>()),
      );

      expect(
        capturedTrace.toString(),
        contains('singleArgCallerFunction'),
        reason:
            'Outer catch should include the caller frame even with a single-arg onError',
      );
    });

    test('includes caller frame for non-PostgrestException errors', () async {
      final client = PostgrestClient(
        'http://localhost:3000',
        httpClient:
            _MockClient((_) async => throw const SocketException('refused')),
        retryEnabled: false,
      );

      StackTrace? capturedTrace;

      Future<void> networkErrorFunction() async {
        try {
          await client.from('users').select();
        } catch (_, trace) {
          capturedTrace = trace;
          rethrow;
        }
      }

      await expectLater(
        networkErrorFunction(),
        throwsA(isA<SocketException>()),
      );

      expect(
        capturedTrace.toString(),
        contains('networkErrorFunction'),
        reason:
            'Stack trace should include the caller frame for network errors',
      );
    });

    test('includes caller frame when error passes through whenComplete',
        () async {
      final client = _buildClient(_MockClient(_errorStatus(400)));

      StackTrace? capturedTrace;
      var actionCalled = false;

      Future<void> whenCompleteFunction() async {
        try {
          await client
              .from('users')
              .select()
              .whenComplete(() => actionCalled = true);
        } catch (_, trace) {
          capturedTrace = trace;
          rethrow;
        }
      }

      await expectLater(
        whenCompleteFunction(),
        throwsA(isA<PostgrestException>()),
      );

      expect(actionCalled, isTrue);
      expect(
        capturedTrace.toString(),
        contains('whenCompleteFunction'),
        reason:
            'Stack trace should include the caller frame after whenComplete',
      );
    });
  });
}
