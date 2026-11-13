import 'dart:convert';
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

    await channel.sendBinaryBroadcastMessage(event: 'file', bytes: bytes);
    await pumpEventQueue();

    final frame = frames.last;
    expect(frame, isA<Uint8List>());
    expect((frame as Uint8List).first, Serializer.kindUserBroadcastPush);
    expect(frame.sublist(frame.length - bytes.length), bytes);
  });

  test('receives a binary payload as bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final received = channel.onBroadcast(event: 'file').first;
    final topic = utf8.encode('realtime:room');
    final event = utf8.encode('file');

    client.onConnectionMessage(
      Uint8List.fromList([
        Serializer.kindUserBroadcast,
        topic.length,
        event.length,
        0,
        Serializer.binaryEncoding,
        ...topic,
        ...event,
        ...bytes,
      ]),
    );

    expect(
      await received,
      BroadcastMessage(event: 'file', payload: BinaryBroadcastPayload(bytes)),
    );
  });

  test('reads the id and replay flag from the meta of a broadcast', () async {
    final received = channel.onBroadcast(event: 'cursor').first;

    realtime.emit(
      RealtimeMessage(
        topic: 'realtime:room',
        event: 'broadcast',
        payload: {
          'type': 'broadcast',
          'event': 'cursor',
          'payload': {'x': 1},
          'meta': {'id': 'abc', 'replayed': true},
        },
      ),
    );

    expect(
      await received,
      const BroadcastMessage(
        event: 'cursor',
        payload: JsonBroadcastPayload({'x': 1}),
        id: 'abc',
        isReplayed: true,
      ),
    );
  });

  test('drops a broadcast without an event name', () async {
    final received = <BroadcastMessage>[];
    channel.onBroadcast(event: '*').listen(received.add);

    realtime.emit(
      RealtimeMessage(
        topic: 'realtime:room',
        event: 'broadcast',
        payload: {
          'type': 'broadcast',
          'payload': {'x': 1},
        },
      ),
    );
    await pumpEventQueue();

    expect(received, isEmpty);
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
      expect(messages.first.payload, const JsonBroadcastPayload({'x': 1}));
    },
  );

  group('v2 compatibility', () {
    Future<RealtimeChannel> subscribeV2CompatibleChannel() async {
      final compatibleChannel = client.channel(
        'v2-room',
        const RealtimeChannelConfig(v2BroadcastCompatibility: true),
      );
      final subscribed = compatibleChannel.onStatusChange.firstWhere(
        (change) => change.status == RealtimeSubscribeStatus.subscribed,
      );
      compatibleChannel.subscribe();
      await subscribed;
      return compatibleChannel;
    }

    test('moves the data of a v2 broadcast under payload', () async {
      final received = channel.onBroadcast(event: 'cursor').first;

      realtime.emit(
        RealtimeMessage(
          topic: 'realtime:room',
          event: 'broadcast',
          payload: {'type': 'broadcast', 'event': 'cursor', 'x': 1, 'y': 2},
        ),
      );

      expect(
        await received,
        const BroadcastMessage(
          event: 'cursor',
          payload: JsonBroadcastPayload({'x': 1, 'y': 2}),
        ),
      );
    });

    test('sends map data under payload and next to type and event', () async {
      final compatibleChannel = await subscribeV2CompatibleChannel();

      await compatibleChannel.sendBroadcastMessage(
        event: 'cursor',
        payload: {
          'x': 1,
          'type': 'pointer',
          'meta': 'note',
          'payload': 'nested',
          'ids': [1],
        },
      );

      expect(await lastSentBroadcast(), {
        'type': 'broadcast',
        'event': 'cursor',
        'x': 1,
        'payload': {
          'x': 1,
          'type': 'pointer',
          'meta': 'note',
          'payload': 'nested',
          'ids': [1],
        },
      });
    });

    test(
      'reads only the payload key of a v2 broadcast that has one',
      () async {
        final received = channel.onBroadcast(event: 'file').first;
        final message = {
          'type': 'broadcast',
          'event': 'file',
          'payload': [1, 2, 3],
          'name': 'a.bin',
        };

        realtime.emit(
          RealtimeMessage(
            topic: 'realtime:room',
            event: 'broadcast',
            payload: message,
          ),
        );

        expect(
          await received,
          const BroadcastMessage(
            event: 'file',
            payload: JsonBroadcastPayload([1, 2, 3]),
          ),
        );
      },
    );

    test('does not treat a broadcast with ids as a postgres change', () async {
      final received = channel.onBroadcast(event: 'selection').first;

      realtime.emit(
        RealtimeMessage(
          topic: 'realtime:room',
          event: 'broadcast',
          payload: {
            'type': 'broadcast',
            'event': 'selection',
            'ids': [1, 2],
          },
        ),
      );

      expect(
        await received,
        const BroadcastMessage(
          event: 'selection',
          payload: JsonBroadcastPayload({
            'ids': [1, 2],
          }),
        ),
      );
    });

    test('sends binary data as usual', () async {
      final compatibleChannel = await subscribeV2CompatibleChannel();
      final bytes = Uint8List.fromList([1, 2, 3]);

      await compatibleChannel.sendBinaryBroadcastMessage(
        event: 'file',
        bytes: bytes,
      );
      await pumpEventQueue();

      final frame = frames.last;
      expect(frame, isA<Uint8List>());
      expect((frame as Uint8List).first, Serializer.kindUserBroadcastPush);
    });

    test('a compatible broadcast is received like a regular one', () async {
      final compatibleChannel = await subscribeV2CompatibleChannel();
      final received = compatibleChannel.onBroadcast(event: 'cursor').first;

      await compatibleChannel.sendBroadcastMessage(
        event: 'cursor',
        payload: {'x': 1},
      );
      realtime.emit(
        RealtimeMessage(
          topic: 'realtime:v2-room',
          event: 'broadcast',
          payload: await lastSentBroadcast(),
        ),
      );

      expect((await received).payload, const JsonBroadcastPayload({'x': 1}));
    });
  });
}
