import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('literal', () {
    test('renders the ranges inside braces', () {
      expect(
        PostgresMultirange([
          const PostgresRange.closedOpen(1, 3),
          const PostgresRange.closedOpen(5, 7),
        ]).literal,
        '{[1,3),[5,7)}',
      );
      expect(PostgresMultirange<int>(const []).literal, '{}');
    });

    test('renders the bounds through render', () {
      final multirange = PostgresMultirange([
        PostgresRange.closedOpen(DateTime.utc(2024), null),
      ]);
      expect(
        multirange.render((bound) => bound.toIso8601String()),
        '{[2024-01-01T00:00:00.000Z,)}',
      );
    });

    test('toString is the literal', () {
      expect(
        PostgresMultirange([const PostgresRange<int>.closed(1, 2)]).toString(),
        '{[1,2]}',
      );
    });
  });

  group('parse', () {
    test('reads every range with the bound parser', () {
      expect(
        PostgresMultirange.parse('{[1,3),[5,7)}', int.parse),
        PostgresMultirange([
          const PostgresRange.closedOpen(1, 3),
          const PostgresRange.closedOpen(5, 7),
        ]),
      );
      expect(
        PostgresMultirange.parse('{(,5)}', int.parse).ranges.single,
        const PostgresRange<int>.closedOpen(null, 5),
      );
    });

    test('reads the empty multirange', () {
      expect(PostgresMultirange.parse('{}', int.parse).ranges, isEmpty);
      expect(PostgresMultirange.parse(' { } ', int.parse).ranges, isEmpty);
    });

    test('keeps a bracket or comma inside a quoted bound', () {
      final multirange = PostgresMultirange.parse(
        r'{["a)b","c\"d"],["2024-01-01 00:00:00+00",)}',
        (bound) => bound,
      );
      expect(multirange.ranges, [
        const PostgresRange.closed('a)b', 'c"d'),
        const PostgresRange.closedOpen('2024-01-01 00:00:00+00', null),
      ]);
    });

    test('reads whitespace around the ranges and an empty member', () {
      expect(
        PostgresMultirange.parse('{ [1,3) , empty }', int.parse).ranges,
        [
          const PostgresRange.closedOpen(1, 3),
          const PostgresRange<int>.empty(),
        ],
      );
    });

    test('rejects what is not a multirange', () {
      for (final literal in [
        '',
        '[1,3)',
        '{[1,3)',
        '{[1,3)[5,7)}',
        '{[1,3),}',
        '{,[1,3)}',
        '{[1,3}',
        '{x}',
      ]) {
        expect(
          () => PostgresMultirange.parse(literal, int.parse),
          throwsFormatException,
          reason: literal,
        );
      }
    });

    test('round trips a rendered literal', () {
      final multirange = PostgresMultirange([
        const PostgresRange.closedOpen(1, 3),
        const PostgresRange<int>.openClosed(5, null),
      ]);
      expect(
        PostgresMultirange.parse(multirange.literal, int.parse),
        multirange,
      );
    });
  });

  test('keeps its own unmodifiable list', () {
    final ranges = [const PostgresRange.closedOpen(1, 3)];
    final multirange = PostgresMultirange(ranges);
    ranges.add(const PostgresRange.closedOpen(5, 7));
    expect(multirange.ranges, hasLength(1));
    expect(
      () => multirange.ranges.add(const PostgresRange.closedOpen(5, 7)),
      throwsUnsupportedError,
    );
  });

  test('equal multiranges hash alike', () {
    expect(
      PostgresMultirange.parse('{[1,3)}', int.parse).hashCode,
      PostgresMultirange.parse('{[1,3)}', int.parse).hashCode,
    );
  });
}
