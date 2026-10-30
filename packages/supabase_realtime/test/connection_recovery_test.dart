import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'socket_test_stubs.dart';

/// A server that answers nothing on its own, so a test decides every reply.
class _Server {
  final connections = <StreamController<dynamic>>[];
  final sent = <List<dynamic>>[];

  WebSocketChannel connect(String url, Map<String, String> headers) {
    final incoming = StreamController<dynamic>();
    connections.add(incoming);
    final channel = MockIOWebSocketChannel();
    final sink = MockWebSocketSink();
    when(() => channel.ready).thenAnswer((_) => Future.value());
    when(() => channel.stream).thenAnswer((_) => incoming.stream);
    when(() => channel.sink).thenReturn(sink);
    when(() => channel.closeCode).thenReturn(null);
    when(() => channel.closeReason).thenReturn(null);
    when(() => sink.add(any())).thenAnswer((invocation) {
      sent.add(jsonDecode(invocation.positionalArguments.first as String));
    });
    when(() => sink.close()).thenAnswer((_) => Future.value());
    when(() => sink.close(any(), any())).thenAnswer((_) => Future.value());
    return channel;
  }

  Iterable<List<dynamic>> sentEvents(String event) =>
      sent.where((frame) => frame[3] == event);

  void reply(List<dynamic> request, String status, [Object? response]) {
    connections.last.add(
      jsonEncode([
        request[0],
        request[1],
        request[2],
        'phx_reply',
        {'status': status, 'response': response ?? <String, dynamic>{}},
      ]),
    );
  }
}

void main() {
  late _Server server;

  setUp(() => server = _Server());

  RealtimeClient createClient({TimerCalculation? reconnectAfter}) {
    return RealtimeClient(
      'ws://localhost:0',
      transport: server.connect,
      reconnectAfter: reconnectAfter,
    );
  }

  group('rejoin', () {
    test('waits 1, 2, 5 and 10 seconds after failed joins', () {
      fakeAsync((async) {
        final client = createClient();
        client.channel('room').subscribe();
        async.flushMicrotasks();

        final delays = <int>[];
        for (var join = 1; join <= 5; join++) {
          final joins = server.sentEvents('phx_join').toList();
          expect(joins, hasLength(join));
          server.reply(joins.last, 'error', {'reason': 'Unauthorized'});
          async.flushMicrotasks();
          final start = async.elapsed.inSeconds;
          while (server.sentEvents('phx_join').length == join) {
            async.elapse(const Duration(seconds: 1));
          }
          delays.add(async.elapsed.inSeconds - start);
        }

        expect(delays, [1, 2, 5, 10, 10]);
        unawaited(client.disconnect());
        async.flushMicrotasks();
      });
    });

    test('waits 30 seconds after a rate limit join error', () {
      fakeAsync((async) {
        final client = createClient();
        client.channel('room').subscribe();
        async.flushMicrotasks();

        server.reply(server.sentEvents('phx_join').single, 'error', {
          'reason': 'ClientJoinRateLimitReached: Too many joins per second',
        });
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 29));
        expect(server.sentEvents('phx_join'), hasLength(1));
        async.elapse(const Duration(seconds: 1));
        expect(server.sentEvents('phx_join'), hasLength(2));

        unawaited(client.disconnect());
        async.flushMicrotasks();
      });
    });

    test(
      'restarts at attempt 1 and rejoins at once after a reconnect',
      () async {
        final client = createClient(reconnectAfter: (_) => Duration.zero);
        addTearDown(client.disconnect);
        final channel = client.channel('room').subscribe();
        await pumpEventQueue();

        server.reply(server.sentEvents('phx_join').last, 'error');
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        server.reply(server.sentEvents('phx_join').last, 'error');
        await pumpEventQueue();
        expect(server.sentEvents('phx_join'), hasLength(2));

        await server.connections.last.close();
        await pumpEventQueue();
        expect(server.connections, hasLength(2));
        expect(channel.isJoining, isTrue);
        expect(server.sentEvents('phx_join'), hasLength(3));

        server.reply(server.sentEvents('phx_join').last, 'error');
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        expect(server.sentEvents('phx_join'), hasLength(4));
      },
    );
  });

  group('a missing heartbeat reply', () {
    test('errors the channels, closes the socket and reconnects as attempt '
        '1', () {
      fakeAsync((async) {
        final attempts = <int>[];
        final client = createClient(
          reconnectAfter: (attempt) {
            attempts.add(attempt);
            return const Duration(seconds: 1);
          },
        );
        final channel = client.channel('room').subscribe();
        async.flushMicrotasks();
        server.reply(server.sentEvents('phx_join').single, 'ok');
        async.flushMicrotasks();
        expect(channel.isJoined, isTrue);

        final heartbeats = <RealtimeHeartbeatStatus>[];
        client.onHeartbeat.listen(heartbeats.add);
        final messages = <RealtimeMessage>[];
        client.onMessage.listen(messages.add);

        async.elapse(client.heartbeatInterval);
        final heartbeat = server.sentEvents('heartbeat').single;
        async.elapse(client.heartbeatInterval);

        expect(heartbeats, [
          RealtimeHeartbeatStatus.sent,
          RealtimeHeartbeatStatus.timeout,
        ]);
        expect(channel.isErrored, isTrue);
        expect(client.connectionState, SocketState.closed);
        expect(attempts, [1]);

        messages.clear();
        server.reply(heartbeat, 'ok');
        async.flushMicrotasks();
        expect(messages, isEmpty);
        expect(heartbeats.last, RealtimeHeartbeatStatus.timeout);

        async.elapse(const Duration(seconds: 1));
        expect(server.connections, hasLength(2));
        expect(client.isConnected, isTrue);

        unawaited(client.disconnect());
        async.flushMicrotasks();
      });
    });

    test('is detected one interval after an unanswered heartbeat, which is '
        'sent at a fixed beat', () {
      fakeAsync((async) {
        final client = createClient();
        unawaited(client.connect());
        async.flushMicrotasks();

        async.elapse(client.heartbeatInterval);
        server.reply(server.sentEvents('heartbeat').single, 'ok');
        async.elapse(const Duration(seconds: 3));
        expect(server.sentEvents('heartbeat'), hasLength(1));
        async.elapse(client.heartbeatInterval - const Duration(seconds: 3));
        expect(server.sentEvents('heartbeat'), hasLength(2));

        async.elapse(client.heartbeatInterval);
        expect(client.connectionState, SocketState.closed);

        unawaited(client.disconnect());
        async.flushMicrotasks();
      });
    });
  });
}
