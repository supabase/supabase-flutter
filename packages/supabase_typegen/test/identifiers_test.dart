import 'package:supabase_typegen/supabase_typegen.dart';
import 'package:test/test.dart';

void main() {
  group('pascalCase', () {
    test('converts snake case names', () {
      expect(pascalCase('author_stats'), 'AuthorStats');
      expect(pascalCase('books'), 'Books');
      expect(pascalCase('user-profiles'), 'UserProfiles');
    });

    test('prefixes names starting with a digit', () {
      expect(pascalCase('2fa_codes'), r'$2faCodes');
    });
  });

  group('camelCase', () {
    test('converts snake case names', () {
      expect(camelCase('created_at'), 'createdAt');
      expect(camelCase('id'), 'id');
    });
  });

  group('memberIdentifier', () {
    test('suffixes reserved words', () {
      expect(memberIdentifier('class'), r'class$');
      expect(memberIdentifier('in'), r'in$');
    });

    test('suffixes Map member names', () {
      expect(memberIdentifier('length'), r'length$');
      expect(memberIdentifier('keys'), r'keys$');
    });

    test('keeps regular names untouched', () {
      expect(memberIdentifier('title'), 'title');
      expect(memberIdentifier('author_id'), 'authorId');
    });
  });
}
