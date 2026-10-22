@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:postgres/postgres.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:test/test.dart';

import 'utils/realtime_test_utils.dart';

/// Integration tests that run against a real Supabase Realtime server started
/// with the Supabase CLI (`supabase start`).
void main() {
  setUpAll(() async {
    await waitForRealtimeServer();
    await primePostgresChanges();
  });

  group('Realtime', () {
    late RealtimeClient client;

    setUp(() {
      client = createRealtimeClient();
    });

    tearDown(() async {
      await client.removeAllChannels();
      await client.disconnect();
    });

    test('connects and reports the open state', () async {
      final opened = Completer<void>();
      client.onStatusChange.listen((change) {
        if (change.status == RealtimeConnectionStatus.open &&
            !opened.isCompleted) {
          opened.complete();
        }
      });
      await client.connect();
      await opened.future.timeout(const Duration(seconds: 10));
      expect(client.isConnected, isTrue);
    });

    test('reports heartbeat sent and ok statuses', () async {
      final heartbeatClient = RealtimeClient(
        localStackRealtimeUrl,
        parameters: {'apikey': generateRealtimeToken()},
        heartbeatInterval: const Duration(milliseconds: 500),
      );
      final statuses = <RealtimeHeartbeatStatus>[];
      final acknowledged = Completer<void>();
      final subscription = heartbeatClient.onHeartbeat.listen((status) {
        statuses.add(status);
        if (status == RealtimeHeartbeatStatus.ok && !acknowledged.isCompleted) {
          acknowledged.complete();
        }
      });

      try {
        await heartbeatClient.connect();
        await acknowledged.future.timeout(const Duration(seconds: 10));
        expect(statuses, contains(RealtimeHeartbeatStatus.sent));
        expect(statuses, contains(RealtimeHeartbeatStatus.ok));
      } finally {
        await subscription.cancel();
        await heartbeatClient.disconnect();
      }
    });

    test('subscribes to a channel', () async {
      final channel = client.channel('subscribe');
      final status = await _subscribe(channel);
      expect(status, RealtimeSubscribeStatus.subscribed);
      expect(channel.isJoined, isTrue);
    });

    test('unsubscribes from a channel', () async {
      final channel = client.channel('unsubscribe');
      await _subscribe(channel);
      final result = await channel.unsubscribe();
      expect(result, 'ok');
      expect(channel.isJoined, isFalse);
    });

    test('receives its own broadcast when self is enabled', () async {
      final channel = client.channel(
        'broadcast-self',
        const RealtimeChannelConfig(self: true),
      );
      final received = Completer<Map<String, dynamic>>();
      channel.onBroadcast(event: 'ping').listen((payload) {
        if (!received.isCompleted) received.complete(payload);
      });
      await _subscribe(channel);
      await channel.sendBroadcastMessage(
        event: 'ping',
        payload: {'value': 42},
      );

      final payload = await received.future.timeout(
        const Duration(seconds: 15),
      );
      expect(payload['event'], 'ping');
      expect(payload['payload'], {'value': 42});
    });

    test('broadcasts between two clients', () async {
      final topic = 'broadcast-cross';
      final receiver = client;
      final sender = createRealtimeClient();
      addTearDown(() async {
        await sender.removeAllChannels();
        await sender.disconnect();
      });

      final received = Completer<Map<String, dynamic>>();
      final receiverChannel = receiver.channel(topic);
      receiverChannel.onBroadcast(event: 'cursor').listen((payload) {
        if (!received.isCompleted) received.complete(payload);
      });
      await _subscribe(receiverChannel);

      final senderChannel = sender.channel(topic);
      await _subscribe(senderChannel);
      await senderChannel.sendBroadcastMessage(
        event: 'cursor',
        payload: {'x': 1, 'y': 2},
      );

      final payload = await received.future.timeout(
        const Duration(seconds: 15),
      );
      expect(payload['payload'], {'x': 1, 'y': 2});
    });

    test('receives broadcasts from every source in the same shape', () async {
      final topic = 'broadcast-sources';
      final channel = client.channel(
        topic,
        const RealtimeChannelConfig(self: true),
      );
      final received = <String, Map<String, dynamic>>{};
      final allReceived = Completer<void>();
      channel.onBroadcast(event: '*').listen((message) {
        received[message['event'] as String] = message;
        if (received.length == 3 && !allReceived.isCompleted) {
          allReceived.complete();
        }
      });
      await _subscribe(channel);

      await channel.sendBroadcastMessage(event: 'socket', payload: {'x': 1});
      await channel.httpSend(event: 'http', payload: {'x': 1});
      final database = await openPostgresConnection();
      addTearDown(database.close);
      await database.execute(
        Sql.named(
          "select realtime.send('{\"x\": 1}'::jsonb, 'database', @topic, "
          'false)',
        ),
        parameters: {'topic': topic},
      );

      await allReceived.future.timeout(const Duration(seconds: 15));
      expect(received['socket']!['payload'], {'x': 1});
      expect(received['http']!['payload'], {'x': 1});
      expect(received['database']!['payload'], containsPair('x', 1));
    });

    test('tracks and syncs presence', () async {
      final channel = client.channel(
        'presence',
        const RealtimeChannelConfig(key: 'user-1'),
      );

      final synced = Completer<void>();
      channel.onPresenceSync.listen((_) {
        if (channel.presenceState().isNotEmpty && !synced.isCompleted) {
          synced.complete();
        }
      });

      final joined = Completer<RealtimePresenceJoinPayload>();
      channel.onPresenceJoin.listen((payload) {
        if (!joined.isCompleted) joined.complete(payload);
      });

      await _subscribe(channel);
      await channel.track({'online_at': '2026-06-15T00:00:00Z'});

      await synced.future.timeout(const Duration(seconds: 15));
      final state = channel.presenceState();
      expect(state, hasLength(1));
      expect(state.first.key, 'user-1');
      expect(
        state.first.presences.first.payload['online_at'],
        '2026-06-15T00:00:00Z',
      );

      final joinPayload = await joined.future.timeout(
        const Duration(seconds: 15),
      );
      expect(joinPayload.key, 'user-1');
      expect(joinPayload.newPresences, isNotEmpty);
    });

    test('removes presence on untrack', () async {
      final channel = client.channel(
        'presence-untrack',
        const RealtimeChannelConfig(key: 'user-2'),
      );

      final left = Completer<RealtimePresenceLeavePayload>();
      channel.onPresenceLeave.listen((payload) {
        if (!left.isCompleted) left.complete(payload);
      });

      await _subscribe(channel);
      await channel.track({'online_at': '2026-06-15T00:00:00Z'});
      await _waitFor(() => channel.presenceState().isNotEmpty);
      await channel.untrack();

      final leavePayload = await left.future.timeout(
        const Duration(seconds: 15),
      );
      expect(leavePayload.key, 'user-2');
      expect(channel.presenceState(), isEmpty);
    });

    group('postgres changes', () {
      late Connection database;

      setUp(() async {
        database = await openPostgresConnection();
        await database.execute('TRUNCATE public.todos RESTART IDENTITY');
      });

      tearDown(() async {
        await database.execute('TRUNCATE public.todos RESTART IDENTITY');
        await database.close();
      });

      test('receives insert, update and delete events', () async {
        final inserts = Completer<PostgresChangePayload>();
        final updates = Completer<PostgresChangePayload>();
        final deletes = Completer<PostgresChangePayload>();

        final channel = client.channel('db-changes');
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'todos',
            )
            .listen((payload) {
              switch (payload.eventType) {
                case PostgresChangeEvent.insert:
                  if (!inserts.isCompleted) inserts.complete(payload);
                case PostgresChangeEvent.update:
                  if (!updates.isCompleted) updates.complete(payload);
                case PostgresChangeEvent.delete:
                  if (!deletes.isCompleted) deletes.complete(payload);
                case PostgresChangeEvent.all || PostgresChangeEvent.unknown:
                  break;
              }
            });

        await _subscribe(channel);
        await Future<void>.delayed(const Duration(seconds: 2));

        await database.execute(
          "INSERT INTO public.todos (task) VALUES ('write tests')",
        );
        final insert = await inserts.future.timeout(
          const Duration(seconds: 20),
        );
        expect(insert.eventType, PostgresChangeEvent.insert);
        expect(insert.newRecord['task'], 'write tests');

        await database.execute(
          "UPDATE public.todos SET is_complete = true WHERE task = 'write "
          "tests'",
        );
        final update = await updates.future.timeout(
          const Duration(seconds: 20),
        );
        expect(update.eventType, PostgresChangeEvent.update);
        expect(update.newRecord['is_complete'], isTrue);
        expect(update.oldRecord['is_complete'], isFalse);

        await database.execute(
          "DELETE FROM public.todos WHERE task = 'write tests'",
        );
        final delete = await deletes.future.timeout(
          const Duration(seconds: 20),
        );
        expect(delete.eventType, PostgresChangeEvent.delete);
        expect(delete.oldRecord['task'], 'write tests');
      });

      test('applies a postgres changes filter', () async {
        final matched = Completer<PostgresChangePayload>();

        final channel = client.channel('db-filter');
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'todos',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'is_complete',
                value: true,
              ),
            )
            .listen((payload) {
              if (!matched.isCompleted) matched.complete(payload);
            });

        await _subscribe(channel);
        await Future<void>.delayed(const Duration(seconds: 2));

        await database.execute(
          "INSERT INTO public.todos (task, is_complete) VALUES ('ignored', "
          "false)",
        );

        await Future<void>.delayed(const Duration(seconds: 3));
        expect(
          matched.isCompleted,
          isFalse,
          reason: 'the non-matching row must not be delivered',
        );

        await database.execute(
          "INSERT INTO public.todos (task, is_complete) VALUES ('matched', "
          "true)",
        );

        final payload = await matched.future.timeout(
          const Duration(seconds: 20),
        );
        expect(payload.newRecord['task'], 'matched');
        expect(payload.newRecord['is_complete'], isTrue);
      });
    });
  });

  group('asynchronous codec', () {
    late RealtimeClient client;

    setUp(() {
      client = RealtimeClient(
        localStackRealtimeUrl,
        parameters: {'apikey': generateRealtimeToken()},
        heartbeatInterval: const Duration(seconds: 5),
        encode: _encodeOnBackgroundIsolate,
        decode: _decodeOnBackgroundIsolate,
      );
    });

    tearDown(() async {
      await client.removeAllChannels();
      await client.disconnect();
    });

    test('round trips broadcasts in order', () async {
      final channel = client.channel(
        'async-codec',
        const RealtimeChannelConfig(self: true),
      );

      final received = <int>[];
      final allReceived = Completer<void>();
      channel.onBroadcast(event: 'tick').listen((payload) {
        received.add(payload['payload']['index'] as int);
        if (received.length == _asyncCodecMessageCount &&
            !allReceived.isCompleted) {
          allReceived.complete();
        }
      });
      await _subscribe(channel);

      for (var index = 0; index < _asyncCodecMessageCount; index++) {
        await channel.sendBroadcastMessage(
          event: 'tick',
          payload: {'index': index},
        );
      }

      await allReceived.future.timeout(const Duration(seconds: 20));
      expect(
        received,
        List.generate(_asyncCodecMessageCount, (index) => index),
      );
    });
  });
}

