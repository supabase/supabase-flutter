import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  late MockSupabaseHttpClient httpClient;
  late AuthClient client;

  setUp(() {
    httpClient = MockSupabaseHttpClient()
      ..stub({}, path: '/auth/v1/otp')
      ..stubSignIn();
    client = AuthClient(
      url: 'http://localhost:9999/auth/v1',
      httpClient: httpClient,
      autoRefreshToken: false,
      asyncStorage: TestAsyncStorage(),
    );
  });

  tearDown(() {
    client.dispose();
  });

  group('hasPendingPkceFlow', () {
    test('is false before a PKCE flow starts', () async {
      expect(await client.hasPendingPkceFlow(), isFalse);
    });

    test('is true while a PKCE flow waits for its code', () async {
      await client.signInWithOtp(email: 'fake1@email.com');

      expect(await client.hasPendingPkceFlow(), isTrue);
    });

    test('is false once the code is exchanged', () async {
      await client.signInWithOtp(email: 'fake1@email.com');
      await client.exchangeCodeForSession('auth-code');

      expect(await client.hasPendingPkceFlow(), isFalse);
    });

    test('is false for an implicit flow client without storage', () async {
      final clientWithoutStorage = AuthClient(
        url: 'http://localhost:9999/auth/v1',
        httpClient: httpClient,
        autoRefreshToken: false,
        flowType: AuthFlowType.implicit,
      );
      addTearDown(clientWithoutStorage.dispose);

      expect(await clientWithoutStorage.hasPendingPkceFlow(), isFalse);
    });
  });
}
