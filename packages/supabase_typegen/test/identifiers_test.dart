import 'package:supabase_typegen/supabase_typegen.dart';
import 'package:test/test.dart';

void main() {
  group('pascalCase', () {
    test('converts snake case names', () {
      expect(pascalCase('author_stats'), 'AuthorStats');
      expect(pascalCase('books'), 'Books');
      expect(pascalCase('user-profiles'), 'UserProfiles');
    });

    test('keeps existing camel humps', () {
      expect(pascalCase('UserProfiles'), 'UserProfiles');
      expect(pascalCase('userId'), 'UserId');
      expect(camelCase('userId'), 'userId');
    });

    test('prefixes names starting with a digit', () {
      expect(pascalCase('2fa_codes'), r'$2faCodes');
    });

    test('spells characters outside ASCII by their code point', () {
      expect(pascalCase('статус'), 'U441U442U430U442U443U441');
      expect(pascalCase('café_menu'), 'CafUe9Menu');
      expect(camelCase('名前'), 'u540dU524d');
      expect(pascalCase('новый'), isNot(pascalCase('готов')));
    });

    test('splits words at other characters outside ASCII', () {
      expect(camelCase('quote\u2029tail'), 'quoteTail');
      expect(pascalCase('page\u00a0count'), 'PageCount');
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

    test('suffixes Object member names', () {
      expect(memberIdentifier('hash_code'), r'hashCode$');
      expect(memberIdentifier('to_string'), r'toString$');
    });

    test('keeps Map member names now that rows do not implement Map', () {
      expect(memberIdentifier('length'), 'length');
      expect(memberIdentifier('keys'), 'keys');
    });

    test('keeps regular names untouched', () {
      expect(memberIdentifier('title'), 'title');
      expect(memberIdentifier('author_id'), 'authorId');
    });
  });
}
