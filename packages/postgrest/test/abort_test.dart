import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

StreamedResponse _ok(BaseRequest request) => StreamedResponse(
  Stream.value(Uint8List.fromList('[]'.codeUnits)),
  200,
  request: request,
  headers: {'content-type': 'application/json'},
);

/// Mimics a client that supports [Abortable]: a request stays pending until
/// either [release] is called (success) or its `abortTrigger` completes.
class _AbortMockClient extends BaseClient {
  final List<BaseRequest> requests = [];
  final _gate = Completer<void>();

  int get callCount => requests.length;

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    requests.add(request);
    final completer = Completer<StreamedResponse>();
    if (request case Abortable(:final abortTrigger?)) {
      unawaited(
        abortTrigger.whenComplete(() {
          if (!completer.isCompleted) {
            completer.completeError(
              RequestAbortedException(request.url),
              StackTrace.current,
            );
          }
        }),
      );
    }
    unawaited(
      _gate.future.whenComplete(() {
        if (!completer.isCompleted) completer.complete(_ok(request));
      }),
    );
    return completer.future;
  }
}

PostgrestClient _buildClient(_AbortMockClient mock) {
  return PostgrestClient(
    'http://localhost:3000',
    httpClient: mock,
    retryDelay: (_) => Duration.zero,
  );
}

void main() {
  group('abortCompleter', () {
    test('aborts a GET request before it completes', () async {
      final mock = _AbortMockClient();
      final client = _buildClient(mock);
      final abort = Completer<void>()..complete();

      await expectLater(
        () => client.from('users').select().abortCompleter(abort),
        throwsA(isA<RequestAbortedException>()),
      );
    });

    test('aborts an insert (POST) request', () async {
      final mock = _AbortMockClient();
      final client = _buildClient(mock);
      final abort = Completer<void>()..complete();

      await expectLater(
        () =>
            client.from('users').insert({'name': 'foo'}).abortCompleter(abort),
        throwsA(isA<RequestAbortedException>()),
      );
    });

    test('does not retry an aborted retryable request', () async {
      final mock = _AbortMockClient();
      final client = _buildClient(mock);
      final abort = Completer<void>()..complete();

      await expectLater(
        () => client.from('users').select().abortCompleter(abort),
        throwsA(isA<RequestAbortedException>()),
      );
      expect(mock.callCount, 1);
    });

    test('completes normally when the completer never fires', () async {
      final mock = _AbortMockClient();
      final client = _buildClient(mock);
      final abort = Completer<void>();

      final future = client.from('users').select().abortCompleter(abort);
      mock.release();

      expect(await future, isEmpty);
    });

    test('survives further chaining after abortCompleter', () async {
      final mock = _AbortMockClient();
      final client = _buildClient(mock);
      final abort = Completer<void>()..complete();

      await expectLater(
        () => client
            .from('users')
            .select()
            .abortCompleter(abort)
            .eq('name', 'foo'),
        throwsA(isA<RequestAbortedException>()),
      );
    });
  });
}
