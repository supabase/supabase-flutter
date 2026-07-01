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

      // The `"` and `\` are backslash-escaped so the element stays a single,
      // well-formed quoted value rather than the malformed `in.("a"b\c")`.
      expect(filter.toString(), r'name=in.("a\"b\\c")');
    });

    test('leaves plain `in` filter values untouched', () {
      final filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.inFilter,
        column: 'status',
        value: ['active', 'pending'],
      );

      expect(filter.toString(), 'status=in.("active","pending")');
    });

    test('non-`in` filters are unaffected', () {
      final filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: 2,
      );

      expect(filter.toString(), 'id=eq.2');
    });
  });
}
