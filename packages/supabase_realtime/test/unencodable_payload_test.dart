import 'dart:convert';

import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  late MockRealtimeTransport realtime;
  late RealtimeClient client;
  late RealtimeChannel channel;

  Future<void> subscribe() async {
    final subscribed = channel.onStatusChange.firstWhere(
      (change) => change.status == RealtimeSubscribeStatus.subscribed,
    );
    channel.subscribe();
    await subscribed;
  }

  setUp(() {
    realtime = MockRealtimeTransport();
    client = RealtimeClient(
      'ws://localhost:54321/realtime/v1',
      transport: realtime.call,
    );
    addTearDown(client.disconnect);
    channel = client.channel('room');
  });

  List<RealtimeMessage> sentBroadcasts() =>
      realtime.sent.where((message) => message.event == 'broadcast').toList();

  test('a broadcast payload that cannot be encoded fails the send', () async {
    await subscribe();

    await expectLater(
      channel.sendBroadcastMessage(
        event: 'cursor',
        payload: {'at': DateTime(2026)},
      ),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );
    await pumpEventQueue();

    expect(sentBroadcasts(), isEmpty);
  });

  test('a broadcast with an acknowledgement fails the send too', () async {
    channel = client.channel(
      'room',
      const RealtimeChannelConfig(ack: true),
    );
    await subscribe();

    await expectLater(
      channel.sendBroadcastMessage(
        event: 'cursor',
        payload: {'at': DateTime(2026)},
      ),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );
  });

  test('fails the send before the channel is joined', () async {
    await expectLater(
      channel.sendBroadcastMessage(
        event: 'cursor',
        payload: {'at': DateTime(2026)},
      ),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );
  });

  test('a payload that can be encoded is still sent', () async {
    await subscribe();

    final response = await channel.sendBroadcastMessage(
      event: 'cursor',
      payload: {'x': 1},
    );
    await pumpEventQueue();

    expect(response, ChannelResponse.ok);
    expect(sentBroadcasts(), hasLength(1));
  });

  test('a custom encode still decides what can be encoded', () async {
    client = RealtimeClient(
      'ws://localhost:54321/realtime/v1',
      transport: realtime.call,
      encode: (message) async => jsonEncode(
        message.toJson(),
        toEncodable: (object) =>
            object is DateTime ? object.toIso8601String() : object,
      ),
    );
    addTearDown(client.disconnect);
    channel = client.channel('room');
    await subscribe();

    final response = await channel.sendBroadcastMessage(
      event: 'cursor',
      payload: {'at': DateTime(2026)},
    );

    expect(response, ChannelResponse.ok);
  });
}
