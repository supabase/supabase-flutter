import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

void main() {
  group('HttpMethod', () {
    test('value is the uppercase method name', () {
      expect(HttpMethod.get.value, 'GET');
      expect(HttpMethod.head.value, 'HEAD');
      expect(HttpMethod.post.value, 'POST');
      expect(HttpMethod.put.value, 'PUT');
      expect(HttpMethod.patch.value, 'PATCH');
      expect(HttpMethod.delete.value, 'DELETE');
    });

    test('covers every method the client packages send', () {
      expect(HttpMethod.values, hasLength(6));
    });
  });
}
