import 'dart:typed_data';

import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('literal', () {
    test('renders a bytes bound as a hex bytea literal', () {
      expect(
        PostgresRange.closedOpen(Uint8List.fromList([1, 2]), null).literal,
        r'["\\x0102",)',
      );
    });

    test('renders the bounds with their inclusivity', () {
      expect(const PostgresRange.closedOpen(2, 25).literal, '[2,25)');
      expect(const PostgresRange.closed(2, 25).literal, '[2,25]');
      expect(const PostgresRange.open(2, 25).literal, '(2,25)');
      expect(const PostgresRange.openClosed(2, 25).literal, '(2,25]');
    });

    test('a null bound is unbounded', () {
      expect(const PostgresRange.closedOpen(2, null).literal, '[2,)');
      expect(const PostgresRange.openClosed(null, 5).literal, '(,5]');
      expect(const PostgresRange<int>.open(null, null).literal, '(,)');
    });

    test('an unbounded side is exclusive whatever the constructor', () {
      const range = PostgresRange.closed(2, null);

      expect(range.literal, '[2,)');
      expect(range.upperInclusive, isFalse);
      expect(const PostgresRange<int>.closed(null, null).literal, '(,)');
      expect(const PostgresRange.openClosed(null, 5).lowerInclusive, isFalse);
      expect(PostgresRange.parse('[2,)', int.parse), range);
    });

    test('the empty range renders as empty', () {
      expect(const PostgresRange<int>.empty().literal, 'empty');
      expect(const PostgresRange<int>.empty().isEmpty, isTrue);
    });

    test('DateTime bounds render in ISO 8601', () {
      expect(
        PostgresRange.closedOpen(
          DateTime.utc(2024),
          DateTime.utc(2025),
        ).literal,
        '[2024-01-01T00:00:00.000Z,2025-01-01T00:00:00.000Z)',
      );
    });

    test('bounds are quoted when the literal requires it', () {
      expect(
        const PostgresRange.closedOpen('a,b', 'c d').literal,
        '["a,b","c d")',
      );
      expect(const PostgresRange.closedOpen('', 'x').literal, '["",x)');
      expect(
        const PostgresRange.closedOpen(r'a"b\c', 'x').literal,
        r'["a\"b\\c",x)',
      );
    });

    test('render takes a bound renderer', () {
      final range = PostgresRange.closedOpen(
        DateTime.utc(2024, 1, 2),
        DateTime.utc(2024, 1, 5),
      );

      expect(
        range.render((bound) => bound.toIso8601String().substring(0, 10)),
        '[2024-01-02,2024-01-05)',
      );
    });

    test('toString is the literal', () {
      expect('${const PostgresRange.closedOpen(2, 25)}', '[2,25)');
    });
  });

  group('parse', () {
    test('reads the bounds and their inclusivity', () {
      expect(
        PostgresRange.parse('[2,25)', int.parse),
        const PostgresRange.closedOpen(2, 25),
      );
      expect(
        PostgresRange.parse('(2,25]', int.parse),
        const PostgresRange.openClosed(2, 25),
      );
      expect(
        PostgresRange.parse('[2,25]', int.parse),
        const PostgresRange.closed(2, 25),
      );
      expect(
        PostgresRange.parse('(2,25)', int.parse),
        const PostgresRange.open(2, 25),
      );
    });

    test('reads unbounded sides and the empty range', () {
      expect(
        PostgresRange.parse('[2,)', int.parse),
        const PostgresRange.closedOpen(2, null),
      );
      expect(
        PostgresRange.parse('(,)', int.parse),
        const PostgresRange<int>.open(null, null),
      );
      expect(
        PostgresRange.parse('empty', int.parse),
        const PostgresRange<int>.empty(),
      );
    });

    test('reads the quoted bounds Postgres emits for timestamps', () {
      final range = PostgresRange.parse(
        '["2024-01-01 00:00:00+00","2024-02-01 00:00:00+00")',
        DateTime.parse,
      );

      expect(range.lower, DateTime.utc(2024, 1, 1));
      expect(range.upper, DateTime.utc(2024, 2, 1));
      expect(range.lowerInclusive, isTrue);
      expect(range.upperInclusive, isFalse);
    });

    test('unescapes quoted bounds', () {
      final range = PostgresRange.parse(
        r'["a\"b\\c","d,e"]',
        (bound) => bound,
      );

      expect(range.lower, r'a"b\c');
      expect(range.upper, 'd,e');
    });

    test(
      'an infinity bound is kept when the bound type has a value for it',
      () {
        final range = PostgresRange.parse(
          '[2024-01-01,infinity)',
          PostgresDate.parse,
        );

        expect(range.upper, PostgresDate.infinity);
        expect(range.literal, '[2024-01-01,"infinity")');
        expect(PostgresRange.parse(range.literal, PostgresDate.parse), range);
        expect(
          PostgresRange.parse(
            '(-infinity,2024-01-01]',
            PostgresDate.parse,
          ).lower,
          PostgresDate.negativeInfinity,
        );
      },
    );

    test('an infinity bound the bound type rejects is unbounded', () {
      expect(
        PostgresRange.parse('[2024-01-01T00:00:00Z,infinity)', DateTime.parse),
        PostgresRange.closedOpen(DateTime.utc(2024), null),
      );
      expect(
        PostgresRange.parse(
          '(-infinity,2024-01-01T00:00:00Z]',
          DateTime.parse,
        ),
        PostgresRange.openClosed(null, DateTime.utc(2024)),
      );
      expect(
        PostgresRange.parse('[2,infinity)', int.parse),
        const PostgresRange.closedOpen(2, null),
      );
    });

    test('a numeric infinity bound is the infinite number', () {
      expect(
        PostgresRange.parse('[1,Infinity)', num.parse),
        const PostgresRange<num>.closedOpen(1, double.infinity),
      );
      expect(
        PostgresRange.parse('["infinity",x)', (bound) => bound).lower,
        'infinity',
      );
    });

    test('a doubled quote inside a quoted bound is a quote', () {
      final range = PostgresRange.parse('["a""b",c)', (bound) => bound);

      expect(range.lower, 'a"b');
      expect(range.upper, 'c');
    });

    test('an empty quoted bound is an empty string, not unbounded', () {
      final range = PostgresRange.parse('["",x)', (bound) => bound);

      expect(range.lower, '');
      expect(range.upper, 'x');
    });

    test('round trips a rendered literal', () {
      for (final range in [
        const PostgresRange.closedOpen('a,b', 'c d'),
        const PostgresRange.closedOpen('infinity', 'x'),
        const PostgresRange.closed('a"b', ''),
      ]) {
        expect(
          PostgresRange.parse(range.literal, (bound) => bound),
          range,
          reason: range.literal,
        );
      }
    });

    test('rejects a stray bracket inside a bound', () {
      for (final literal in ['[a,b))', '[a,b]]', '[a],b)']) {
        expect(
          () => PostgresRange.parse(literal, (bound) => bound),
          throwsFormatException,
          reason: literal,
        );
      }
    });

    test('rejects anything that is not a range', () {
      for (final literal in [
        '2',
        '[2,25',
        '2,25)',
        '[2]',
        '[2,3,4)',
        '["2,3)',
      ]) {
        expect(
          () => PostgresRange.parse(literal, int.parse),
          throwsFormatException,
          reason: literal,
        );
      }
    });
  });

  test('ranges compare by value', () {
    expect(
      const PostgresRange.closedOpen(2, 25),
      const PostgresRange.closedOpen(2, 25),
    );
    expect(
      const PostgresRange.closedOpen(2, 25),
      isNot(const PostgresRange.closed(2, 25)),
    );
    expect(
      const PostgresRange.closedOpen(2, 25).hashCode,
      const PostgresRange.closedOpen(2, 25).hashCode,
    );
  });
}
