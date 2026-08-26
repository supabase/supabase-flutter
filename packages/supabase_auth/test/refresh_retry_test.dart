import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'refresh_token_race_test.dart' show createExpiredSessionForUser1;
import 'utils.dart';

/// HTTP client that answers every refresh with a retryable server error.
class _UnavailableHttpClient extends BaseClient {
  int requestCount = 0;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    requestCount++;
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'msg': 'unavailable'}))),
      503,
      request: request,
    );
  }
}

void main() {
  const authUrl = 'http://localhost:9999';

  Future<int> refreshAttemptsWith(SupabaseRetryOptions retryOptions) async {
    final httpClient = _UnavailableHttpClient();
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

    return httpClient.requestCount;
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
