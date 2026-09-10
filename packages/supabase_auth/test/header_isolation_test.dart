import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('AuthClient header isolation', () {
    late MockSupabaseHttpClient http;
    late AuthClient client;

    setUp(() {
      http = MockSupabaseHttpClient()..stubUser();
      client = AuthClient(
        url: 'http://localhost',
        headers: {'apikey': 'anon-key'},
        httpClient: http,
        asyncStorage: TestAsyncStorage(),
      );
    });

    test('a jwt-bearing call sends the token but never persists it', () async {
      await client.getUser('user-access-token');

      // The token reached the wire for this single request...
      expect(
        http.requests.single.headers['Authorization'],
        'Bearer user-access-token',
      );
      // ...but it must not be baked into the shared header map, where it would
      // ride along on every later request, including after sign out.
      expect(client.headers.containsKey('Authorization'), isFalse);
      expect(client.headers.containsKey('Content-Type'), isFalse);
    });

    test('client headers are unchanged across repeated calls', () async {
      final before = Map.of(client.headers);
      await client.getUser('token-a');
      await client.getUser('token-b');

      expect(client.headers, before);
    });

    test('headers cannot be mutated in place', () async {
      expect(
        () => client.headers['apikey'] = 'other-key',
        throwsUnsupportedError,
      );

      await client.getUser('user-access-token');

      expect(http.requests.single.headers['apikey'], 'anon-key');
    });

    test('setHeader adds a header to subsequent requests', () async {
      expect(
        identical(client.setHeader('x-custom-header', 'value'), client),
        isTrue,
      );

      await client.getUser('user-access-token');

      expect(http.requests.single.headers['x-custom-header'], 'value');
      expect(client.headers['x-custom-header'], 'value');
    });

    test('setHeader is picked up by the admin api', () async {
      // The admin api reads a user through its own endpoint, which the
      // stubUser shorthand does not cover.
      http.stub(testUserJson(), path: '/admin/users/$testUserId');
      client.setHeader('x-custom-header', 'value');

      await client.admin.getUserById(testUserId);

      expect(http.requests.single.headers['x-custom-header'], 'value');
    });
  });
}
