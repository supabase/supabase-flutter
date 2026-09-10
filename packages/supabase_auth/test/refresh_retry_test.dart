import 'dart:async';

import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'refresh_token_race_test.dart' show createExpiredSessionForUser1;
import 'utils.dart';

void main() {
  const authUrl = 'http://localhost:9999';

  Future<int> refreshAttemptsWith(SupabaseRetryOptions retryOptions) async {
    // Every refresh is answered with a retryable server error.
    final httpClient = MockSupabaseHttpClient()
      ..stub({'msg': 'unavailable'}, statusCode: 503);
    final client = AuthClient(
      url: authUrl,
      asyncStorage: TestAsyncStorage(),
      httpClient: httpClient,
      autoRefreshToken: false,
      retryOptions: retryOptions,
    );
    final subscription = client.onAuthStateChange.listen(
      (_) {},
      onError: (_) {},
    );
    addTearDown(subscription.cancel);

    await client.setInitialSession(createExpiredSessionForUser1());

    await expectLater(client.getSession(), throwsA(isA<AuthException>()));

    return httpClient.requests.length;
  }

  group('refresh retry configuration', () {
    test('a count of zero refreshes exactly once', () async {
      expect(
        await refreshAttemptsWith(const SupabaseRetryOptions(count: 0)),
        1,
      );
    });

    test('the configured count bounds the refresh attempts', () async {
      expect(
        await refreshAttemptsWith(
          const SupabaseRetryOptions(
            count: 2,
            initialDelay: Duration(milliseconds: 1),
          ),
        ),
        3,
      );
    });

    test('disabled options refresh exactly once', () async {
      expect(
        await refreshAttemptsWith(const SupabaseRetryOptions(enabled: false)),
        1,
      );
    });
  });
}
