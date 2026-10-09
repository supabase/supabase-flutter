import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

/// Answers every request with [respond], after reading the request body the
/// way a real client does.
class _FakeClient extends BaseClient {
  _FakeClient(this.respond, {this.honorAbort = true, this.sendTime});

  final Future<StreamedResponse> Function(BaseRequest request, List<int> body)
  respond;

  /// Whether an abort trigger fails the request, as the clients of
  /// `package:http` do.
  final bool honorAbort;

  /// How long putting a chunk of the request body on the wire takes, `null`
  /// to read the body at once.
  final Duration Function(List<int> chunk)? sendTime;

  bool aborted = false;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final abortTrigger = request is Abortable ? request.abortTrigger : null;
    final abortCompleter = Completer<StreamedResponse>();
    unawaited(
      abortTrigger?.then((_) {
        aborted = true;
        if (honorAbort && !abortCompleter.isCompleted) {
          abortCompleter.completeError(
            RequestAbortedException(request.url),
            StackTrace.current,
          );
        }
      }),
    );
    final body = <int>[];
    await for (final chunk in request.finalize()) {
      final sendTime = this.sendTime;
      if (sendTime != null) await Future<void>.delayed(sendTime(chunk));
      body.addAll(chunk);
    }
    return Future.any([respond(request, body), abortCompleter.future]);
  }
}

final _url = Uri.parse('http://localhost/resource');

Stream<List<int>> _chunks(int count, Duration interval) async* {
  for (var index = 0; index < count; index++) {
    await Future<void>.delayed(interval);
    yield utf8.encode('$index');
  }
}

Future<StreamedResponse> _never() => Completer<StreamedResponse>().future;

