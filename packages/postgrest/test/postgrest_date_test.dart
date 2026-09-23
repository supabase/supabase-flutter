import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

void main() {
  group('literal', () {
    test('renders the ISO date Postgres emits', () {
      expect(PostgrestDate(2024, 2, 29).literal, '2024-02-29');
      expect(PostgrestDate(33, 1, 5).literal, '0033-01-05');
      expect(PostgrestDate(12345, 12, 31).literal, '12345-12-31');
    });

    test('dates before year 1 carry the BC suffix', () {
      expect(PostgrestDate(0, 3, 15).literal, '0001-03-15 BC');
      expect(PostgrestDate(-43, 3, 15).literal, '0044-03-15 BC');
    });

    test('the infinite dates spell themselves', () {
      expect(PostgrestDate.infinity.literal, 'infinity');
      expect(PostgrestDate.negativeInfinity.literal, '-infinity');
    });

    test('toString is the literal', () {
      expect('${PostgrestDate(2024, 2, 29)}', '2024-02-29');
    });
  });

  group('parse', () {
    test('reads the ISO date and the BC suffix', () {
      expect(PostgrestDate.parse('2024-02-29'), PostgrestDate(2024, 2, 29));
      expect(PostgrestDate.parse(' 2024-02-29 '), PostgrestDate(2024, 2, 29));
      expect(PostgrestDate.parse('0044-03-15 BC'), PostgrestDate(-43, 3, 15));
      expect(PostgrestDate.parse('0001-01-01 BC'), PostgrestDate(0, 1, 1));
    });

    test('reads the infinite dates', () {
      expect(PostgrestDate.parse('infinity'), PostgrestDate.infinity);
      expect(PostgrestDate.parse('-infinity'), PostgrestDate.negativeInfinity);
      expect(PostgrestDate.parse('Infinity'), PostgrestDate.infinity);
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
          () => PostgrestDate.parse(literal),
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
        expect(PostgrestDate.parse(literal).literal, literal);
      }
    });
  });

  group('construction', () {
    test('rejects a day that does not exist', () {
      expect(() => PostgrestDate(2023, 2, 29), throwsArgumentError);
      expect(() => PostgrestDate(2024, 4, 31), throwsArgumentError);
      expect(() => PostgrestDate(2024, 0, 1), throwsArgumentError);
      expect(() => PostgrestDate(2024, 1, 0), throwsArgumentError);
      expect(PostgrestDate(2000, 2, 29).day, 29);
      expect(() => PostgrestDate(1900, 2, 29), throwsArgumentError);
    });

    test('fromDateTime keeps the date of the timezone the value carries', () {
      expect(
        PostgrestDate.fromDateTime(DateTime.utc(2024, 2, 29, 23, 59)),
        PostgrestDate(2024, 2, 29),
      );
      expect(
        PostgrestDate.fromDateTime(DateTime(2024, 2, 29, 0, 30)),
        PostgrestDate(2024, 2, 29),
      );
    });
  });

  group('components', () {
    test('are exposed for a finite date', () {
      final date = PostgrestDate(2024, 2, 29);

      expect(date.year, 2024);
      expect(date.month, 2);
      expect(date.day, 29);
      expect(date.isFinite, isTrue);
      expect(date.isInfinite, isFalse);
    });

    test('throw for an infinite date', () {
      expect(PostgrestDate.infinity.isFinite, isFalse);
      expect(PostgrestDate.infinity.isInfinite, isTrue);
      expect(() => PostgrestDate.infinity.year, throwsStateError);
      expect(() => PostgrestDate.negativeInfinity.day, throwsStateError);
      expect(() => PostgrestDate.infinity.toDateTime(), throwsStateError);
    });

    test('toDateTime is midnight, local or UTC', () {
      final date = PostgrestDate(2024, 2, 29);

      expect(date.toDateTime(), DateTime(2024, 2, 29));
      expect(date.toDateTime(isUtc: true), DateTime.utc(2024, 2, 29));
    });
  });

  group('ordering', () {
    test('compares by calendar order with the infinities at the ends', () {
      final dates = [
        PostgrestDate.infinity,
        PostgrestDate(2024, 3, 1),
        PostgrestDate(2024, 2, 29),
        PostgrestDate.negativeInfinity,
        PostgrestDate(-43, 3, 15),
        PostgrestDate(2023, 12, 31),
      ]..sort();

      expect(dates, [
        PostgrestDate.negativeInfinity,
        PostgrestDate(-43, 3, 15),
        PostgrestDate(2023, 12, 31),
        PostgrestDate(2024, 2, 29),
        PostgrestDate(2024, 3, 1),
        PostgrestDate.infinity,
      ]);
      expect(PostgrestDate.infinity.compareTo(PostgrestDate.infinity), 0);
    });

    test('equal dates hash alike', () {
      expect(
        PostgrestDate(2024, 2, 29).hashCode,
        PostgrestDate.parse('2024-02-29').hashCode,
      );
      expect(PostgrestDate(2024, 2, 29), isNot(PostgrestDate(2024, 3, 1)));
      expect(PostgrestDate.infinity, isNot(PostgrestDate.negativeInfinity));
    });
  });
}
