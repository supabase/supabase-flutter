import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:test/test.dart';

Map<String, dynamic> payloadWith(Object? commitTimestamp) => {
  'schema': 'public',
  'table': 'messages',
  'commit_timestamp': commitTimestamp,
  'eventType': 'INSERT',
  'new': {'id': 1},
  'old': <String, dynamic>{},
  'errors': null,
};

void main() {
  group('PostgresChangePayload.fromPayload', () {
    test('parses a commit timestamp as UTC', () {
      final payload = PostgresChangePayload.fromPayload(
        payloadWith('2022-09-21T04:59:30Z'),
      );

      expect(payload.commitTimestamp, DateTime.utc(2022, 9, 21, 4, 59, 30));
      expect(payload.commitTimestamp.isUtc, isTrue);
    });

    test('normalizes a commit timestamp with an offset to UTC', () {
      final payload = PostgresChangePayload.fromPayload(
        payloadWith('2022-09-21T06:59:30+02:00'),
      );

      expect(payload.commitTimestamp, DateTime.utc(2022, 9, 21, 4, 59, 30));
      expect(payload.commitTimestamp.isUtc, isTrue);
    });

    test('decodes an unrecognized event type as unknown', () {
      final payload = PostgresChangePayload.fromPayload({
        ...payloadWith('2022-09-21T04:59:30Z'),
        'eventType': 'TRUNCATE',
      });

      expect(payload.eventType, PostgresChangeEvent.unknown);
    });

    test('falls back to the UTC epoch when the timestamp is missing', () {
      final payload = PostgresChangePayload.fromPayload(payloadWith(null));

      expect(payload.commitTimestamp, DateTime.utc(1970));
      expect(payload.commitTimestamp.isUtc, isTrue);
    });

    test('falls back to the UTC epoch when the timestamp is malformed', () {
      final payload = PostgresChangePayload.fromPayload(
        payloadWith('not a timestamp'),
      );

      expect(payload.commitTimestamp, DateTime.utc(1970));
      expect(payload.commitTimestamp.isUtc, isTrue);
    });

    test('falls back to the UTC epoch when the timestamp is not a string', () {
      // Casting this to String? raised a TypeError, which the FormatException
      // fallback around the parse does not catch.
      final payload = PostgresChangePayload.fromPayload(
        payloadWith(1663764570),
      );

      expect(payload.commitTimestamp, DateTime.utc(1970));
      expect(payload.commitTimestamp.isUtc, isTrue);
    });
  });

  group('malformed payloads', () {
    Matcher throwsFormatExceptionNaming(String key) => throwsA(
      isA<FormatException>().having(
        (error) => error.message,
        'message',
        contains('"$key"'),
      ),
    );

    test('a postgres change with a non-string table throws', () {
      expect(
        () => PostgresChangePayload.fromPayload({
          ...payloadWith('2022-09-21T04:59:30Z'),
          'table': 42,
        }),
        throwsFormatExceptionNaming('table'),
      );
    });

    test('a postgres change without an event type throws', () {
      expect(
        () => PostgresChangePayload.fromPayload({
          ...payloadWith('2022-09-21T04:59:30Z'),
          'eventType': null,
        }),
        throwsFormatExceptionNaming('eventType'),
      );
    });

    test('a presence join with a non-string key throws', () {
      expect(
        () => RealtimePresenceJoinPayload.fromJson({
          'event': 'join',
          'key': 1,
          'newPresences': <Presence>[],
          'currentPresences': <Presence>[],
        }),
        throwsFormatExceptionNaming('key'),
      );
    });

    test('a presence leave without left presences throws', () {
      expect(
        () => RealtimePresenceLeavePayload.fromJson({
          'event': 'leave',
          'key': 'user',
          'currentPresences': <Presence>[],
        }),
        throwsFormatExceptionNaming('leftPresences'),
      );
    });

    test('a presence payload without an event throws', () {
      expect(
        () => RealtimePresenceSyncPayload.fromJson({}),
        throwsFormatExceptionNaming('event'),
      );
    });

    test('a presence with a non-string reference throws', () {
      expect(
        () => Presence.fromJson({'presence_ref': 1}),
        throwsFormatExceptionNaming('presence_ref'),
      );
    });
  });

  group('PostgresChangePayload equality', () {
    test('equal payloads with distinct maps share a hash code', () {
      final first = PostgresChangePayload.fromPayload(
        payloadWith('2026-06-15T00:00:00Z'),
      );
      final second = PostgresChangePayload.fromPayload(
        payloadWith('2026-06-15T00:00:00Z'),
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect({first, second}, hasLength(1));
    });
  });

  group('RealtimePresencePayload', () {
    test('decodes an unrecognized event as unknown', () {
      final payload = RealtimePresenceSyncPayload.fromJson({
        'event': 'resync',
      });

      expect(payload.event, PresenceEvent.unknown);
    });
  });
}
