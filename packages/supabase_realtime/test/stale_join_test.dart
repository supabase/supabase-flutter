import 'dart:async';
import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_realtime/src/constants.dart';
import 'package:test/test.dart';

import 'socket_test_stubs.dart';

const _topic = 'realtime:room';

class _FakeConnection {
  _FakeConnection({required bool reachable}) {
    when(() => channel.sink).thenReturn(sink);
    when(() => channel.ready).thenAnswer(
      (_) => reachable
          ? Future.value()
          : Future.error(Exception('server unreachable')),
    );
    when(() => channel.stream).thenAnswer((_) => _incoming.stream);
    when(() => sink.add(any())).thenAnswer((invocation) {
      sent.add(jsonDecode(invocation.positionalArguments.first as String));
    });
    when(() => sink.close()).thenAnswer((_) => _incoming.close());
    when(() => sink.close(any(), any())).thenAnswer((_) => _incoming.close());
  }

  final channel = MockIOWebSocketChannel();
  final sink = MockWebSocketSink();
  final _incoming = StreamController<dynamic>();
  final List<dynamic> sent = [];

  List<List<dynamic>> get joins => sent
      .cast<List<dynamic>>()
      .where((frame) => frame[3] == ChannelEvent.join.eventName())
      .toList();

  void receive(List<dynamic> frame) => _incoming.add(jsonEncode(frame));

  void reply(String ref, String status, [Map<String, dynamic>? response]) {
    receive([
      ref,
      ref,
      _topic,
      ChannelEvent.reply.eventName(),
      {'status': status, 'response': response ?? {}},
    ]);
  }

  Future<void> drop() => _incoming.close();
}

void main() {
  late List<_FakeConnection> connections;
  late RealtimeClient client;
  late List<RealtimeSubscribeStatus> statuses;

  RealtimeClient createClient({
    required Duration timeout,
    bool Function(int attempt)? reachable,
  }) {
    return RealtimeClient(
      'wss://localhost:0/',
      timeout: timeout,
      heartbeatInterval: const Duration(minutes: 5),
      reconnectAfter: (tries) => const Duration(milliseconds: 10),
      transport: (url, headers) {
        final connection = _FakeConnection(
          reachable: reachable?.call(connections.length + 1) ?? true,
        );
        connections.add(connection);
        return connection.channel;
      },
    );
  }

  RealtimeChannel subscribe([Duration? timeout]) {
    final channel = client.channel('room');
    channel.onStatusChange.listen((change) => statuses.add(change.status));
    return channel.subscribe(timeout);
  }

  Future<void> waitUntil(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('condition not met within 5 seconds');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  setUp(() {
    connections = [];
    statuses = [];
  });

  tearDown(() => client.disconnect());

  group('a join that went stale through a rejoin', () {
    late RealtimeChannel channel;
    late String staleRef;
    late String currentRef;
    late DateTime staleDeadline;

    setUp(() async {
      const timeout = Duration(milliseconds: 400);
      client = createClient(timeout: timeout);
      staleDeadline = DateTime.now().add(timeout);
      channel = subscribe();
      await waitUntil(() => connections.first.joins.length == 1);
      staleRef = connections.first.joins.single[1] as String;

      await Future<void>.delayed(const Duration(milliseconds: 200));
      await connections.first.drop();
      await waitUntil(
        () => connections.length == 2 && connections.last.joins.length == 1,
      );
      currentRef = connections.last.joins.single[1] as String;
      expect(currentRef, isNot(staleRef));
      expect(channel.isJoining, isTrue);
      statuses.clear();
    });

    test('ignores an error reply to the stale join', () async {
      connections.last.reply(staleRef, 'error', {'reason': 'stale'});
      await pumpEventQueue();

      expect(channel.isJoining, isTrue);
      expect(statuses, isEmpty);

      connections.last.reply(currentRef, 'ok');
      await waitUntil(() => channel.isJoined);
      expect(statuses, [RealtimeSubscribeStatus.subscribed]);
    });

    test('ignores a channel error for the stale join', () async {
      connections.last.receive([
        staleRef,
        staleRef,
        _topic,
        ChannelEvent.error.eventName(),
        {},
      ]);
      await pumpEventQueue();

      expect(channel.isJoining, isTrue);
      expect(statuses, isEmpty);

      connections.last.reply(currentRef, 'ok');
      await waitUntil(() => channel.isJoined);
      expect(statuses, [RealtimeSubscribeStatus.subscribed]);
    });

    test('does not time out when the stale join would have', () async {
      await Future<void>.delayed(
        staleDeadline.difference(DateTime.now()) +
            const Duration(milliseconds: 50),
      );

      expect(channel.isJoining, isTrue);
      expect(statuses, isEmpty);
      expect(connections.last.joins, hasLength(1));

      connections.last.reply(currentRef, 'ok');
      await waitUntil(() => channel.isJoined);
      expect(statuses, [RealtimeSubscribeStatus.subscribed]);
    });
  });

  group('during an outage', () {
    var outage = true;

    setUp(() {
      outage = true;
      client = createClient(
        timeout: const Duration(milliseconds: 50),
        reachable: (_) => !outage,
      );
    });

    test('connect() returns while the reconnect keeps retrying', () async {
      await client.connect().timeout(const Duration(seconds: 1));

      expect(client.isConnected, isFalse);
      await waitUntil(() => connections.length >= 3);

      outage = false;
      await waitUntil(() => client.isConnected);
    });

    test('subscribe() times out instead of hanging, then joins once the '
        'server is back without sending the timed out join', () async {
      final channel = subscribe();

      await waitUntil(
        () => statuses.contains(RealtimeSubscribeStatus.timedOut),
      );
      expect(channel.isErrored, isTrue);
      expect(client.isConnected, isFalse);

      outage = false;
      await waitUntil(() => connections.last.joins.isNotEmpty);
      await pumpEventQueue();
      final join = connections.last.joins.single;
      expect(join[1], channel.joinRef);
      connections.last.reply(join[1] as String, 'ok');

      await waitUntil(() => channel.isJoined);
      expect(statuses.last, RealtimeSubscribeStatus.subscribed);
    });
  });
}
