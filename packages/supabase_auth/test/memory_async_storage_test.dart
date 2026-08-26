import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

void main() {
  late MemoryAuthAsyncStorage storage;

  setUp(() {
    storage = MemoryAuthAsyncStorage();
  });

  test('returns null for a key that was never stored', () async {
    expect(await storage.getItem(key: 'code-verifier'), isNull);
  });

  test('returns the value that was stored last', () async {
    await storage.setItem(key: 'code-verifier', value: 'first');
    await storage.setItem(key: 'code-verifier', value: 'second');

    expect(await storage.getItem(key: 'code-verifier'), 'second');
  });

  test('forgets a removed key', () async {
    await storage.setItem(key: 'code-verifier', value: 'value');
    await storage.removeItem(key: 'code-verifier');

    expect(await storage.getItem(key: 'code-verifier'), isNull);
  });

  test('keeps the entries of two instances apart', () async {
    await storage.setItem(key: 'code-verifier', value: 'value');

    final other = MemoryAuthAsyncStorage();

    expect(await other.getItem(key: 'code-verifier'), isNull);
  });
}
