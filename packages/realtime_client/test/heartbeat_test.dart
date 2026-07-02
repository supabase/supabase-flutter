import 'dart:convert';

import 'package:realtime_client/realtime_client.dart';
import 'package:test/test.dart';

void main() {
  late RealtimeClient client;
  late List<RealtimeHeartbeatStatus> statuses;

  setUp(() {
    client = RealtimeClient(
      'wss://localhost:0/',
      decode: (rawMessage) =>
          Map<String, dynamic>.from(jsonDecode(rawMessage as String) as Map),
    );
    statuses = [];
    client.onHeartbeat(statuses.add);
  });

  String heartbeatReply(String ref, String status) {
    return jsonEncode({
      'topic': 'phoenix',
      'event': 'phoenix_reply',
      'payload': {'status': status, 'response': <String, dynamic>{}},
      'ref': ref,
    });
  }

  test('emits disconnected when the socket is not connected', () async {
    await client.sendHeartbeat();

    expect(statuses, [RealtimeHeartbeatStatus.disconnected]);
  });

  test('emits sent when a heartbeat is pushed', () async {
    client.connState = SocketStates.open;

    await client.sendHeartbeat();

    expect(statuses, [RealtimeHeartbeatStatus.sent]);
    expect(client.pendingHeartbeatRef, isNotNull);
  });

  test('emits timeout when the previous heartbeat was not acknowledged',
      () async {
    client.connState = SocketStates.open;
    client.pendingHeartbeatRef = 'stale-ref';

    await client.sendHeartbeat();

    expect(statuses, [RealtimeHeartbeatStatus.timeout]);
    expect(client.pendingHeartbeatRef, isNull);
  });

  test('emits ok when the heartbeat reply succeeds', () {
    client.pendingHeartbeatRef = 'ref-1';

    client.onConnMessage(heartbeatReply('ref-1', 'ok'));

    expect(statuses, [RealtimeHeartbeatStatus.ok]);
    expect(client.pendingHeartbeatRef, isNull);
  });

  test('emits error when the heartbeat reply fails', () {
    client.pendingHeartbeatRef = 'ref-2';

    client.onConnMessage(heartbeatReply('ref-2', 'error'));

    expect(statuses, [RealtimeHeartbeatStatus.error]);
  });

  test('does not emit for messages that are not the pending heartbeat', () {
    client.pendingHeartbeatRef = 'ref-3';

    client.onConnMessage(heartbeatReply('other-ref', 'ok'));

    expect(statuses, isEmpty);
  });
}
