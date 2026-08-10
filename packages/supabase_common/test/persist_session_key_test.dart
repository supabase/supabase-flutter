import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('defaultPersistSessionKey', () {
    test('derives the key from the project ref', () {
      expect(
        defaultPersistSessionKey('https://abcdefghijklmnop.supabase.co'),
        'sb-abcdefghijklmnop-auth-token',
      );
    });

    test('ignores the port and the path', () {
      expect(
        defaultPersistSessionKey('http://localhost:54321/rest/v1'),
        'sb-localhost-auth-token',
      );
    });

    test('handles a custom domain', () {
      expect(
        defaultPersistSessionKey('https://auth.example.com'),
        'sb-auth-auth-token',
      );
    });
  });
}