/// Number of broadcasts the asynchronous codec test sends.
const _asyncCodecMessageCount = 10;

/// Encodes a protocol `2.0.0` text frame on a background isolate.
Future<Object> _encodeOnBackgroundIsolate(RealtimeMessage message) async {
  final json = message.toJson();
  await _delayInReverseOrder(message.payload);
  return Isolate.run(() => jsonEncode(json));
}

/// Decodes a protocol `2.0.0` text frame on a background isolate.
Future<RealtimeMessage> _decodeOnBackgroundIsolate(Object frame) async {
  final json = await Isolate.run(() => jsonDecode(frame as String));
  final message = RealtimeMessage.fromJson(json);
  await _delayInReverseOrder(message.payload);
  return message;
}

/// Holds back a broadcast for longer the earlier its index is.
///
/// The codec calls then complete in the opposite order of the messages, so the
/// client has to restore the push order before writing to the socket and the
/// receive order before dispatching to the channel.
Future<void> _delayInReverseOrder(Object? payload) async {
  final index = payload is Map ? (payload['payload']?['index'] as int?) : null;
  if (index == null) {
    return;
  }
  await Future<void>.delayed(
    Duration(milliseconds: 20 * (_asyncCodecMessageCount - index)),
  );
}

/// Subscribes to [channel] and resolves with the terminal subscribe status.
Future<RealtimeSubscribeStatus> _subscribe(RealtimeChannel channel) {
  final completer = Completer<RealtimeSubscribeStatus>();
  channel.onStatusChange.listen((change) {
    if (completer.isCompleted) return;
    if (change.status == RealtimeSubscribeStatus.subscribed) {
      completer.complete(change.status);
    } else if (change.status == RealtimeSubscribeStatus.channelError ||
        change.status == RealtimeSubscribeStatus.timedOut ||
        change.status == RealtimeSubscribeStatus.closed) {
      completer.completeError(
        StateError(
          'Failed to subscribe: ${change.status.name} (${change.error})',
        ),
        StackTrace.current,
      );
    }
  });
  channel.subscribe();
  return completer.future.timeout(const Duration(seconds: 15));
}

/// Polls [condition] until it returns true or the timeout elapses.
Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TimeoutException('Condition not met within $timeout');
}
