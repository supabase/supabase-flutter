import 'dart:async';
import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:test/test.dart';

import 'socket_test_stubs.dart';

void main() {
  late RealtimeClient client;
  late List<RealtimeHeartbeatStatus> statuses;
  late StreamSubscription<RealtimeHeartbeatStatus> subscription;

  setUp(() {
    final mockedChannel = MockIOWebSocketChannel();
    final mockedSink = MockWebSocketSink();
    when(() => mockedChannel.sink).thenReturn(mockedSink);
    when(() => mockedChannel.ready).thenAnswer((_) => Future.value());
    when(
      () => mockedChannel.stream,
    ).thenAnswer((_) => StreamController<dynamic>.broadcast().stream);
    when(() => mockedSink.add(any())).thenAnswer((_) {});
    when(() => mockedSink.close()).thenAnswer((_) => Future.value());
    when(
      () => mockedSink.close(any(), any()),
    ).thenAnswer((_) => Future.value());

    client = RealtimeClient(
      'wss://localhost:0/',
      transport: (url, headers) => mockedChannel,
      decode: (rawMessage) async => RealtimeMessage.fromJson(
        jsonDecode(rawMessage as String),
        RealtimeProtocolVersion.v1,
      ),
    );
    statuses = [];
    subscription = client.onHeartbeat.listen(statuses.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await client.disconnect();
  });

  String heartbeatReply(String? ref, String status) {
    return jsonEncode({
      'topic': 'phoenix',
      'event': 'phoenix_reply',
      'payload': {'status': status, 'response': <String, dynamic>{}},
      'ref': ref,
    });
  }

  test('emits nothing when the socket is not connected', () async {
    await client.sendHeartbeat();
    await pumpEventQueue();

    expect(statuses, isEmpty);
  });

  test('emits sent when a heartbeat is pushed', () async {
    await client.connect();

    await client.sendHeartbeat();
    await pumpEventQueue();

    expect(statuses, [RealtimeHeartbeatStatus.sent]);
    expect(client.pendingHeartbeatRef, isNotNull);
  });

  test(
    'emits timeout when the previous heartbeat was not acknowledged',
    () async {
      await client.connect();
      await client.sendHeartbeat();

      await client.sendHeartbeat();
      await pumpEventQueue();

      expect(statuses, [
        RealtimeHeartbeatStatus.sent,
        RealtimeHeartbeatStatus.timeout,
      ]);
      expect(client.pendingHeartbeatRef, isNull);
    },
  );

  test('emits ok when the heartbeat reply succeeds', () async {
    await client.connect();
    await client.sendHeartbeat();

    client.onConnectionMessage(
      heartbeatReply(client.pendingHeartbeatRef, 'ok'),
    );
    await pumpEventQueue();

    expect(statuses, [
      RealtimeHeartbeatStatus.sent,
      RealtimeHeartbeatStatus.ok,
    ]);
    expect(client.pendingHeartbeatRef, isNull);
  });

  test('emits error when the heartbeat reply fails', () async {
    await client.connect();
    await client.sendHeartbeat();

    client.onConnectionMessage(
      heartbeatReply(client.pendingHeartbeatRef, 'error'),
    );
    await pumpEventQueue();

    expect(statuses, [
      RealtimeHeartbeatStatus.sent,
      RealtimeHeartbeatStatus.error,
    ]);
  });

  test(
    'does not emit for messages that are not the pending heartbeat',
    () async {
      await client.connect();
      await client.sendHeartbeat();

      client.onConnectionMessage(heartbeatReply('other-ref', 'ok'));
      await pumpEventQueue();

      expect(statuses, [RealtimeHeartbeatStatus.sent]);
    },
  );
}
