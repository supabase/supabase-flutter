import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('decode', () {
    test('reads infinity and -infinity as the extreme instants', () {
      expect(postgresTimestamp.decode('infinity'), postgresTimestamp.infinity);
      expect(
        postgresTimestamp.decode('-infinity'),
        postgresTimestamp.negativeInfinity,
      );
      expect(
        postgresTimestamp.infinity,
        DateTime.fromMillisecondsSinceEpoch(8640000000000000, isUtc: true),
      );
    });

    test('reads any other value with DateTime.parse', () {
      expect(
        postgresTimestamp.decode('2024-02-29T12:00:00+00:00'),
        DateTime.utc(2024, 2, 29, 12),
      );
      expect(
        () => postgresTimestamp.decode('tomorrow'),
        throwsFormatException,
      );
    });
  });

  group('encode', () {
    test('writes the extreme instants as infinity and -infinity', () {
      final infinity = postgresTimestamp.decode('infinity');
      final negativeInfinity = postgresTimestamp.decode('-infinity');

      expect(postgresTimestamp.encode(infinity), 'infinity');
      expect(postgresTimestamp.encode(negativeInfinity), '-infinity');
    });

    test('writes any other value in ISO 8601', () {
      expect(
        postgresTimestamp.encode(DateTime.utc(2024, 2, 29, 12)),
        '2024-02-29T12:00:00.000Z',
      );
    });
  });
}
