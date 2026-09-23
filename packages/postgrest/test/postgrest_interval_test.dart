import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

void main() {
  group('construction', () {
    test('folds the components into months, days and microseconds', () {
      const interval = PostgrestInterval(
        years: 1,
        months: 2,
        weeks: 1,
        days: 3,
        hours: 4,
        minutes: 5,
        seconds: 6,
        milliseconds: 7,
        microseconds: 8,
      );

      expect(interval.months, 14);
      expect(interval.days, 10);
      expect(
        interval.microseconds,
        4 * Duration.microsecondsPerHour +
            5 * Duration.microsecondsPerMinute +
            6 * Duration.microsecondsPerSecond +
            7 * Duration.microsecondsPerMillisecond +
            8,
      );
    });

    test('fromDuration keeps the whole span as clock time', () {
      final interval = PostgrestInterval.fromDuration(
        const Duration(days: 2, hours: 3),
      );

      expect(interval.months, 0);
      expect(interval.days, 0);
      expect(interval.microseconds, 51 * Duration.microsecondsPerHour);
      expect(interval.literal, '51:00:00');
    });

    test('zero has no length', () {
      expect(PostgrestInterval.zero, const PostgrestInterval());
      expect(PostgrestInterval.zero.literal, '00:00:00');
    });
  });

  group('literal', () {
    test('renders the postgres style Postgres emits', () {
      expect(
        const PostgrestInterval(
          years: 1,
          months: 2,
          days: 3,
          hours: 4,
          minutes: 5,
          seconds: 6,
          milliseconds: 789,
        ).literal,
        '1 year 2 mons 3 days 04:05:06.789',
      );
      expect(const PostgrestInterval(months: 1).literal, '1 mon');
      expect(const PostgrestInterval(months: 26).literal, '2 years 2 mons');
      expect(const PostgrestInterval(days: 1).literal, '1 day');
      expect(const PostgrestInterval(hours: 100).literal, '100:00:00');
      expect(
        const PostgrestInterval(microseconds: 1).literal,
        '00:00:00.000001',
      );
      expect(const PostgrestInterval(seconds: 90).literal, '00:01:30');
    });

    test('signs each part the way Postgres does', () {
      expect(const PostgrestInterval(years: -1).literal, '-1 years');
      expect(
        const PostgrestInterval(
          years: -1,
          months: -2,
          days: 3,
          hours: -4,
        ).literal,
        '-1 years -2 mons +3 days -04:00:00',
      );
      expect(
        const PostgrestInterval(days: -1, hours: 4).literal,
        '-1 days +04:00:00',
      );
      expect(
        const PostgrestInterval(months: 1, seconds: -1).literal,
        '1 mon -00:00:01',
      );
      expect(
        const PostgrestInterval(days: -3, minutes: -30).literal,
        '-3 days -00:30:00',
      );
    });

    test('toString is the literal', () {
      expect('${const PostgrestInterval(days: 2)}', '2 days');
    });
  });

  group('parse', () {
    test('reads the postgres style', () {
      expect(
        PostgrestInterval.parse('1 year 2 mons 3 days 04:05:06.789'),
        const PostgrestInterval(
          years: 1,
          months: 2,
          days: 3,
          hours: 4,
          minutes: 5,
          seconds: 6,
          milliseconds: 789,
        ),
      );
      expect(
        PostgrestInterval.parse('1 mon'),
        const PostgrestInterval(months: 1),
      );
      expect(PostgrestInterval.parse('00:00:00'), PostgrestInterval.zero);
      expect(
        PostgrestInterval.parse('-1 years -2 mons +3 days -04:05:06'),
        const PostgrestInterval(
          years: -1,
          months: -2,
          days: 3,
          hours: -4,
          minutes: -5,
          seconds: -6,
        ),
      );
      expect(
        PostgrestInterval.parse('100:00:00'),
        const PostgrestInterval(hours: 100),
      );
    });

    test('reads the postgres_verbose style', () {
      expect(
        PostgrestInterval.parse(
          '@ 1 year 2 mons 3 days 4 hours 5 mins 6.5 secs',
        ),
        const PostgrestInterval(
          years: 1,
          months: 2,
          days: 3,
          hours: 4,
          minutes: 5,
          seconds: 6,
          milliseconds: 500,
        ),
      );
      expect(
        PostgrestInterval.parse('@ 1 day 2 hours ago'),
        const PostgrestInterval(days: -1, hours: -2),
      );
      expect(PostgrestInterval.parse('@ 0'), PostgrestInterval.zero);
    });

    test('reads the sql_standard style', () {
      expect(
        PostgrestInterval.parse('+1-2 +3 +4:05:06.789'),
        const PostgrestInterval(
          years: 1,
          months: 2,
          days: 3,
          hours: 4,
          minutes: 5,
          seconds: 6,
          milliseconds: 789,
        ),
      );
      expect(
        PostgrestInterval.parse('-1-2 -3 -4:05:06'),
        const PostgrestInterval(
          years: -1,
          months: -2,
          days: -3,
          hours: -4,
          minutes: -5,
          seconds: -6,
        ),
      );
      expect(
        PostgrestInterval.parse('1-2'),
        const PostgrestInterval(years: 1, months: 2),
      );
      expect(PostgrestInterval.parse('3'), const PostgrestInterval(days: 3));
      expect(PostgrestInterval.parse('0'), PostgrestInterval.zero);
      expect(
        PostgrestInterval.parse('4:05'),
        const PostgrestInterval(hours: 4, minutes: 5),
      );
    });

    test('a single leading sign in the sql_standard style covers every '
        'field', () {
      expect(
        PostgrestInterval.parse('-3 4:05:06'),
        const PostgrestInterval(days: -3, hours: -4, minutes: -5, seconds: -6),
      );
      expect(
        PostgrestInterval.parse('-1-2'),
        const PostgrestInterval(years: -1, months: -2),
      );
      expect(
        PostgrestInterval.parse('-4:05:06.5'),
        const PostgrestInterval(
          hours: -4,
          minutes: -5,
          seconds: -6,
          milliseconds: -500,
        ),
      );
      expect(
        PostgrestInterval.parse('-3 4:05:06').literal,
        '-3 days -04:05:06',
      );
    });

    test('reads the iso_8601 style', () {
      expect(
        PostgrestInterval.parse('P1Y2M3DT4H5M6.789S'),
        const PostgrestInterval(
          years: 1,
          months: 2,
          days: 3,
          hours: 4,
          minutes: 5,
          seconds: 6,
          milliseconds: 789,
        ),
      );
      expect(PostgrestInterval.parse('PT0S'), PostgrestInterval.zero);
      expect(PostgrestInterval.parse('P2W'), const PostgrestInterval(weeks: 2));
      expect(
        PostgrestInterval.parse('P-1Y-2M3DT-4H'),
        const PostgrestInterval(years: -1, months: -2, days: 3, hours: -4),
      );
      expect(
        PostgrestInterval.parse('PT-0.5S'),
        const PostgrestInterval(milliseconds: -500),
      );
    });

    test('reads spelled out units', () {
      expect(
        PostgrestInterval.parse('3 hours 30 minutes'),
        const PostgrestInterval(hours: 3, minutes: 30),
      );
      expect(
        PostgrestInterval.parse('2 weeks 1 month 250 milliseconds'),
        const PostgrestInterval(months: 1, weeks: 2, milliseconds: 250),
      );
    });

    test('rejects what is not an interval', () {
      for (final literal in [
        '',
        'P',
        'PT',
        '1 fortnight',
        '1.5 days',
        '1 day 2',
        'ago',
        '1 mon,2 days',
        '5 6',
        '1-2 3-4',
        '4:05 6:07',
        'P1YT',
        '1.5',
      ]) {
        expect(
          () => PostgrestInterval.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });

    test('round trips every postgres style literal', () {
      for (final literal in [
        '00:00:00',
        '1 mon',
        '1 year 2 mons 3 days 04:05:06.789',
        '-1 years -2 mons +3 days -04:05:06',
        '-1 days +04:00:00',
        '100:00:00',
        '00:00:00.000001',
      ]) {
        expect(PostgrestInterval.parse(literal).literal, literal);
      }
    });
  });

  group('toDuration', () {
    test('counts a year as 365.25 days and a month as 30', () {
      expect(
        const PostgrestInterval(years: 1).toDuration(),
        const Duration(days: 365, hours: 6),
      );
      expect(
        const PostgrestInterval(months: 1).toDuration(),
        const Duration(days: 30),
      );
      expect(
        const PostgrestInterval(months: 14, days: 3, hours: 4).toDuration(),
        const Duration(days: 365 + 60 + 3, hours: 6 + 4),
      );
      expect(
        const PostgrestInterval(months: -13).toDuration(),
        -const Duration(days: 365 + 30, hours: 6),
      );
    });
  });

  group('ordering', () {
    test('counts a month as 30 days and a day as 24 hours', () {
      expect(
        const PostgrestInterval(months: 1).compareTo(
          const PostgrestInterval(days: 30),
        ),
        0,
      );
      expect(
        const PostgrestInterval(days: 31).compareTo(
          const PostgrestInterval(months: 1),
        ),
        greaterThan(0),
      );
      expect(
        const PostgrestInterval(hours: 23).compareTo(
          const PostgrestInterval(days: 1),
        ),
        lessThan(0),
      );
      expect(
        [
          const PostgrestInterval(days: 1),
          const PostgrestInterval(hours: -1),
          const PostgrestInterval(months: 1),
          PostgrestInterval.zero,
        ]..sort(),
        [
          const PostgrestInterval(hours: -1),
          PostgrestInterval.zero,
          const PostgrestInterval(days: 1),
          const PostgrestInterval(months: 1),
        ],
      );
    });
  });

  test('equal intervals hash alike', () {
    expect(
      const PostgrestInterval(years: 1, months: 2),
      const PostgrestInterval(months: 14),
    );
    expect(
      const PostgrestInterval(days: 30),
      isNot(const PostgrestInterval(months: 1)),
    );
    expect(
      const PostgrestInterval(hours: 1).hashCode,
      PostgrestInterval.parse('01:00:00').hashCode,
    );
  });
}
