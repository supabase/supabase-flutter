import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  late MockSupabaseHttpClient httpClient;
  late MockRealtimeTransport realtime;
  late SupabaseClient supabase;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    realtime = MockRealtimeTransport();
    supabase = testSupabaseClient(httpClient: httpClient, realtime: realtime);
    addTearDown(supabase.dispose);
  });

  Future<void> subscribed(RealtimeChannel channel) {
    final done = channel.onStatusChange.firstWhere(
      (change) => change.status == RealtimeSubscribeStatus.subscribed,
    );
    channel.subscribe();
    return done;
  }

  group('joining', () {
    test('a channel subscribes and the join is recorded', () async {
      final channel = supabase.channel('todos');
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'todos',
      );

      await subscribed(channel);

      expect(realtime.isConnected, isTrue);
      expect(realtime.connectionCount, 1);
      expect(realtime.joinedTopics, ['realtime:todos']);
      final join = realtime.sent.singleWhere(
        (message) => message.event == 'phx_join',
      );
      final config = (join.payload as Map)['config'] as Map;
      expect(
        config['postgres_changes'],
        [
          containsPair('table', 'todos'),
        ],
      );
    });

    test('leaving a channel forgets its topic', () async {
      final channel = supabase.channel('todos');
      await subscribed(channel);

      await channel.unsubscribe();

      expect(realtime.joinedTopics, isEmpty);
    });

    test('a heartbeat is answered with an ok reply', () async {
      final connection = realtime('ws://localhost:54321/realtime/v1', {});
      final reply = connection.stream.first;

      connection.sink.add('[null,"7","phoenix","phx_heartbeat",{}]');

      expect(
        await reply,
        '[null,"7","phoenix","phx_reply",{"status":"ok","response":{}}]',
      );
      expect(realtime.sent.single.event, 'phx_heartbeat');
    });
  });

  group('emitPostgresChange', () {
    test('reaches a channel bound to the table and event', () async {
      final channel = supabase.channel('todos');
      final changes = channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'todos',
      );
      await subscribed(channel);
      final received = changes.first;

      realtime.emitPostgresChange(
        table: 'todos',
        event: PostgresChangeEvent.insert,
        newRecord: {'id': 1, 'task': 'Ship it', 'status': false},
      );

      final payload = await received;
      expect(payload.eventType, PostgresChangeEvent.insert);
      expect(payload.table, 'todos');
      expect(payload.newRecord, {'id': 1, 'task': 'Ship it', 'status': false});
      expect(payload.oldRecord, isEmpty);
    });

    test('skips channels bound to another event or table', () async {
      final channel = supabase.channel('todos');
      final deletes = channel.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'todos',
      );
      final profiles = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
      );
      final inserts = channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'todos',
      );
      await subscribed(channel);
      final unexpected = <Object>[];
      deletes.listen(unexpected.add);
      profiles.listen(unexpected.add);
      final received = inserts.first;

      realtime.emitPostgresChange(
        table: 'todos',
        event: PostgresChangeEvent.insert,
        newRecord: {'id': 1},
      );

      await received;
      expect(unexpected, isEmpty);
    });

    test('reaches a channel bound to the whole schema', () async {
      final channel = supabase.channel('everything');
      final changes = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
      );
      await subscribed(channel);
      final received = changes.first;

      realtime.emitPostgresChange(
        table: 'todos',
        event: PostgresChangeEvent.delete,
        oldRecord: {'id': 1},
      );

      final payload = await received;
      expect(payload.table, 'todos');
      expect(payload.eventType, PostgresChangeEvent.delete);
    });

    test('throws when no joined channel listens to the table', () async {
      await subscribed(supabase.channel('room'));

      expect(
        () => realtime.emitPostgresChange(
          table: 'todos',
          event: PostgresChangeEvent.insert,
          newRecord: {'id': 1},
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('public.todos'),
          ),
        ),
      );
    });

    test('rejects the all event', () {
      expect(
        () => realtime.emitPostgresChange(
          table: 'todos',
          event: PostgresChangeEvent.all,
        ),
        throwsArgumentError,
      );
    });
  });

  group('stream', () {
    test('emits the initial rows and then applies the changes', () async {
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1, 'task': 'Ship it'},
        ],
      );
      final stream = supabase.from('todos').stream(primaryKey: ['id']);
      final snapshots = <SupabaseStreamEvent>[];
      final subscription = stream.listen(snapshots.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      realtime.emitPostgresChange(
        table: 'todos',
        event: PostgresChangeEvent.insert,
        newRecord: {'id': 2, 'task': 'Write tests'},
      );
      await pumpEventQueue();
      realtime.emitPostgresChange(
        table: 'todos',
        event: PostgresChangeEvent.update,
        newRecord: {'id': 1, 'task': 'Shipped'},
        oldRecord: {'id': 1},
      );
      await pumpEventQueue();
      realtime.emitPostgresChange(
        table: 'todos',
        event: PostgresChangeEvent.delete,
        oldRecord: {'id': 2},
      );
      await pumpEventQueue();

      expect(snapshots, [
        [
          {'id': 1, 'task': 'Ship it'},
        ],
        [
          {'id': 1, 'task': 'Ship it'},
          {'id': 2, 'task': 'Write tests'},
        ],
        [
          {'id': 1, 'task': 'Shipped'},
          {'id': 2, 'task': 'Write tests'},
        ],
        [
          {'id': 1, 'task': 'Shipped'},
        ],
      ]);
    });
  });

  group('emitBroadcast', () {
    test('reaches the listeners of the event', () async {
      final channel = supabase.channel('room');
      final cursors = channel.onBroadcast(event: 'cursor');
      await subscribed(channel);
      final received = cursors.first;

      realtime.emitBroadcast(
        'room',
        event: 'cursor',
        payload: {'x': 1, 'y': 2},
      );

      final message = await received;
      expect(message['event'], 'cursor');
      expect(message['payload'], {'x': 1, 'y': 2});
    });

    test('a broadcast the client sends is recorded and acknowledged', () async {
      final channel = supabase.channel('room');
      await subscribed(channel);

      final status = await channel.sendBroadcastMessage(
        event: 'cursor',
        payload: {'x': 3},
      );

      expect(status, ChannelResponse.ok);
      final sent = realtime.sent.singleWhere(
        (message) => message.event == 'broadcast',
      );
      expect(sent.topic, 'realtime:room');
      expect(sent.payload, {'type': 'broadcast', 'event': 'cursor', 'x': 3});
    });
  });

  group('closeConnection', () {
    test('the client observes the disconnect', () async {
      final channel = supabase.channel('room');
      await subscribed(channel);
      final closed = supabase.realtime.onStatusChange.firstWhere(
        (change) => change.status == RealtimeConnectionStatus.closed,
      );

      await realtime.closeConnection(code: 1011, reason: 'restart');

      await closed;
      expect(realtime.isConnected, isFalse);
      expect(realtime.joinedTopics, isEmpty);
    });
  });

  test('disposing the client forgets its connection and topics', () async {
    await subscribed(supabase.channel('room'));

    await supabase.dispose();

    expect(realtime.isConnected, isFalse);
    expect(realtime.joinedTopics, isEmpty);
  });

  test('emitting without a connection names the problem', () {
    expect(
      () => realtime.emitBroadcast('room', event: 'x', payload: {}),
      throwsA(isA<StateError>()),
    );
  });
}
