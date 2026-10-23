import 'dart:typed_data';

import 'package:supabase_realtime/src/serializer.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  late MockRealtimeTransport realtime;
  late List<Object> frames;
  late RealtimeClient client;
  late RealtimeChannel channel;

  setUp(() async {
    realtime = MockRealtimeTransport();
    frames = [];
    client = RealtimeClient(
      'ws://localhost:54321/realtime/v1',
      transport: realtime.call,
      encode: (message) async {
        final frame = const Serializer().encode(message);
        frames.add(frame);
        return frame;
      },
    );
    addTearDown(client.disconnect);
    channel = client.channel('room');
    final subscribed = channel.onStatusChange.firstWhere(
      (change) => change.status == RealtimeSubscribeStatus.subscribed,
    );
    channel.subscribe();
    await subscribed;
  });

  Future<Map<String, dynamic>> lastSentBroadcast() async {
    await pumpEventQueue();
    return realtime.sent
            .lastWhere((message) => message.event == 'broadcast')
            .payload
        as Map<String, dynamic>;
  }

  test('sends the payload under the payload key', () async {
    await channel.sendBroadcastMessage(event: 'cursor', payload: {'x': 1});

    expect(await lastSentBroadcast(), {
      'type': 'broadcast',
      'event': 'cursor',
      'payload': {'x': 1},
    });
  });

  test('accepts a const payload', () async {
    final status = await channel.sendBroadcastMessage(
      event: 'cursor',
      payload: const {'x': 1},
    );

    expect(status, ChannelResponse.ok);
    expect((await lastSentBroadcast())['payload'], {'x': 1});
  });

  test('accepts a payload with narrower value types', () async {
    final payload = {'x': 1};

    final status = await channel.sendBroadcastMessage(
      event: 'cursor',
      payload: payload,
    );

    expect(status, ChannelResponse.ok);
    expect((await lastSentBroadcast())['payload'], {'x': 1});
  });

  test('accepts a map without type arguments', () async {
    final status = await channel.sendBroadcastMessage(
      event: 'cursor',
      payload: Map<Object?, Object?>.from({'x': 1}),
    );

    expect(status, ChannelResponse.ok);
    expect((await lastSentBroadcast())['payload'], {'x': 1});
  });

  test('leaves the payload map of the caller unchanged', () async {
    final payload = <String, dynamic>{'x': 1};

    await channel.sendBroadcastMessage(event: 'cursor', payload: payload);
    await channel.sendBroadcastMessage(event: 'position', payload: payload);

    expect(payload, {'x': 1});
    expect(await lastSentBroadcast(), {
      'type': 'broadcast',
      'event': 'position',
      'payload': {'x': 1},
    });
  });

  test('sends a binary payload as a binary frame', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);

    await channel.sendBroadcastMessage(event: 'file', payload: bytes);
    await pumpEventQueue();

    final frame = frames.last;
    expect(frame, isA<Uint8List>());
    expect((frame as Uint8List).first, Serializer.kindUserBroadcastPush);
    expect(frame.sublist(frame.length - bytes.length), bytes);
  });

  test('rejects a payload that is neither a map nor binary', () async {
    await expectLater(
      channel.sendBroadcastMessage(event: 'cursor', payload: 'text'),
      throwsArgumentError,
    );
    await expectLater(
      channel.sendBroadcastMessage(event: 'cursor', payload: [1, 2]),
      throwsArgumentError,
    );
    await pumpEventQueue();

    expect(
      realtime.sent.where((message) => message.event == 'broadcast'),
      isEmpty,
    );
  });

  test('httpSend rejects a payload that is neither a map nor binary', () {
    return expectLater(
      channel.httpSend(event: 'cursor', payload: 'text'),
      throwsArgumentError,
    );
  });

  test(
    'a sent broadcast is received in the same shape as one from JavaScript',
    () async {
      final received = channel.onBroadcast(event: 'cursor').take(2).toList();

      await channel.sendBroadcastMessage(event: 'cursor', payload: {'x': 1});
      realtime.emit(
        RealtimeMessage(
          topic: 'realtime:room',
          event: 'broadcast',
          payload: await lastSentBroadcast(),
        ),
      );
      realtime.emit(
        RealtimeMessage(
          topic: 'realtime:room',
          event: 'broadcast',
          payload: {
            'type': 'broadcast',
            'event': 'cursor',
            'payload': {'x': 1},
          },
        ),
      );

      final messages = await received;
      expect(messages.first, messages.last);
      expect(messages.first['payload'], {'x': 1});
    },
  );
}
