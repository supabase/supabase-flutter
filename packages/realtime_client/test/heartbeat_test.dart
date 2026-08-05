import 'dart:async';
import 'dart:convert';

import 'package:realtime_client/realtime_client.dart';
import 'package:test/test.dart';

void main() {
  late RealtimeClient client;
  late List<RealtimeHeartbeatStatus> statuses;
  late StreamSubscription<RealtimeHeartbeatStatus> subscription;

  setUp(() {
    client = RealtimeClient(
      'wss://localhost:0/',
      decode: (rawMessage) =>
          Map<String, dynamic>.from(jsonDecode(rawMessage as String) as Map),
    );
    statuses = [];
    subscription = client.onHeartbeat.listen(statuses.add);
  });

  tearDown(() async {
    await subscription.cancel();
  });

  String heartbeatReply(String ref, String status) {
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
    client.connectionStatus = SocketStates.open;

    await client.sendHeartbeat();
    await pumpEventQueue();

    expect(statuses, [RealtimeHeartbeatStatus.sent]);
    expect(client.pendingHeartbeatRef, isNotNull);
  });

  test(
    'emits timeout when the previous heartbeat was not acknowledged',
    () async {
      client.connectionStatus = SocketStates.open;
      client.pendingHeartbeatRef = 'stale-ref';

      await client.sendHeartbeat();
      await pumpEventQueue();

      expect(statuses, [RealtimeHeartbeatStatus.timeout]);
      expect(client.pendingHeartbeatRef, isNull);
    },
  );

  test('emits ok when the heartbeat reply succeeds', () async {
    client.pendingHeartbeatRef = 'ref-1';

    client.onConnectionMessage(heartbeatReply('ref-1', 'ok'));
    await pumpEventQueue();

    expect(statuses, [RealtimeHeartbeatStatus.ok]);
    expect(client.pendingHeartbeatRef, isNull);
  });

  test('emits error when the heartbeat reply fails', () async {
    client.pendingHeartbeatRef = 'ref-2';

    client.onConnectionMessage(heartbeatReply('ref-2', 'error'));
    await pumpEventQueue();

    expect(statuses, [RealtimeHeartbeatStatus.error]);
  });

  test(
    'does not emit for messages that are not the pending heartbeat',
    () async {
      client.pendingHeartbeatRef = 'ref-3';

      client.onConnectionMessage(heartbeatReply('other-ref', 'ok'));
      await pumpEventQueue();

      expect(statuses, isEmpty);
    },
  );
}
