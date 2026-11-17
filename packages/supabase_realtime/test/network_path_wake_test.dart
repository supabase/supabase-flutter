import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'socket_test_stubs.dart';

/// A server whose connection attempts fail until [accept] is set, recording
/// when each attempt started.
class _Server {
  _Server(this.async);

  final FakeAsync async;
  final attempts = <Duration>[];
  bool accept = false;
  Completer<void>? pendingReady;

  WebSocketChannel connect(String url, Map<String, String> headers) {
    attempts.add(async.elapsed);
    final channel = MockIOWebSocketChannel();
    final sink = MockWebSocketSink();
    final ready =
        pendingReady?.future ??
        (accept
            ? Future<void>.value()
            : Future<void>.error(Exception('unreachable')));
    when(() => channel.ready).thenAnswer((_) => ready);
    when(
      () => channel.stream,
    ).thenAnswer((_) => StreamController<dynamic>().stream);
    when(() => channel.sink).thenReturn(sink);
    when(() => channel.closeCode).thenReturn(null);
    when(() => channel.closeReason).thenReturn(null);
    when(() => sink.close()).thenAnswer((_) => Future.value());
    when(() => sink.close(any(), any())).thenAnswer((_) => Future.value());
    return channel;
  }
}

void main() {
  late StreamController<bool> reachability;
  late List<int> backoffAttempts;

  setUp(() {
    reachability = StreamController<bool>.broadcast(sync: true);
    backoffAttempts = [];
  });

  RealtimeClient createClient(_Server server, {required Duration backoff}) {
    final client = RealtimeClient(
      'ws://localhost:0',
      transport: server.connect,
      networkReachability: reachability.stream,
      reconnectAfter: (attempt) {
        backoffAttempts.add(attempt);
        return backoff;
      },
    );
    client.onStatusChange.listen(null, onError: (_) {});
    return client;
  }

  void startMonitor(FakeAsync async) {
    reachability.add(true);
    async.flushMicrotasks();
  }

  void finish(FakeAsync async, RealtimeClient client) {
    client.detachNetworkReachability();
    unawaited(client.disconnect());
    async.flushMicrotasks();
  }

  test('reconnects at once when the previous attempt started at least '
      '2 seconds ago, continuing the attempt count', () {
    fakeAsync((async) {
      final server = _Server(async);
      final client = createClient(server, backoff: const Duration(seconds: 30));
      startMonitor(async);
      unawaited(client.connect());
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 5));
      reachability.add(true);
      async.flushMicrotasks();

      expect(server.attempts, [Duration.zero, const Duration(seconds: 5)]);
      expect(backoffAttempts, [1, 2]);
      finish(async, client);
    });
  });

  test('waits until 2 seconds after the previous attempt started when the '
      'report comes sooner, and further reports change nothing', () {
    fakeAsync((async) {
      final server = _Server(async);
      final client = createClient(server, backoff: const Duration(seconds: 30));
      startMonitor(async);
      unawaited(client.connect());
      async.flushMicrotasks();

      async.elapse(const Duration(milliseconds: 500));
      reachability.add(true);
      async.elapse(const Duration(milliseconds: 500));
      reachability.add(true);
      async.elapse(const Duration(milliseconds: 500));
      expect(server.attempts, [Duration.zero]);

      async.elapse(const Duration(milliseconds: 500));
      expect(server.attempts, [Duration.zero, const Duration(seconds: 2)]);
      finish(async, client);
    });
  });

  test('never lengthens a backoff that ends within 2 seconds', () {
    fakeAsync((async) {
      final server = _Server(async);
      final client = createClient(server, backoff: const Duration(seconds: 1));
      startMonitor(async);
      unawaited(client.connect());
      async.flushMicrotasks();

      async.elapse(const Duration(milliseconds: 500));
      reachability.add(true);
      async.elapse(const Duration(milliseconds: 500));

      expect(server.attempts, [Duration.zero, const Duration(seconds: 1)]);
      finish(async, client);
    });
  });

  test('ignores the first report and reports of an unreachable network', () {
    fakeAsync((async) {
      final server = _Server(async);
      final client = createClient(server, backoff: const Duration(seconds: 30));
      unawaited(client.connect());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));

      reachability.add(true);
      reachability.add(false);
      async.flushMicrotasks();
      expect(server.attempts, [Duration.zero]);

      reachability.add(true);
      async.flushMicrotasks();
      expect(server.attempts, hasLength(2));
      finish(async, client);
    });
  });

  test('keeps listening after the monitor reports an error', () {
    fakeAsync((async) {
      final server = _Server(async);
      final client = createClient(server, backoff: const Duration(seconds: 30));
      startMonitor(async);
      unawaited(client.connect());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));

      reachability.addError(Exception('monitor failed'));
      reachability.add(true);
      async.flushMicrotasks();

      expect(server.attempts, hasLength(2));
      finish(async, client);
    });
  });

  test('ignores a report while connected', () {
    fakeAsync((async) {
      final server = _Server(async)..accept = true;
      final client = createClient(server, backoff: Duration.zero);
      startMonitor(async);
      unawaited(client.connect());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));

      reachability.add(true);
      async.flushMicrotasks();

      expect(server.attempts, [Duration.zero]);
      expect(client.isConnected, isTrue);
      finish(async, client);
    });
  });

  test('ignores a report while a connection attempt is in flight', () {
    fakeAsync((async) {
      final server = _Server(async)..pendingReady = Completer<void>();
      final client = createClient(server, backoff: const Duration(seconds: 30));
      startMonitor(async);
      unawaited(client.connect());
      async.elapse(const Duration(seconds: 5));

      reachability.add(true);
      async.flushMicrotasks();

      expect(server.attempts, [Duration.zero]);
      expect(client.connectionState, SocketState.connecting);
      finish(async, client);
    });
  });

  test('ignores a report after an explicit disconnect', () {
    fakeAsync((async) {
      final server = _Server(async);
      final client = createClient(server, backoff: const Duration(seconds: 30));
      startMonitor(async);
      unawaited(client.connect());
      async.flushMicrotasks();
      unawaited(client.disconnect());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));

      reachability.add(true);
      async.elapse(const Duration(minutes: 1));

      expect(server.attempts, [Duration.zero]);
      finish(async, client);
    });
  });

  test('stops listening to the reports when detached', () {
    fakeAsync((async) {
      final client = createClient(
        _Server(async),
        backoff: const Duration(seconds: 30),
      );
      expect(reachability.hasListener, isTrue);

      finish(async, client);

      expect(reachability.hasListener, isFalse);
    });
  });
}
