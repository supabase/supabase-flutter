import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_realtime/src/push.dart';
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

  group('state', () {
    test('follows the channel from subscribe to unsubscribe', () async {
      final channel = client.channel('room');
      expect(channel.state, ChannelState.closed);

      channel.subscribe();
      expect(channel.state, ChannelState.joining);

      await channel.onStatusChange.firstWhere(
        (change) => change.status == RealtimeSubscribeStatus.subscribed,
      );
      expect(channel.state, ChannelState.joined);

      expect(await channel.unsubscribe(), ChannelResponse.ok);
      expect(channel.state, ChannelState.closed);
    });

    test('finds a channel by its topic', () async {
      final channel = await subscribedChannel('room');

      expect(
        client.channels.where((each) => each.topic == 'realtime:room'),
        [channel],
      );
    });
  });

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
      expect(
        (await received).payload,
        const JsonBroadcastPayload({'text': 'hello'}),
      );
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

    // A client whose first socket closes only once [closeHandshake]
    // completes, and whose stream cancels only after [streamCancel].
    void useSlowClosingClient(
      Completer<void> closeHandshake,
      Completer<void> streamCancel,
    ) {
      client = RealtimeClient(
        'ws://localhost:0',
        disconnectOnEmptyChannelsAfter: Duration.zero,
        transport: (url, headers) {
          final connection = transport.call(url, headers);
          if (transport.connectionCount > 1) return connection;
          // The first socket closes only once the close handshake
          // completes, and its stream cancels only after that.
          final stream = StreamController<dynamic>(
            onCancel: () => streamCancel.future,
          );
          connection.stream.listen(stream.add, onDone: stream.close);
          final closing = MockIOWebSocketChannel();
          final sink = MockWebSocketSink();
          when(() => closing.ready).thenAnswer((_) => connection.ready);
          when(() => closing.stream).thenAnswer((_) => stream.stream);
          when(() => closing.sink).thenReturn(sink);
          when(() => sink.add(any())).thenAnswer(
            (invocation) =>
                connection.sink.add(invocation.positionalArguments.single),
          );
          when(() => sink.close()).thenAnswer((_) async {
            await closeHandshake.future;
            await connection.sink.close();
          });
          return closing;
        },
      );
    }

    test('a channel subscribed while the socket is closing joins on a new '
        'socket once the close is done', () {
      fakeAsync((async) {
        final closeHandshake = Completer<void>();
        final streamCancel = Completer<void>();
        useSlowClosingClient(closeHandshake, streamCancel);
        final first = client.channel('first').subscribe();
        async.flushMicrotasks();
        unawaited(client.removeChannel(first));
        async.flushMicrotasks();
        expect(client.connectionState, SocketState.disconnecting);

        final channel = client.channel('second').subscribe();
        closeHandshake.complete();
        async.flushMicrotasks();

        expect(transport.connectionCount, 2);
        expect(channel.isJoined, isTrue);
        expect(transport.joinedTopics, ['realtime:second']);

        // The cleanup of the old socket leaves the new one's heartbeat on.
        streamCancel.complete();
        async.elapse(client.heartbeatInterval);
        expect(sentEvents('heartbeat'), hasLength(1));

        unawaited(client.removeAllChannels());
        async.elapse(client.timeout);
      });
    });

    test('a disconnect requested while a connect waits for the close keeps '
        'the client disconnected', () {
      fakeAsync((async) {
        final closeHandshake = Completer<void>();
        useSlowClosingClient(closeHandshake, Completer<void>()..complete());
        final first = client.channel('first').subscribe();
        async.flushMicrotasks();
        unawaited(client.removeChannel(first));
        async.flushMicrotasks();
        expect(client.connectionState, SocketState.disconnecting);

        client.channel('second').subscribe();
        unawaited(client.disconnect());
        closeHandshake.complete();
        async.flushMicrotasks();

        expect(transport.connectionCount, 1);
        expect(client.connectionState, SocketState.disconnected);

        unawaited(client.removeAllChannels());
        async.elapse(client.timeout);
      });
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
      channel.joinPush.trigger(PushStatus.ok, {'postgres_changes': <Object>[]});
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
          reconnectAfter: (_) => Duration.zero,
        );
        await client.connect();
        final statuses = <RealtimeConnectionStatus>[];
        final subscription = client.onStatusChange.listen(
          (change) => statuses.add(change.status),
        );
        addTearDown(subscription.cancel);

        await client.sendHeartbeat();
        await client.sendHeartbeat();
        await pumpEventQueue();

        expect(statuses, [
          RealtimeConnectionStatus.closed,
          RealtimeConnectionStatus.open,
        ]);
        expect(connections, 2);
      });
    }
  });
}
