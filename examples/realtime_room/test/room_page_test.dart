import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realtime_room_example/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/testing.dart';
import 'package:supabase_test/supabase_test.dart';

const _topic = 'realtime:public-room';

void main() {
  late MockSupabaseHttpClient httpClient;
  late MockRealtimeTransport realtime;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    realtime = MockRealtimeTransport();
  });

  Future<Supabase> openRoom(WidgetTester tester) async {
    final supabase = await initializeTestSupabase(
      httpClient: httpClient,
      realtimeTransport: realtime.call,
    );
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messengerKey,
        home: const RoomPage(username: 'alice'),
      ),
    );
    await _pumpUntil(tester, () => realtime.joinedTopics.contains(_topic));
    return supabase;
  }

  testWidgets('keeps a message inserted while the history loads', (
    tester,
  ) async {
    httpClient.stubHandler((request) {
      // The row commits after the read's snapshot, so only the stream has it.
      realtime.emitPostgresChange(
        table: 'messages',
        event: PostgresChangeEvent.insert,
        newRecord: _message('2', 'sent during the load'),
      );
      return jsonResponse([_message('1', 'already there')]);
    }, path: '/rest/v1/messages');

    final supabase = await openRoom(tester);
    _emitReplicationReady(realtime);
    await tester.pumpAndSettle();

    expect(find.text('already there'), findsOneWidget);
    expect(find.text('sent during the load'), findsOneWidget);
    await _closeRoom(tester, supabase);
  });

  testWidgets('drops a message deleted while the history loads', (
    tester,
  ) async {
    httpClient.stubHandler((request) {
      // The read's snapshot still has the row the stream reports deleted.
      realtime.emitPostgresChange(
        table: 'messages',
        event: PostgresChangeEvent.delete,
        oldRecord: {'id': '1'},
      );
      return jsonResponse([_message('1', 'deleted'), _message('2', 'kept')]);
    }, path: '/rest/v1/messages');

    final supabase = await openRoom(tester);
    _emitReplicationReady(realtime);
    await tester.pumpAndSettle();

    expect(find.text('deleted'), findsNothing);
    expect(find.text('kept'), findsOneWidget);
    await _closeRoom(tester, supabase);
  });

  testWidgets('still loads the history when realtime fails to join', (
    tester,
  ) async {
    httpClient.stubTable('messages', rows: [_message('1', 'already there')]);

    final supabase = await openRoom(tester);
    _emitReplicationReady(realtime, status: 'error');
    await tester.pumpAndSettle();

    expect(find.text('already there'), findsOneWidget);
    await _closeRoom(tester, supabase);
  });

  testWidgets('loads the history again after the app resumes', (
    tester,
  ) async {
    httpClient.stubTable(
      'messages',
      rows: [_message('1', 'deleted while away')],
    );
    final supabase = await openRoom(tester);
    _emitReplicationReady(realtime);
    await tester.pumpAndSettle();
    expect(find.text('deleted while away'), findsOneWidget);

    // The app goes to the background, which closes the realtime connection,
    // and the table changes before it comes back.
    _moveLifecycle(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await _pumpUntil(tester, () => !realtime.isConnected);
    httpClient.stubTable(
      'messages',
      rows: [_message('2', 'sent while away')],
    );
    _moveLifecycle(tester, const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await _pumpUntil(
      tester,
      () => realtime.connectionCount == 2 && realtime.joinedTopics.isNotEmpty,
    );
    _emitReplicationReady(realtime);
    await tester.pumpAndSettle();

    expect(find.text('deleted while away'), findsNothing);
    expect(find.text('sent while away'), findsOneWidget);
    expect(httpClient.requestsTo('/rest/v1/messages'), hasLength(2));
    await _closeRoom(tester, supabase);
  });

  testWidgets('shows typing pings from v2 and v3 clients', (tester) async {
    httpClient.stubTable('messages', rows: []);
    final supabase = await openRoom(tester);
    _emitReplicationReady(realtime);
    await tester.pumpAndSettle();

    // A client still on v2 sends the data next to `type` and `event`.
    realtime.emit(
      RealtimeMessage(
        topic: _topic,
        event: 'broadcast',
        payload: {'type': 'broadcast', 'event': 'typing', 'username': 'bob'},
      ),
    );
    realtime.emitBroadcast(
      _topic,
      event: 'typing',
      payload: {'username': 'carol'},
    );
    await _pumpUntil(
      tester,
      () => find.text('bob, carol are typing…').evaluate().isNotEmpty,
    );
    await _closeRoom(tester, supabase);
  });
}

Map<String, dynamic> _message(String id, String content) => {
  'id': id,
  'username': 'bob',
  'content': content,
  'created_at': '2026-01-01T00:00:0${id}Z',
};

/// The `system` event the server sends once Postgres Changes replication is
/// live, after the first join and again after every rejoin.
void _emitReplicationReady(
  MockRealtimeTransport realtime, {
  String status = 'ok',
}) {
  realtime.emit(
    RealtimeMessage(
      topic: _topic,
      event: 'system',
      payload: {
        'extension': 'system',
        'status': status,
        'message': 'Replication connection established',
        'channel': 'public-room',
      },
    ),
  );
}

void _moveLifecycle(WidgetTester tester, List<AppLifecycleState> states) {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

/// Leaves the room and disposes the client inside the test body, so no
/// realtime timer outlives the test.
Future<void> _closeRoom(WidgetTester tester, Supabase supabase) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(supabase.dispose);
}

/// Pumps frames until [condition] holds, giving up after [timeout] of fake
/// time, which covers the realtime client's reconnect backoff.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  const step = Duration(milliseconds: 100);
  for (var waited = Duration.zero; waited < timeout && !condition();) {
    await tester.pump(step);
    // Lets futures that complete outside the fake async zone resume.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    waited += step;
  }
  expect(condition(), isTrue);
}
