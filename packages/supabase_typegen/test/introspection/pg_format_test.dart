import 'package:supabase_typegen/src/introspection/pg_format.dart';
import 'package:test/test.dart';

void main() {
  group('literal', () {
    test('quotes strings and doubles embedded quotes', () {
      expect(literal('public'), "'public'");
      expect(literal("it's"), "'it''s'");
      expect(literal(''), "''");
    });

    test('uses the escape string form for backslashes', () {
      expect(literal(r'a\b'), r"E'a\\b'");
      expect(literal(r"a\'b"), r"E'a\\''b'");
    });

    test('quotes numbers like pg-format does', () {
      expect(literal(10), "'10'");
      expect(literal(1.5), "'1.5'");
    });

    test('renders null and booleans', () {
      expect(literal(null), 'NULL');
      expect(literal(true), "'t'");
      expect(literal(false), "'f'");
    });

    test('joins lists and parenthesises nested lists', () {
      expect(literal(['a', 'b']), "'a','b'");
      expect(
        literal([
          ['a', 'b'],
          ['c', 'd'],
        ]),
        "('a', 'b'), ('c', 'd')",
      );
    });

    test('rejects values pg-format would serialize as JSON', () {
      expect(() => literal({'a': 1}), throwsArgumentError);
    });
  });
}
