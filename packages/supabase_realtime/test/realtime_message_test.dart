import 'dart:typed_data';

import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_realtime/src/constants.dart';
import 'package:supabase_realtime/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('outgoing', () {
    test('names a heartbeat without the phx prefix', () {
      final message = RealtimeMessage.outgoing(
        topic: 'phoenix',
        event: ChannelEvent.heartbeat,
        payload: <String, dynamic>{},
        ref: '1',
      );

      expect(message.event, 'heartbeat');
      expect(message.topic, 'phoenix');
      expect(message.ref, '1');
      expect(message.joinRef, isNull);
    });

    test('names every other event as the server expects it', () {
      final message = RealtimeMessage.outgoing(
        topic: 'realtime:room',
        event: ChannelEvent.join,
        payload: {'user_id': '123'},
        joinRef: 'join-456',
      );

      expect(message.event, 'phx_join');
      expect(message.payload, {'user_id': '123'});
      expect(message.joinRef, 'join-456');
      expect(message.ref, isNull);
    });

    test('replaces a nested binding with its serializable shape', () {
      final binding = Binding('postgres_changes', {'event': '*'}, (_, [_]) {});
      final message = RealtimeMessage.outgoing(
        topic: 'realtime:room',
        event: ChannelEvent.join,
        payload: {
          'config': {'postgres_changes': binding},
        },
      );

      expect(message.payload, {
        'config': {
          'postgres_changes': {
            'type': 'postgres_changes',
            'filter': {'event': '*'},
          },
        },
      });
    });

    test('preserves a nested empty map', () {
      final message = RealtimeMessage.outgoing(
        topic: 'realtime:room',
        event: ChannelEvent.presence,
        payload: {'event': 'track', 'payload': <String, dynamic>{}},
      );

      expect(message.payload, {'event': 'track', 'payload': {}});
    });

    test('leaves a binary payload as Uint8List', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final message = RealtimeMessage.outgoing(
        topic: 'realtime:room',
        event: ChannelEvent.broadcast,
        payload: {'type': 'broadcast', 'event': 'file', 'payload': bytes},
      );

      expect((message.payload as Map)['payload'], isA<Uint8List>());
      expect((message.payload as Map)['payload'], same(bytes));
    });

    test('replaces a binding nested inside a list', () {
      final binding = Binding('postgres_changes', {'event': '*'}, (_, [_]) {});
      final message = RealtimeMessage.outgoing(
        topic: 'realtime:room',
        event: ChannelEvent.join,
        payload: {
          'config': {
            'postgres_changes': [binding],
          },
        },
      );

      expect(message.payload, {
        'config': {
          'postgres_changes': [
            {
              'type': 'postgres_changes',
              'filter': {'event': '*'},
            },
          ],
        },
      });
    });

    test('replaces a binding nested three levels deep', () {
      final binding = Binding('postgres_changes', {'event': '*'}, (_, [_]) {});
      final message = RealtimeMessage.outgoing(
        topic: 'realtime:room',
        event: ChannelEvent.join,
        payload: {
          'config': {
            'postgres_changes': {'0': binding},
          },
        },
      );

      expect(message.payload, {
        'config': {
          'postgres_changes': {
            '0': {
              'type': 'postgres_changes',
              'filter': {'event': '*'},
            },
          },
        },
      });
    });
  });

  group('toJson', () {
    test('lays the fields out positionally for 2.0.0', () {
      const message = RealtimeMessage(
        topic: 'realtime:room',
        event: 'phx_join',
        payload: {'foo': 'bar'},
        ref: '2',
        joinRef: '1',
      );

      expect(message.toJson(), [
        '1',
        '2',
        'realtime:room',
        'phx_join',
        {'foo': 'bar'},
      ]);
    });

    test('keeps missing references positional for 2.0.0', () {
      const message = RealtimeMessage(
        topic: 'phoenix',
        event: 'heartbeat',
        payload: <String, dynamic>{},
      );

      expect(message.toJson(), [null, null, 'phoenix', 'heartbeat', {}]);
    });
  });

  group('fromJson', () {
    test('reads a positional 2.0.0 frame', () {
      final message = RealtimeMessage.fromJson([
        '1',
        '2',
        'realtime:room',
        'phx_reply',
        {'status': 'ok'},
      ]);

      expect(message.joinRef, '1');
      expect(message.ref, '2');
      expect(message.topic, 'realtime:room');
      expect(message.event, 'phx_reply');
      expect(message.payload, {'status': 'ok'});
    });

    test('throws when the frame is not a positional array', () {
      expect(
        () => RealtimeMessage.fromJson({'not': 'an array'}),
        throwsFormatException,
      );
      expect(
        () => RealtimeMessage.fromJson(['too', 'short']),
        throwsFormatException,
      );
    });

    test('throws a FormatException when a field has the wrong type', () {
      expect(
        () => RealtimeMessage.fromJson([
          '1',
          '2',
          'realtime:room',
          3,
          {'status': 'ok'},
        ]),
        throwsFormatException,
      );
      expect(
        () => RealtimeMessage.fromJson([
          1,
          '2',
          'realtime:room',
          'phx_reply',
          {'status': 'ok'},
        ]),
        throwsFormatException,
      );
    });

    test('round trips through toJson', () {
      const message = RealtimeMessage(
        topic: 'realtime:room',
        event: 'broadcast',
        payload: {'event': 'cursor'},
        ref: '2',
        joinRef: '1',
      );

      expect(RealtimeMessage.fromJson(message.toJson()), message);
    });
  });
}
