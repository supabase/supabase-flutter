@Tags(['integration'])
library;

import 'dart:async';

import 'package:postgres/postgres.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:test/test.dart';

import 'utils/realtime_test_utils.dart';

/// Integration tests that run against a real Supabase Realtime server started
/// with the Supabase CLI (`supabase start`).
///
/// The whole suite runs once for each supported protocol version so that both
/// the legacy v1 frames and the v2 positional/binary frames are exercised
/// against the server.
void main() {
  setUpAll(() async {
    await waitForRealtimeServer();
    await primePostgresChanges();
  });

  for (final version in RealtimeProtocolVersion.values) {
    group('Realtime protocol ${version.vsn}', () {
      late RealtimeClient client;

      setUp(() {
        client = createRealtimeClient(version);
      });

      tearDown(() async {
        await client.removeAllChannels();
        await client.disconnect();
      });

      test('connects and reports the open state', () async {
        final opened = Completer<void>();
        client.onOpen(() {
          if (!opened.isCompleted) opened.complete();
        });
        client.connect();
        await opened.future.timeout(const Duration(seconds: 10));
        expect(client.isConnected, isTrue);
      });

      test('subscribes to a channel', () async {
        final channel = client.channel('subscribe-${version.vsn}');
        final status = await _subscribe(channel);
        expect(status, RealtimeSubscribeStatus.subscribed);
        expect(channel.isJoined, isTrue);
      });

      test('unsubscribes from a channel', () async {
        final channel = client.channel('unsubscribe-${version.vsn}');
        await _subscribe(channel);
        final result = await channel.unsubscribe();
        expect(result, 'ok');
        expect(channel.isJoined, isFalse);
      });

      test('receives its own broadcast when self is enabled', () async {
        final channel = client.channel(
          'broadcast-self-${version.vsn}',
          const RealtimeChannelConfig(self: true),
        );
        final received = Completer<Map<String, dynamic>>();
        channel.onBroadcast(
          event: 'ping',
          callback: (payload) {
            if (!received.isCompleted) received.complete(payload);
          },
        );
        await _subscribe(channel);
        await channel.sendBroadcastMessage(
          event: 'ping',
          payload: {
            'payload': {'value': 42},
          },
        );

        final payload =
            await received.future.timeout(const Duration(seconds: 15));
        expect(payload['event'], 'ping');
        expect(payload['payload'], {'value': 42});
      });

      test('broadcasts between two clients', () async {
        final topic = 'broadcast-cross-${version.vsn}';
        final receiver = client;
        final sender = createRealtimeClient(version);
        addTearDown(() async {
          await sender.removeAllChannels();
          await sender.disconnect();
        });

        final received = Completer<Map<String, dynamic>>();
        final receiverChannel = receiver.channel(topic);
        receiverChannel.onBroadcast(
          event: 'cursor',
          callback: (payload) {
            if (!received.isCompleted) received.complete(payload);
          },
        );
        await _subscribe(receiverChannel);

        final senderChannel = sender.channel(topic);
        await _subscribe(senderChannel);
        await senderChannel.sendBroadcastMessage(
          event: 'cursor',
          payload: {
            'payload': {'x': 1, 'y': 2},
          },
        );

        final payload =
            await received.future.timeout(const Duration(seconds: 15));
        expect(payload['payload'], {'x': 1, 'y': 2});
      });

      test('tracks and syncs presence', () async {
        final channel = client.channel(
          'presence-${version.vsn}',
          const RealtimeChannelConfig(key: 'user-1'),
        );

        final synced = Completer<void>();
        channel.onPresenceSync((_) {
          if (channel.presenceState().isNotEmpty && !synced.isCompleted) {
            synced.complete();
          }
        });

        final joined = Completer<RealtimePresenceJoinPayload>();
        channel.onPresenceJoin((payload) {
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

        final joinPayload =
            await joined.future.timeout(const Duration(seconds: 15));
        expect(joinPayload.key, 'user-1');
        expect(joinPayload.newPresences, isNotEmpty);
      });

      test('removes presence on untrack', () async {
        final channel = client.channel(
          'presence-untrack-${version.vsn}',
          const RealtimeChannelConfig(key: 'user-2'),
        );

        final left = Completer<RealtimePresenceLeavePayload>();
        channel.onPresenceLeave((payload) {
          if (!left.isCompleted) left.complete(payload);
        });

        await _subscribe(channel);
        await channel.track({'online_at': '2026-06-15T00:00:00Z'});
        await _waitFor(() => channel.presenceState().isNotEmpty);
        await channel.untrack();

        final leavePayload =
            await left.future.timeout(const Duration(seconds: 15));
        expect(leavePayload.key, 'user-2');
        expect(channel.presenceState(), isEmpty);
      });

      group('postgres changes', () {
        late Connection db;

        setUp(() async {
          db = await openPostgresConnection();
          await db.execute('TRUNCATE public.todos RESTART IDENTITY');
        });

        tearDown(() async {
          await db.execute('TRUNCATE public.todos RESTART IDENTITY');
          await db.close();
        });

        test('receives insert, update and delete events', () async {
          final inserts = Completer<PostgresChangePayload>();
          final updates = Completer<PostgresChangePayload>();
          final deletes = Completer<PostgresChangePayload>();

          final channel = client.channel('db-changes-${version.vsn}');
          channel.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'todos',
            callback: (payload) {
              switch (payload.eventType) {
                case PostgresChangeEvent.insert:
                  if (!inserts.isCompleted) inserts.complete(payload);
                  break;
                case PostgresChangeEvent.update:
                  if (!updates.isCompleted) updates.complete(payload);
                  break;
                case PostgresChangeEvent.delete:
                  if (!deletes.isCompleted) deletes.complete(payload);
                  break;
                case PostgresChangeEvent.all:
                  break;
              }
            },
          );

          await _subscribe(channel);
          await Future<void>.delayed(const Duration(seconds: 2));

          await db.execute(
            "INSERT INTO public.todos (task) VALUES ('write tests')",
          );
          final insert =
              await inserts.future.timeout(const Duration(seconds: 20));
          expect(insert.eventType, PostgresChangeEvent.insert);
          expect(insert.newRecord['task'], 'write tests');

          await db.execute(
            "UPDATE public.todos SET is_complete = true WHERE task = 'write tests'",
          );
          final update =
              await updates.future.timeout(const Duration(seconds: 20));
          expect(update.eventType, PostgresChangeEvent.update);
          expect(update.newRecord['is_complete'], isTrue);
          expect(update.oldRecord['is_complete'], isFalse);

          await db
              .execute("DELETE FROM public.todos WHERE task = 'write tests'");
          final delete =
              await deletes.future.timeout(const Duration(seconds: 20));
          expect(delete.eventType, PostgresChangeEvent.delete);
          expect(delete.oldRecord['task'], 'write tests');
        });

        test('applies a postgres changes filter', () async {
          final matched = Completer<PostgresChangePayload>();

          final channel = client.channel('db-filter-${version.vsn}');
          channel.onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'todos',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'is_complete',
              value: true,
            ),
            callback: (payload) {
              if (!matched.isCompleted) matched.complete(payload);
            },
          );

          await _subscribe(channel);
          await Future<void>.delayed(const Duration(seconds: 2));

          await db.execute(
            "INSERT INTO public.todos (task, is_complete) VALUES ('ignored', false)",
          );

          await Future<void>.delayed(const Duration(seconds: 3));
          expect(
            matched.isCompleted,
            isFalse,
            reason: 'the non-matching row must not be delivered',
          );

          await db.execute(
            "INSERT INTO public.todos (task, is_complete) VALUES ('matched', true)",
          );

          final payload =
              await matched.future.timeout(const Duration(seconds: 20));
          expect(payload.newRecord['task'], 'matched');
          expect(payload.newRecord['is_complete'], isTrue);
        });
      });
    });
  }
}

/// Subscribes to [channel] and resolves with the terminal subscribe status.
Future<RealtimeSubscribeStatus> _subscribe(RealtimeChannel channel) {
  final completer = Completer<RealtimeSubscribeStatus>();
  channel.subscribe((status, error) {
    if (completer.isCompleted) return;
    if (status == RealtimeSubscribeStatus.subscribed) {
      completer.complete(status);
    } else if (status == RealtimeSubscribeStatus.channelError ||
        status == RealtimeSubscribeStatus.timedOut) {
      completer.completeError(
        StateError('Failed to subscribe: ${status.name} ($error)'),
        StackTrace.current,
      );
    }
  });
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
