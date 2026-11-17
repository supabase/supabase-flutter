@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

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

    test('stops after a private channel join is denied', () async {
      final channel = client.channel(
        'private-without-policy',
        const RealtimeChannelConfig(private: true),
      );
      final changes = <RealtimeSubscribeStatusChange>[];
      channel.onStatusChange.listen(changes.add);
      final replies = <RealtimeMessage>[];
      client.onMessage
          .where(
            (message) =>
                message.topic == channel.topic && message.event == 'phx_reply',
          )
          .listen(replies.add);

      final denied = channel.onStatusChange.firstWhere(
        (change) => change.status == RealtimeSubscribeStatus.channelError,
      );
      channel.subscribe();
      await denied.timeout(const Duration(seconds: 15));
      await Future<void>.delayed(const Duration(seconds: 4));

      expect(replies, hasLength(1));
      expect(changes, hasLength(1));
      expect(
        changes.single.error,
        isA<RealtimeException>().having(
          (error) => error.errorCode,
          'errorCode',
          'Unauthorized',
        ),
      );
      expect(channel.isErrored, isTrue);
    });

    test('unsubscribes from a channel', () async {
      final channel = client.channel('unsubscribe');
      await _subscribe(channel);
      final result = await channel.unsubscribe();
      expect(result, ChannelResponse.ok);
      expect(channel.isJoined, isFalse);
    });

    test('receives its own broadcast when self is enabled', () async {
      final channel = client.channel(
        'broadcast-self',
        const RealtimeChannelConfig(self: true),
      );
      final received = Completer<BroadcastMessage>();
      channel.onBroadcast(event: 'ping').listen((message) {
        if (!received.isCompleted) received.complete(message);
      });
      await _subscribe(channel);
      await channel.sendBroadcastMessage(
        event: 'ping',
        payload: {'value': 42},
      );

      final message = await received.future.timeout(
        const Duration(seconds: 15),
      );
      expect(message.event, 'ping');
      expect(message.payload, const JsonBroadcastPayload({'value': 42}));
    });

    test('broadcasts between two clients', () async {
      final topic = 'broadcast-cross';
      final receiver = client;
      final sender = createRealtimeClient();
      addTearDown(() async {
        await sender.removeAllChannels();
        await sender.disconnect();
      });

      final received = Completer<BroadcastMessage>();
      final receiverChannel = receiver.channel(topic);
      receiverChannel.onBroadcast(event: 'cursor').listen((message) {
        if (!received.isCompleted) received.complete(message);
      });
      await _subscribe(receiverChannel);

      final senderChannel = sender.channel(topic);
      await _subscribe(senderChannel);
      await senderChannel.sendBroadcastMessage(
        event: 'cursor',
        payload: {'x': 1, 'y': 2},
      );

      final message = await received.future.timeout(
        const Duration(seconds: 15),
      );
      expect(message.payload, const JsonBroadcastPayload({'x': 1, 'y': 2}));
    });

    test('receives broadcasts from every source in the same shape', () async {
      final topic = 'broadcast-sources';
      final channel = client.channel(
        topic,
        const RealtimeChannelConfig(self: true),
      );
      final received = <String, BroadcastMessage>{};
      final allReceived = Completer<void>();
      channel.onBroadcast(event: '*').listen((message) {
        received[message.event] = message;
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
      expect(received['socket']!.payload, const JsonBroadcastPayload({'x': 1}));
      expect(received['http']!.payload, const JsonBroadcastPayload({'x': 1}));
      expect(
        received['database']!.payload,
        isA<JsonBroadcastPayload>().having(
          (payload) => payload.value,
          'value',
          containsPair('x', 1),
        ),
      );
      expect(received['database']!.id, isNotNull);
    });

    test('round trips a binary broadcast', () async {
      final channel = client.channel(
        'broadcast-binary',
        const RealtimeChannelConfig(self: true),
      );
      final received = Completer<BroadcastMessage>();
      channel.onBroadcast(event: 'file').listen((message) {
        if (!received.isCompleted) received.complete(message);
      });
      await _subscribe(channel);

      final bytes = Uint8List.fromList([1, 2, 3]);
      await channel.sendBinaryBroadcastMessage(event: 'file', bytes: bytes);

      final message = await received.future.timeout(
        const Duration(seconds: 15),
      );
      expect(message.payload, BinaryBroadcastPayload(bytes));
    });

    test('tracks and syncs presence', () async {
      final channel = client.channel(
        'presence',
        const RealtimeChannelConfig(presenceKey: 'user-1'),
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
        const RealtimeChannelConfig(presenceKey: 'user-2'),
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

  group('broadcast persistence', () {
    const storedPrefix = 'persist-stored-';
    const deniedPrefix = 'persist-denied-';
    late Connection database;
    late RealtimeClient client;
    bool? previousFlag;
    var topicCount = 0;

    String uniqueTopic(String prefix) =>
        '$prefix${DateTime.now().microsecondsSinceEpoch}-${topicCount++}';

    Future<int> storedCount(String topic) async {
      final result = await database.execute(
        Sql.named('select count(*) from realtime.messages where topic = @t'),
        parameters: {'t': topic},
      );
      return result.single.single! as int;
    }

    // The server stores a message it does not acknowledge in the background,
    // so it may not be there yet when the send completes.
    Future<int> eventuallyStoredCount(String topic) async {
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      var count = await storedCount(topic);
      while (count == 0 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        count = await storedCount(topic);
      }
      return count;
    }

    setUpAll(() async {
      database = await openPostgresConnection();
      await database.execute(
        'drop policy if exists persist_test_read on realtime.messages',
      );
      await database.execute(
        'drop policy if exists persist_test_write on realtime.messages',
      );
      await database.execute('''
        create policy persist_test_read on realtime.messages
          for select to anon
          using (realtime.topic() like '$storedPrefix%'
            or realtime.topic() like '$deniedPrefix%')''');
      await database.execute('''
        create policy persist_test_write on realtime.messages
          for insert to anon
          with check (realtime.topic() like '$storedPrefix%'
            or (realtime.topic() like '$deniedPrefix%'
              and extension <> 'persistence'))''');

      final admin = await openPostgresConnection(username: 'supabase_admin');
      try {
        final previous = await admin.execute(
          "select enabled from _realtime.feature_flags "
          "where name = 'broadcast_persistence'",
        );
        previousFlag = previous.isEmpty ? null : previous.single.single as bool;
        await admin.execute('''
          insert into _realtime.feature_flags
            (id, name, enabled, inserted_at, updated_at)
          values
            (gen_random_uuid(), 'broadcast_persistence', true, now(), now())
          on conflict (name) do update set enabled = true''');
      } finally {
        await admin.close();
      }

      // The server caches feature flags for up to 30 seconds, so wait until
      // it stores a message.
      final probe = createRealtimeClient();
      try {
        final channel = probe.channel(
          uniqueTopic(storedPrefix),
          const RealtimeChannelConfig(private: true),
        );
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (await storedCount(channel.subTopic) == 0) {
          if (DateTime.now().isAfter(deadline)) {
            throw TimeoutException('Broadcast persistence never turned on');
          }
          await channel.httpSend(
            event: 'probe',
            payload: {},
            persist: const BroadcastPersistence(),
          );
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      } finally {
        await probe.disconnect();
      }
    });

    tearDownAll(() async {
      await database.execute(
        "delete from realtime.messages where topic like '$storedPrefix%' "
        "or topic like '$deniedPrefix%'",
      );
      await database.execute(
        'drop policy persist_test_read on realtime.messages',
      );
      await database.execute(
        'drop policy persist_test_write on realtime.messages',
      );
      await database.close();
      if (previousFlag != true) {
        final admin = await openPostgresConnection(username: 'supabase_admin');
        try {
          await admin.execute(
            previousFlag == null
                ? "delete from _realtime.feature_flags "
                      "where name = 'broadcast_persistence'"
                : "update _realtime.feature_flags set enabled = false "
                      "where name = 'broadcast_persistence'",
          );
        } finally {
          await admin.close();
        }
      }
    });

    setUp(() {
      client = createRealtimeClient();
    });

    tearDown(() async {
      await client.removeAllChannels();
      await client.disconnect();
    });

    test('stores a message sent over the websocket', () async {
      final channel = client.channel(
        uniqueTopic(storedPrefix),
        const RealtimeChannelConfig(private: true, ack: true),
      );
      await _subscribe(channel);

      final status = await channel.sendBroadcastMessage(
        event: 'stored',
        payload: {'value': 1},
        persist: const BroadcastPersistence(expiresIn: Duration(minutes: 5)),
      );

      expect(status, ChannelResponse.ok);
      final result = await database.execute(
        Sql.named(
          'select payload, '
          'extract(epoch from expires_at - inserted_at)::int '
          'from realtime.messages where topic = @t',
        ),
        parameters: {'t': channel.subTopic},
      );
      final [payload, lifetime] = result.single;
      expect(payload, {'value': 1});
      expect(lifetime, closeTo(300, 5));
    });

    test('reports a message the sender may not store', () async {
      final channel = client.channel(
        uniqueTopic(deniedPrefix),
        const RealtimeChannelConfig(private: true, ack: true),
      );
      await _subscribe(channel);

      final status = await channel.sendBroadcastMessage(
        event: 'denied',
        payload: {'value': 1},
        persist: const BroadcastPersistence(),
      );

      expect(status, ChannelResponse.persistenceUnauthorized);
      expect(await storedCount(channel.subTopic), 0);
    });

    test('stores a message sent over HTTP', () async {
      final channel = client.channel(
        uniqueTopic(storedPrefix),
        const RealtimeChannelConfig(private: true),
      );

      await channel.httpSend(
        event: 'stored',
        payload: {'value': 1},
        persist: const BroadcastPersistence(),
      );

      expect(await eventuallyStoredCount(channel.subTopic), 1);
    });

    test('throws the message of an expiry the server refuses over HTTP', () {
      final channel = client.channel(
        uniqueTopic(storedPrefix),
        const RealtimeChannelConfig(private: true),
      );

      return expectLater(
        () => channel.httpSend(
          event: 'refused',
          payload: {'value': 1},
          persist: const BroadcastPersistence(expiresIn: Duration.zero),
        ),
        throwsA(
          isA<RealtimeApiException>()
              .having((exception) => exception.statusCode, 'statusCode', 422)
              .having(
                (exception) => exception.message,
                'message',
                contains('persist ttl'),
              ),
        ),
      );
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
      channel.onBroadcast(event: 'tick').listen((message) {
        if (message.payload case JsonBroadcastPayload(
          value: {'index': final int index},
        )) {
          received.add(index);
        }
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
