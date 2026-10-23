import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

import 'socket_test_stubs.dart';

void main() {
  late MockRealtimeTransport transport;
  late RealtimeClient client;

  setUp(() {
    transport = MockRealtimeTransport();
    client = RealtimeClient('ws://localhost:0', transport: transport.call);
  });

  tearDown(() => client.removeAllChannels());

  Iterable<RealtimeMessage> sentEvents(String event) =>
      transport.sent.where((message) => message.event == event);

  Future<RealtimeChannel> subscribedChannel(
    String topic, {
    RealtimeChannelConfig config = const RealtimeChannelConfig(),
  }) async {
    final channel = client.channel(topic, config);
    final subscribed = channel.onStatusChange.firstWhere(
      (change) => change.status == RealtimeSubscribeStatus.subscribed,
    );
    channel.subscribe();
    await subscribed;
    return channel;
  }

  group('disconnect', () {
    test('rejoins the subscribed channels on the next connect', () async {
      final channel = await subscribedChannel('room');
      final messages = channel.onBroadcast(event: 'message');
      final statuses = <RealtimeSubscribeStatus>[];
      channel.onStatusChange.listen((change) => statuses.add(change.status));

      await client.disconnect();
      await pumpEventQueue();
      expect(transport.joinedTopics, isEmpty);

      await client.connect();
      await pumpEventQueue();

      expect(sentEvents('phx_join'), hasLength(2));
      expect(transport.joinedTopics, ['realtime:room']);
      expect(statuses, [RealtimeSubscribeStatus.subscribed]);
      expect(channel.isJoined, isTrue);

      final received = messages.first;
      transport.emitBroadcast(
        'room',
        event: 'message',
        payload: {'text': 'hello'},
      );
      expect((await received)['payload'], {'text': 'hello'});
    });

    test('a channel removed while disconnected does not leave the channel '
        'that reuses its name', () async {
      final first = await subscribedChannel('room');
      await client.disconnect();
      await client.removeChannel(first);

      final second = client.channel('room').subscribe();
      await client.disconnect();
      await client.connect();
      await pumpEventQueue();

      expect(second, isNot(same(first)));
      expect(sentEvents('phx_leave'), isEmpty);
      expect(second.isJoined, isTrue);
      expect(transport.joinedTopics, ['realtime:room']);
    });

    test('keeps the channels registered', () async {
      final channel = await subscribedChannel('room');

      await client.disconnect();

      expect(client.channels, [channel]);
    });
  });

  group('a second channel with the same name', () {
    test('is the subscribed channel, which stays joined', () async {
      final channel = await subscribedChannel('room');
      final statuses = <RealtimeSubscribeStatus>[];
      channel.onStatusChange.listen((change) => statuses.add(change.status));

      final second = client.channel('room');
      await pumpEventQueue();

      expect(second, same(channel));
      expect(channel.isJoined, isTrue);
      expect(statuses, isEmpty);
      expect(sentEvents('phx_leave'), isEmpty);
      expect(client.channels, [channel]);
    });
  });

  group('reply bindings', () {
    test('are removed once an acknowledged broadcast is answered', () async {
      final channel = await subscribedChannel(
        'room',
        config: const RealtimeChannelConfig(ack: true),
      );
      final bindingTypes = channel.bindingTypes.toSet();

      for (var i = 0; i < 100; i++) {
        expect(
          await channel.sendBroadcastMessage(
            event: 'tick',
            payload: <String, dynamic>{},
          ),
          ChannelResponse.ok,
        );
      }

      expect(channel.bindingTypes.toSet(), bindingTypes);
    });

    test('are not kept for a broadcast without an acknowledgement', () async {
      final channel = await subscribedChannel('room');
      final bindingTypes = channel.bindingTypes.toSet();

      for (var i = 0; i < 100; i++) {
        await channel.sendBroadcastMessage(
          event: 'tick',
          payload: <String, dynamic>{},
        );
      }

      expect(channel.bindingTypes.toSet(), bindingTypes);
      expect(sentEvents('broadcast'), hasLength(100));
    });
  });

  group('a broadcast without an acknowledgement', () {
    test('reports an error without sending after unsubscribe', () async {
      final channel = await subscribedChannel('room');
      await channel.unsubscribe();

      final response = await channel.sendBroadcastMessage(
        event: 'tick',
        payload: <String, dynamic>{},
      );

      expect(response, ChannelResponse.error);
      expect(sentEvents('broadcast'), isEmpty);
    });

    test('reports ok once it is sent after the join', () async {
      final channel = client.channel('room').subscribe();

      final response = await channel.sendBroadcastMessage(
        event: 'tick',
        payload: <String, dynamic>{},
      );

      expect(response, ChannelResponse.ok);
      expect(sentEvents('broadcast'), hasLength(1));
      expect(channel.isJoined, isTrue);
    });

    test('reports an error when the channel closes before the join', () async {
      final channel = client.channel('room').subscribe();
      final response = channel.sendBroadcastMessage(
        event: 'tick',
        payload: <String, dynamic>{},
      );

      await channel.unsubscribe();

      expect(await response, ChannelResponse.error);
      expect(sentEvents('broadcast'), isEmpty);
    });

    test('reports a timeout when the join outlasts the timeout', () async {
      final connection = MockIOWebSocketChannel();
      final sink = MockWebSocketSink();
      when(() => connection.sink).thenReturn(sink);
      when(() => connection.ready).thenAnswer((_) => Completer<void>().future);
      when(() => sink.add(any())).thenAnswer((_) {});
      when(() => sink.close()).thenAnswer((_) => Future.value());
      client = RealtimeClient(
        'ws://localhost:0',
        transport: (url, headers) => connection,
        timeout: const Duration(milliseconds: 20),
      );
      final channel = client.channel('room').subscribe();

      final response = await channel.sendBroadcastMessage(
        event: 'tick',
        payload: <String, dynamic>{},
      );

      expect(response, ChannelResponse.timedOut);
      verifyNever(() => sink.add(any()));
    });
  });

  group('postgres changes bindings', () {
    Stream<PostgresChangePayload> listenToTodos(RealtimeChannel channel) =>
        channel.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'todos',
        );

    test('cannot be added once the channel has errored', () async {
      final channel = await subscribedChannel('room');
      await transport.closeConnection(code: 1006);
      await pumpEventQueue(times: 1);
      expect(channel.isErrored, isTrue);

      expect(() => listenToTodos(channel), throwsStateError);
    });

    test('report a mismatch when the server echoes fewer of them', () async {
      final channel = client.channel('room');
      listenToTodos(channel);
      final statuses = <RealtimeSubscribeStatusChange>[];
      channel.onStatusChange.listen(statuses.add);

      channel.subscribe();
      channel.joinPush.trigger('ok', {'postgres_changes': <Object>[]});
      await pumpEventQueue();

      final mismatch = statuses.firstWhere(
        (change) => change.status == RealtimeSubscribeStatus.channelError,
      );
      expect(
        mismatch.error,
        isA<RealtimeException>().having(
          (error) => error.message,
          'message',
          contains('mismatch'),
        ),
      );
    });
  });

  group('a heartbeat timeout', () {
    for (final (description, close) in [
      ('never completes', () => Completer<void>().future),
      ('completes without ending the stream', Future<void>.value),
    ]) {
      test('reconnects when closing the connection $description', () async {
        var connections = 0;
        final connection = MockIOWebSocketChannel();
        final sink = MockWebSocketSink();
        when(() => connection.sink).thenReturn(sink);
        when(() => connection.ready).thenAnswer((_) => Future.value());
        when(
          () => connection.stream,
        ).thenAnswer((_) => StreamController<dynamic>().stream);
        when(() => sink.add(any())).thenAnswer((_) {});
        when(() => sink.close()).thenAnswer((_) => Future.value());
        when(() => sink.close(any(), any())).thenAnswer((_) => close());

        client = RealtimeClient(
          'ws://localhost:0',
          transport: (url, headers) {
            connections++;
            return connection;
          },
          connectionCloseTimeout: const Duration(milliseconds: 10),
          reconnectAfter: (_) => Duration.zero,
        );
        await client.connect();
        final statuses = client.onStatusChange.map((change) => change.status);

        await client.sendHeartbeat();
        await client.sendHeartbeat();

        await expectLater(
          statuses,
          emitsInOrder([
            RealtimeConnectionStatus.closed,
            RealtimeConnectionStatus.open,
          ]),
        );
        expect(connections, 2);
      });
    }
  });
}
