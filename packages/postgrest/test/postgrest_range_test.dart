import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

void main() {
  group('literal', () {
    test('renders the bounds with their inclusivity', () {
      expect(const PostgrestRange.closedOpen(2, 25).literal, '[2,25)');
      expect(const PostgrestRange.closed(2, 25).literal, '[2,25]');
      expect(const PostgrestRange.open(2, 25).literal, '(2,25)');
      expect(const PostgrestRange.openClosed(2, 25).literal, '(2,25]');
    });

    test('a null bound is unbounded', () {
      expect(const PostgrestRange.closedOpen(2, null).literal, '[2,)');
      expect(const PostgrestRange.openClosed(null, 5).literal, '(,5]');
      expect(const PostgrestRange<int>.open(null, null).literal, '(,)');
    });

    test('an unbounded side is exclusive whatever the constructor', () {
      const range = PostgrestRange.closed(2, null);

      expect(range.literal, '[2,)');
      expect(range.upperInclusive, isFalse);
      expect(const PostgrestRange<int>.closed(null, null).literal, '(,)');
      expect(const PostgrestRange.openClosed(null, 5).lowerInclusive, isFalse);
      expect(PostgrestRange.parse('[2,)', int.parse), range);
    });

    test('the empty range renders as empty', () {
      expect(const PostgrestRange<int>.empty().literal, 'empty');
      expect(const PostgrestRange<int>.empty().isEmpty, isTrue);
    });

    test('DateTime bounds render in ISO 8601', () {
      expect(
        PostgrestRange.closedOpen(
          DateTime.utc(2024),
          DateTime.utc(2025),
        ).literal,
        '[2024-01-01T00:00:00.000Z,2025-01-01T00:00:00.000Z)',
      );
    });

    test('bounds are quoted when the literal requires it', () {
      expect(
        const PostgrestRange.closedOpen('a,b', 'c d').literal,
        '["a,b","c d")',
      );
      expect(const PostgrestRange.closedOpen('', 'x').literal, '["",x)');
      expect(
        const PostgrestRange.closedOpen(r'a"b\c', 'x').literal,
        r'["a\"b\\c",x)',
      );
    });

    test('render takes a bound renderer', () {
      final range = PostgrestRange.closedOpen(
        DateTime.utc(2024, 1, 2),
        DateTime.utc(2024, 1, 5),
      );

      expect(
        range.render((bound) => bound.toIso8601String().substring(0, 10)),
        '[2024-01-02,2024-01-05)',
      );
    });

    test('toString is the literal', () {
      expect('${const PostgrestRange.closedOpen(2, 25)}', '[2,25)');
    });
  });

  group('parse', () {
    test('reads the bounds and their inclusivity', () {
      expect(
        PostgrestRange.parse('[2,25)', int.parse),
        const PostgrestRange.closedOpen(2, 25),
      );
      expect(
        PostgrestRange.parse('(2,25]', int.parse),
        const PostgrestRange.openClosed(2, 25),
      );
      expect(
        PostgrestRange.parse('[2,25]', int.parse),
        const PostgrestRange.closed(2, 25),
      );
      expect(
        PostgrestRange.parse('(2,25)', int.parse),
        const PostgrestRange.open(2, 25),
      );
    });

    test('reads unbounded sides and the empty range', () {
      expect(
        PostgrestRange.parse('[2,)', int.parse),
        const PostgrestRange.closedOpen(2, null),
      );
      expect(
        PostgrestRange.parse('(,)', int.parse),
        const PostgrestRange<int>.open(null, null),
      );
      expect(
        PostgrestRange.parse('empty', int.parse),
        const PostgrestRange<int>.empty(),
      );
    });

    test('reads the quoted bounds Postgres emits for timestamps', () {
      final range = PostgrestRange.parse(
        '["2024-01-01 00:00:00+00","2024-02-01 00:00:00+00")',
        DateTime.parse,
      );

      expect(range.lower, DateTime.utc(2024, 1, 1));
      expect(range.upper, DateTime.utc(2024, 2, 1));
      expect(range.lowerInclusive, isTrue);
      expect(range.upperInclusive, isFalse);
    });

    test('unescapes quoted bounds', () {
      final range = PostgrestRange.parse(
        r'["a\"b\\c","d,e"]',
        (bound) => bound,
      );

      expect(range.lower, r'a"b\c');
      expect(range.upper, 'd,e');
    });

    test('an unquoted infinity bound is unbounded', () {
      expect(
        PostgrestRange.parse('[2024-01-01T00:00:00Z,infinity)', DateTime.parse),
        PostgrestRange.closedOpen(DateTime.utc(2024), null),
      );
      expect(
        PostgrestRange.parse(
          '(-infinity,2024-01-01T00:00:00Z]',
          DateTime.parse,
        ),
        PostgrestRange.openClosed(null, DateTime.utc(2024)),
      );
      expect(
        PostgrestRange.parse('[Infinity,+Infinity]', double.parse),
        const PostgrestRange<double>.closed(null, null),
      );
      expect(
        PostgrestRange.parse('["infinity",x)', (bound) => bound).lower,
        'infinity',
      );
    });

    test('a doubled quote inside a quoted bound is a quote', () {
      final range = PostgrestRange.parse('["a""b",c)', (bound) => bound);

      expect(range.lower, 'a"b');
      expect(range.upper, 'c');
    });

    test('an empty quoted bound is an empty string, not unbounded', () {
      final range = PostgrestRange.parse('["",x)', (bound) => bound);

      expect(range.lower, '');
      expect(range.upper, 'x');
    });

    test('round trips a rendered literal', () {
      for (final range in [
        const PostgrestRange.closedOpen('a,b', 'c d'),
        const PostgrestRange.closedOpen('infinity', 'x'),
        const PostgrestRange.closed('a"b', ''),
      ]) {
        expect(
          PostgrestRange.parse(range.literal, (bound) => bound),
          range,
          reason: range.literal,
        );
      }
    });

    test('rejects a stray bracket inside a bound', () {
      for (final literal in ['[a,b))', '[a,b]]', '[a],b)']) {
        expect(
          () => PostgrestRange.parse(literal, (bound) => bound),
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
          () => PostgrestRange.parse(literal, int.parse),
          throwsFormatException,
          reason: literal,
        );
      }
    });
  });

  test('ranges compare by value', () {
    expect(
      const PostgrestRange.closedOpen(2, 25),
      const PostgrestRange.closedOpen(2, 25),
    );
    expect(
      const PostgrestRange.closedOpen(2, 25),
      isNot(const PostgrestRange.closed(2, 25)),
    );
    expect(
      const PostgrestRange.closedOpen(2, 25).hashCode,
      const PostgrestRange.closedOpen(2, 25).hashCode,
    );
  });
}