void main() {
  group('IdleTimeout', () {
    test('applies no timeout without a duration', () async {
      final idleTimeout = IdleTimeout(null);
      final client = _FakeClient((request, _) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return StreamedResponse(Stream.value(utf8.encode('ok')), 200);
      });

      final response = await idleTimeout.send(
        AbortableRequest(
          'GET',
          _url,
          abortTrigger: idleTimeout.abortTrigger(null),
        ),
        client,
      );

      expect(await response.stream.bytesToString(), 'ok');
      expect(idleTimeout.abortTrigger(null), isNull);
    });

    test('throws a TimeoutException and aborts a stalled request', () async {
      final idleTimeout = IdleTimeout(const Duration(milliseconds: 50));
      final client = _FakeClient((_, _) => _never());

      await expectLater(
        idleTimeout.send(
          AbortableRequest(
            'GET',
            _url,
            abortTrigger: idleTimeout.abortTrigger(null),
          ),
          client,
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(client.aborted, isTrue);
      expect(idleTimeout.expired, isTrue);
    });

    test('times out a client that ignores the abort trigger', () async {
      final idleTimeout = IdleTimeout(const Duration(milliseconds: 50));
      final client = _FakeClient((_, _) => _never(), honorAbort: false);

      await expectLater(
        idleTimeout.send(Request('GET', _url), client),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('lets a caller abort keep its own exception', () async {
      final idleTimeout = IdleTimeout(const Duration(seconds: 5));
      final client = _FakeClient((_, _) => _never());

      await expectLater(
        idleTimeout.send(
          AbortableRequest(
            'GET',
            _url,
            abortTrigger: idleTimeout.abortTrigger(
              Future.delayed(const Duration(milliseconds: 20)),
            ),
          ),
          client,
        ),
        throwsA(isA<RequestAbortedException>()),
      );
      expect(idleTimeout.expired, isFalse);
    });

    test('does not cut short a response body that keeps arriving', () async {
      final idleTimeout = IdleTimeout(const Duration(milliseconds: 100));
      final client = _FakeClient(
        (_, _) async => StreamedResponse(
          _chunks(8, const Duration(milliseconds: 40)),
          200,
        ),
      );

      final response = await idleTimeout.send(
        AbortableRequest(
          'GET',
          _url,
          abortTrigger: idleTimeout.abortTrigger(null),
        ),
        client,
      );

      expect(await response.stream.bytesToString(), '01234567');
    });

    test('fails a response body that stops arriving', () async {
      final idleTimeout = IdleTimeout(const Duration(milliseconds: 50));
      final body = StreamController<List<int>>();
      final client = _FakeClient(
        (_, _) async => StreamedResponse(body.stream, 200),
      );

      final response = await idleTimeout.send(
        AbortableRequest(
          'GET',
          _url,
          abortTrigger: idleTimeout.abortTrigger(null),
        ),
        client,
      );
      body.add(utf8.encode('partial'));

      await expectLater(
        response.stream.bytesToString(),
        throwsA(isA<TimeoutException>()),
      );
      await body.close();
    });

    test('does not cut short a request body that keeps being sent', () async {
      final idleTimeout = IdleTimeout(const Duration(milliseconds: 100));
      final client = _FakeClient(
        (_, body) async => StreamedResponse(Stream.value(body), 200),
      );
      final request = StreamedRequest('POST', _url);
      unawaited(
        idleTimeout
            .watchRequestBody(_chunks(8, const Duration(milliseconds: 40)))
            .pipe(request.sink),
      );

      final response = await idleTimeout.send(request, client);

      expect(await response.stream.bytesToString(), '01234567');
    });

    test('does not cut short a large body sent as one chunk', () async {
      final idleTimeout = IdleTimeout(const Duration(milliseconds: 100));
      final client = _FakeClient(
        (_, body) async => StreamedResponse(Stream.value(body), 200),
        sendTime: (chunk) => Duration(milliseconds: chunk.length ~/ 2048),
      );
      final request = idleTimeout.request('POST', _url)
        ..bodyBytes = Uint8List(512 * 1024);

      final response = await idleTimeout.send(request, client);

      expect(await response.stream.toBytes(), hasLength(512 * 1024));
      expect(idleTimeout.expired, isFalse);
    });

    test('stops the timer when the request fails', () async {
      final idleTimeout = IdleTimeout(const Duration(milliseconds: 30));
      final client = _FakeClient(
        (_, _) => Future.error(ClientException('Connection refused', _url)),
      );

      await expectLater(
        idleTimeout.send(idleTimeout.request('GET', _url), client),
        throwsA(isA<ClientException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(idleTimeout.expired, isFalse);
    });

    test('cancels a response body nobody listened to', () async {
      final idleTimeout = IdleTimeout(const Duration(milliseconds: 50));
      final cancelled = Completer<void>();
      final body = StreamController<List<int>>(onCancel: cancelled.complete);
      final client = _FakeClient(
        (_, _) async => StreamedResponse(body.stream, 200),
      );

      await idleTimeout.send(idleTimeout.request('GET', _url), client);

      await expectLater(
        cancelled.future.timeout(const Duration(seconds: 1)),
        completes,
      );
    });

    test('pauses while the consumer of the body pauses', () async {
      final idleTimeout = IdleTimeout(const Duration(milliseconds: 50));
      final client = _FakeClient(
        (_, _) async => StreamedResponse(
          _chunks(2, const Duration(milliseconds: 10)),
          200,
        ),
      );
      final response = await idleTimeout.send(
        AbortableRequest(
          'GET',
          _url,
          abortTrigger: idleTimeout.abortTrigger(null),
        ),
        client,
      );

      final received = <String>[];
      final done = Completer<void>();
      final subscription = response.stream.listen(
        (chunk) => received.add(utf8.decode(chunk)),
        onError: done.completeError,
        onDone: done.complete,
      );
      subscription.pause();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      subscription.resume();
      await done.future;

      expect(received, ['0', '1']);
      expect(idleTimeout.expired, isFalse);
    });

    test('stops once the response body is done', () async {
      final idleTimeout = IdleTimeout(const Duration(milliseconds: 30));
      final client = _FakeClient(
        (_, _) async => StreamedResponse(Stream.value(utf8.encode('ok')), 200),
      );

      final response = await idleTimeout.send(
        AbortableRequest(
          'GET',
          _url,
          abortTrigger: idleTimeout.abortTrigger(null),
        ),
        client,
      );
      await response.stream.drain<void>();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(idleTimeout.expired, isFalse);
    });
  });
}
