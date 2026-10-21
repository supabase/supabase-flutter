import 'dart:collection';

import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('literal', () {
    test('renders HH:MM:SS with the fraction trimmed', () {
      expect(PostgresTime(hour: 9, minute: 30).literal, '09:30:00');
      expect(
        PostgresTime(
          hour: 4,
          minute: 5,
          second: 6,
          microsecond: 789000,
        ).literal,
        '04:05:06.789',
      );
      expect(
        PostgresTime(hour: 4, minute: 5, second: 6, microsecond: 1).literal,
        '04:05:06.000001',
      );
      expect(PostgresTime(hour: 24).literal, '24:00:00');
    });

    test('renders the offset the way Postgres does', () {
      expect(
        PostgresTime(hour: 9, offset: const Duration(hours: 2)).literal,
        '09:00:00+02',
      );
      expect(
        PostgresTime(hour: 9, offset: const Duration(hours: -8)).literal,
        '09:00:00-08',
      );
      expect(
        PostgresTime(
          hour: 9,
          offset: const Duration(hours: 5, minutes: 30),
        ).literal,
        '09:00:00+05:30',
      );
      expect(
        PostgresTime(
          hour: 9,
          offset: const Duration(hours: -3, minutes: -30, seconds: -15),
        ).literal,
        '09:00:00-03:30:15',
      );
      expect(
        PostgresTime(hour: 9, offset: Duration.zero).literal,
        '09:00:00+00',
      );
    });

    test('toString is the literal', () {
      expect('${PostgresTime(hour: 9, minute: 30)}', '09:30:00');
    });
  });

  group('parse', () {
    test('reads the time literal Postgres emits', () {
      expect(
        PostgresTime.parse('04:05:06.789'),
        PostgresTime(hour: 4, minute: 5, second: 6, microsecond: 789000),
      );
      expect(
        PostgresTime.parse('04:05:06.000001'),
        PostgresTime(hour: 4, minute: 5, second: 6, microsecond: 1),
      );
      expect(PostgresTime.parse('24:00:00'), PostgresTime(hour: 24));
      expect(PostgresTime.parse('09:30'), PostgresTime(hour: 9, minute: 30));
    });

    test('reads the offset of a timetz literal', () {
      expect(
        PostgresTime.parse('09:00:00+02'),
        PostgresTime(hour: 9, offset: const Duration(hours: 2)),
      );
      expect(
        PostgresTime.parse('09:00:00-08:30'),
        PostgresTime(
          hour: 9,
          offset: const Duration(hours: -8, minutes: -30),
        ),
      );
      expect(
        PostgresTime.parse('09:00:00+05:30:15'),
        PostgresTime(
          hour: 9,
          offset: const Duration(hours: 5, minutes: 30, seconds: 15),
        ),
      );
      expect(
        PostgresTime.parse('09:00:00+00'),
        PostgresTime(hour: 9, offset: Duration.zero),
      );
    });

    test('rejects what is not a time', () {
      for (final literal in [
        '',
        '9:30',
        '25:00:00',
        '24:00:01',
        '09:60:00',
        '09:30:60',
        '09:30:00.1234567',
        '09:30:00Z',
        '09:30:00+16',
        '2024-02-29T09:30:00',
      ]) {
        expect(
          () => PostgresTime.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });

    test('round trips every literal', () {
      for (final literal in [
        '00:00:00',
        '04:05:06.789',
        '24:00:00',
        '09:00:00+02',
        '09:00:00-08:30',
        '09:00:00+05:30:15',
      ]) {
        expect(PostgresTime.parse(literal).literal, literal);
      }
    });
  });

  group('construction', () {
    test('rejects components out of range', () {
      expect(() => PostgresTime(hour: 25), throwsArgumentError);
      expect(() => PostgresTime(hour: -1), throwsArgumentError);
      expect(() => PostgresTime(hour: 24, minute: 1), throwsArgumentError);
      expect(() => PostgresTime(hour: 9, minute: 60), throwsArgumentError);
      expect(() => PostgresTime(hour: 9, second: 60), throwsArgumentError);
      expect(
        () => PostgresTime(hour: 9, microsecond: 1000000),
        throwsArgumentError,
      );
    });

    test('rejects an offset Postgres would not store', () {
      expect(
        () => PostgresTime(hour: 9, offset: const Duration(hours: 16)),
        throwsArgumentError,
      );
      expect(
        () => PostgresTime(hour: 9, offset: const Duration(milliseconds: 1)),
        throwsArgumentError,
      );
      expect(
        PostgresTime(
          hour: 9,
          offset: const Duration(hours: 15, minutes: 59, seconds: 59),
        ).offset,
        const Duration(hours: 15, minutes: 59, seconds: 59),
      );
    });

    test('fromDateTime keeps the wall clock time', () {
      expect(
        PostgresTime.fromDateTime(DateTime.utc(2024, 2, 29, 4, 5, 6, 789, 1)),
        PostgresTime(hour: 4, minute: 5, second: 6, microsecond: 789001),
      );
      expect(PostgresTime.fromDateTime(DateTime(2024, 2, 29)).offset, isNull);
    });
  });

  group('ordering', () {
    test('the same instant sorts east of UTC first, like Postgres', () {
      final times = [
        PostgresTime(hour: 7, offset: const Duration(hours: -1)),
        PostgresTime(hour: 8, offset: Duration.zero),
        PostgresTime(hour: 9, offset: const Duration(hours: 1)),
      ]..sort();

      expect(times.map((time) => time.literal), [
        '09:00:00+01',
        '08:00:00+00',
        '07:00:00-01',
      ]);
    });

    test('compares by the UTC instant of the day', () {
      final nineAtPlusOne = PostgresTime(
        hour: 9,
        offset: const Duration(hours: 1),
      );
      final eightUtc = PostgresTime(hour: 8, offset: Duration.zero);
      final tenUtc = PostgresTime(hour: 10, offset: Duration.zero);

      expect(nineAtPlusOne.compareTo(eightUtc), lessThan(0));
      expect(eightUtc.compareTo(nineAtPlusOne), greaterThan(0));
      expect(nineAtPlusOne.compareTo(tenUtc), lessThan(0));
      expect(tenUtc.compareTo(nineAtPlusOne), greaterThan(0));
      expect(
        PostgresTime(hour: 9, minute: 30).compareTo(PostgresTime(hour: 9)),
        greaterThan(0),
      );
    });

    test('a plain time sorts before the same instant with an offset', () {
      final plain = PostgresTime(hour: 9);
      final utc = PostgresTime(hour: 9, offset: Duration.zero);

      expect(plain.compareTo(utc), lessThan(0));
      expect(utc.compareTo(plain), greaterThan(0));
      expect(plain.compareTo(PostgresTime(hour: 9)), 0);
    });

    test('distinct times never compare equal', () {
      final times = SplayTreeSet<PostgresTime>()
        ..add(PostgresTime(hour: 9, offset: const Duration(hours: 1)))
        ..add(PostgresTime(hour: 8, offset: Duration.zero))
        ..add(PostgresTime(hour: 8));

      expect(times.length, 3);
    });

    test('equality takes the offset into account', () {
      expect(
        PostgresTime(hour: 9, offset: const Duration(hours: 1)),
        isNot(PostgresTime(hour: 8, offset: Duration.zero)),
      );
      expect(
        PostgresTime(hour: 9),
        isNot(PostgresTime(hour: 9, offset: Duration.zero)),
      );
      expect(
        PostgresTime(hour: 9, minute: 30).hashCode,
        PostgresTime.parse('09:30:00').hashCode,
      );
    });
  });
}
