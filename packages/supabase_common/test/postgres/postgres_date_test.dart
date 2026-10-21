import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('literal', () {
    test('renders the ISO date Postgres emits', () {
      expect(PostgresDate(2024, 2, 29).literal, '2024-02-29');
      expect(PostgresDate(33, 1, 5).literal, '0033-01-05');
      expect(PostgresDate(12345, 12, 31).literal, '12345-12-31');
    });

    test('dates before year 1 carry the BC suffix', () {
      expect(PostgresDate(0, 3, 15).literal, '0001-03-15 BC');
      expect(PostgresDate(-43, 3, 15).literal, '0044-03-15 BC');
    });

    test('the infinite dates spell themselves', () {
      expect(PostgresDate.infinity.literal, 'infinity');
      expect(PostgresDate.negativeInfinity.literal, '-infinity');
    });

    test('toString is the literal', () {
      expect('${PostgresDate(2024, 2, 29)}', '2024-02-29');
    });
  });

  group('parse', () {
    test('reads the ISO date and the BC suffix', () {
      expect(PostgresDate.parse('2024-02-29'), PostgresDate(2024, 2, 29));
      expect(PostgresDate.parse(' 2024-02-29 '), PostgresDate(2024, 2, 29));
      expect(PostgresDate.parse('0044-03-15 BC'), PostgresDate(-43, 3, 15));
      expect(PostgresDate.parse('0001-01-01 BC'), PostgresDate(0, 1, 1));
    });

    test('reads the infinite dates', () {
      expect(PostgresDate.parse('infinity'), PostgresDate.infinity);
      expect(PostgresDate.parse('-infinity'), PostgresDate.negativeInfinity);
      expect(PostgresDate.parse('Infinity'), PostgresDate.infinity);
    });

    test('rejects what is not a date', () {
      for (final literal in [
        '',
        '2024-2-29',
        '2024-02-29T00:00:00',
        '2024-02-30',
        '2023-02-29',
        '2024-13-01',
        '0000-01-01 BC',
        'tomorrow',
      ]) {
        expect(
          () => PostgresDate.parse(literal),
          throwsFormatException,
          reason: literal,
        );
      }
    });

    test('round trips every literal', () {
      for (final literal in [
        '2024-02-29',
        '0044-03-15 BC',
        '12345-12-31',
        'infinity',
        '-infinity',
      ]) {
        expect(PostgresDate.parse(literal).literal, literal);
      }
    });
  });

  group('construction', () {
    test('rejects a day that does not exist', () {
      expect(() => PostgresDate(2023, 2, 29), throwsArgumentError);
      expect(() => PostgresDate(2024, 4, 31), throwsArgumentError);
      expect(() => PostgresDate(2024, 0, 1), throwsArgumentError);
      expect(() => PostgresDate(2024, 1, 0), throwsArgumentError);
      expect(PostgresDate(2000, 2, 29).day, 29);
      expect(() => PostgresDate(1900, 2, 29), throwsArgumentError);
    });

    test('fromDateTime keeps the date of the timezone the value carries', () {
      expect(
        PostgresDate.fromDateTime(DateTime.utc(2024, 2, 29, 23, 59)),
        PostgresDate(2024, 2, 29),
      );
      expect(
        PostgresDate.fromDateTime(DateTime(2024, 2, 29, 0, 30)),
        PostgresDate(2024, 2, 29),
      );
    });
  });

  group('components', () {
    test('are exposed for a finite date', () {
      final date = PostgresDate(2024, 2, 29);

      expect(date.year, 2024);
      expect(date.month, 2);
      expect(date.day, 29);
      expect(date.isFinite, isTrue);
      expect(date.isInfinite, isFalse);
    });

    test('throw for an infinite date', () {
      expect(PostgresDate.infinity.isFinite, isFalse);
      expect(PostgresDate.infinity.isInfinite, isTrue);
      expect(() => PostgresDate.infinity.year, throwsStateError);
      expect(() => PostgresDate.negativeInfinity.day, throwsStateError);
      expect(() => PostgresDate.infinity.toDateTime(), throwsStateError);
    });

    test('toDateTime is midnight, local or UTC', () {
      final date = PostgresDate(2024, 2, 29);

      expect(date.toDateTime(), DateTime(2024, 2, 29));
      expect(date.toDateTime(isUtc: true), DateTime.utc(2024, 2, 29));
    });
  });

  group('ordering', () {
    test('compares by calendar order with the infinities at the ends', () {
      final dates = [
        PostgresDate.infinity,
        PostgresDate(2024, 3, 1),
        PostgresDate(2024, 2, 29),
        PostgresDate.negativeInfinity,
        PostgresDate(-43, 3, 15),
        PostgresDate(2023, 12, 31),
      ]..sort();

      expect(dates, [
        PostgresDate.negativeInfinity,
        PostgresDate(-43, 3, 15),
        PostgresDate(2023, 12, 31),
        PostgresDate(2024, 2, 29),
        PostgresDate(2024, 3, 1),
        PostgresDate.infinity,
      ]);
      expect(
        PostgresDate.infinity.compareTo(PostgresDate.parse('infinity')),
        0,
      );
    });

    test('equal dates hash alike', () {
      expect(
        PostgresDate(2024, 2, 29).hashCode,
        PostgresDate.parse('2024-02-29').hashCode,
      );
      expect(PostgresDate(2024, 2, 29), isNot(PostgresDate(2024, 3, 1)));
      expect(PostgresDate.infinity, isNot(PostgresDate.negativeInfinity));
    });
  });
}
