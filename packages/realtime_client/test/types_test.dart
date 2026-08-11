import 'package:realtime_client/realtime_client.dart';
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
}
