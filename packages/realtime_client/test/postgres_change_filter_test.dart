import 'package:realtime_client/realtime_client.dart';
import 'package:test/test.dart';

void main() {
  group('PostgresChangeFilter.toString()', () {
    test('escapes double quotes and backslashes in `in` filter values', () {
      final filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.inFilter,
        column: 'name',
        value: [r'a"b\c'],
      );

      expect(filter.toString(), r'name=in.("a\"b\\c")');
    });

    test('leaves plain `in` filter values unquoted', () {
      final filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.inFilter,
        column: 'status',
        value: ['active', 'pending'],
      );

      expect(filter.toString(), 'status=in.(active,pending)');
    });

    test('quotes only the `in` elements that contain reserved characters', () {
      final filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.inFilter,
        column: 'name',
        value: ['plain', 'a,b'],
      );

      expect(filter.toString(), 'name=in.(plain,"a,b")');
    });

    test('non-`in` filters are unaffected', () {
      final filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: 2,
      );

      expect(filter.toString(), 'id=eq.2');
    });

    test('quotes a scalar value containing a reserved character', () {
      final filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'name',
        value: 'a,b',
      );

      expect(filter.toString(), 'name=eq."a,b"');
    });

    group('new operators emit the correct wire token', () {
      final cases = [
        (PostgresChangeFilterType.like, 'title=like.%foo%'),
        (PostgresChangeFilterType.ilike, 'title=ilike.%foo%'),
        (PostgresChangeFilterType.match, 'title=match.%foo%'),
        (PostgresChangeFilterType.imatch, 'title=imatch.%foo%'),
        (PostgresChangeFilterType.isDistinct, 'title=isdistinct.%foo%'),
      ];

      for (final (type, expected) in cases) {
        test('${type.name} -> $expected', () {
          final filter = PostgresChangeFilter(
            type: type,
            column: 'title',
            value: '%foo%',
          );
          expect(filter.toString(), expected);
        });
      }
    });

    test('`is` operator uses the `is` token and serializes null', () {
      final filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.isFilter,
        column: 'deleted_at',
        value: null,
      );

      expect(filter.toString(), 'deleted_at=is.null');
    });

    group('negate prefixes the operator with `not.`', () {
      test('scalar operator', () {
        final filter = PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: 1,
          negate: true,
        );
        expect(filter.toString(), 'id=not.eq.1');
      });

      test('`in` operator', () {
        final filter = PostgresChangeFilter(
          type: PostgresChangeFilterType.inFilter,
          column: 'status',
          value: ['draft', 'archived'],
          negate: true,
        );
        expect(filter.toString(), 'status=not.in.(draft,archived)');
      });

      test('`is` operator', () {
        final filter = PostgresChangeFilter(
          type: PostgresChangeFilterType.isFilter,
          column: 'deleted_at',
          value: null,
          negate: true,
        );
        expect(filter.toString(), 'deleted_at=not.is.null');
      });
    });
  });
}
