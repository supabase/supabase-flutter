import 'dart:collection';

import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

void main() {
  group('literal', () {
    test('renders HH:MM:SS with the fraction trimmed', () {
      expect(PostgrestTime(hour: 9, minute: 30).literal, '09:30:00');
      expect(
        PostgrestTime(
          hour: 4,
          minute: 5,
          second: 6,
          microsecond: 789000,
        ).literal,
        '04:05:06.789',
      );
      expect(
        PostgrestTime(hour: 4, minute: 5, second: 6, microsecond: 1).literal,
        '04:05:06.000001',
      );
      expect(PostgrestTime(hour: 24).literal, '24:00:00');
    });

    test('renders the offset the way Postgres does', () {
      expect(
        PostgrestTime(hour: 9, offset: const Duration(hours: 2)).literal,
        '09:00:00+02',
      );
      expect(
        PostgrestTime(hour: 9, offset: const Duration(hours: -8)).literal,
        '09:00:00-08',
      );
      expect(
        PostgrestTime(
          hour: 9,
          offset: const Duration(hours: 5, minutes: 30),
        ).literal,
        '09:00:00+05:30',
      );
      expect(
        PostgrestTime(
          hour: 9,
          offset: const Duration(hours: -3, minutes: -30, seconds: -15),
        ).literal,
        '09:00:00-03:30:15',
      );
      expect(
        PostgrestTime(hour: 9, offset: Duration.zero).literal,
        '09:00:00+00',
      );
    });

    test('toString is the literal', () {
      expect('${PostgrestTime(hour: 9, minute: 30)}', '09:30:00');
    });
  });

  group('parse', () {
    test('reads the time literal Postgres emits', () {
      expect(
        PostgrestTime.parse('04:05:06.789'),
        PostgrestTime(hour: 4, minute: 5, second: 6, microsecond: 789000),
      );
      expect(
        PostgrestTime.parse('04:05:06.000001'),
        PostgrestTime(hour: 4, minute: 5, second: 6, microsecond: 1),
      );
      expect(PostgrestTime.parse('24:00:00'), PostgrestTime(hour: 24));
      expect(PostgrestTime.parse('09:30'), PostgrestTime(hour: 9, minute: 30));
    });

    test('reads the offset of a timetz literal', () {
      expect(
        PostgrestTime.parse('09:00:00+02'),
        PostgrestTime(hour: 9, offset: const Duration(hours: 2)),
      );
      expect(
        PostgrestTime.parse('09:00:00-08:30'),
        PostgrestTime(
          hour: 9,
          offset: const Duration(hours: -8, minutes: -30),
        ),
      );
      expect(
        PostgrestTime.parse('09:00:00+05:30:15'),
        PostgrestTime(
          hour: 9,
          offset: const Duration(hours: 5, minutes: 30, seconds: 15),
        ),
      );
      expect(
        PostgrestTime.parse('09:00:00+00'),
        PostgrestTime(hour: 9, offset: Duration.zero),
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
          () => PostgrestTime.parse(literal),
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
        expect(PostgrestTime.parse(literal).literal, literal);
      }
    });
  });

  group('construction', () {
    test('rejects components out of range', () {
      expect(() => PostgrestTime(hour: 25), throwsArgumentError);
      expect(() => PostgrestTime(hour: -1), throwsArgumentError);
      expect(() => PostgrestTime(hour: 24, minute: 1), throwsArgumentError);
      expect(() => PostgrestTime(hour: 9, minute: 60), throwsArgumentError);
      expect(() => PostgrestTime(hour: 9, second: 60), throwsArgumentError);
      expect(
        () => PostgrestTime(hour: 9, microsecond: 1000000),
        throwsArgumentError,
      );
    });

    test('rejects an offset Postgres would not store', () {
      expect(
        () => PostgrestTime(hour: 9, offset: const Duration(hours: 16)),
        throwsArgumentError,
      );
      expect(
        () => PostgrestTime(hour: 9, offset: const Duration(milliseconds: 1)),
        throwsArgumentError,
      );
      expect(
        PostgrestTime(
          hour: 9,
          offset: const Duration(hours: 15, minutes: 59, seconds: 59),
        ).offset,
        const Duration(hours: 15, minutes: 59, seconds: 59),
      );
    });

    test('fromDateTime keeps the wall clock time', () {
      expect(
        PostgrestTime.fromDateTime(DateTime.utc(2024, 2, 29, 4, 5, 6, 789, 1)),
        PostgrestTime(hour: 4, minute: 5, second: 6, microsecond: 789001),
      );
      expect(PostgrestTime.fromDateTime(DateTime(2024, 2, 29)).offset, isNull);
    });
  });

  group('ordering', () {
    test('compares by the UTC instant of the day', () {
      final nineAtPlusOne = PostgrestTime(
        hour: 9,
        offset: const Duration(hours: 1),
      );
      final eightUtc = PostgrestTime(hour: 8, offset: Duration.zero);
      final tenUtc = PostgrestTime(hour: 10, offset: Duration.zero);

      expect(nineAtPlusOne.compareTo(eightUtc), greaterThan(0));
      expect(eightUtc.compareTo(nineAtPlusOne), lessThan(0));
      expect(nineAtPlusOne.compareTo(tenUtc), lessThan(0));
      expect(tenUtc.compareTo(nineAtPlusOne), greaterThan(0));
      expect(
        PostgrestTime(hour: 9, minute: 30).compareTo(PostgrestTime(hour: 9)),
        greaterThan(0),
      );
    });

    test('a plain time sorts before the same instant with an offset', () {
      final plain = PostgrestTime(hour: 9);
      final utc = PostgrestTime(hour: 9, offset: Duration.zero);

      expect(plain.compareTo(utc), lessThan(0));
      expect(utc.compareTo(plain), greaterThan(0));
      expect(plain.compareTo(PostgrestTime(hour: 9)), 0);
    });

    test('distinct times never compare equal', () {
      final times = SplayTreeSet<PostgrestTime>()
        ..add(PostgrestTime(hour: 9, offset: const Duration(hours: 1)))
        ..add(PostgrestTime(hour: 8, offset: Duration.zero))
        ..add(PostgrestTime(hour: 8));

      expect(times.length, 3);
    });

    test('equality takes the offset into account', () {
      expect(
        PostgrestTime(hour: 9, offset: const Duration(hours: 1)),
        isNot(PostgrestTime(hour: 8, offset: Duration.zero)),
      );
      expect(
        PostgrestTime(hour: 9),
        isNot(PostgrestTime(hour: 9, offset: Duration.zero)),
      );
      expect(
        PostgrestTime(hour: 9, minute: 30).hashCode,
        PostgrestTime.parse('09:30:00').hashCode,
      );
    });
  });
}
