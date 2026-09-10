import 'dart:async';

import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'refresh_token_race_test.dart'
    show
        InvalidRefreshTokenHttpClient,
        RefreshTokenTrackingHttpClient,
        createExpiredSessionForUser1;
import 'utils.dart';

void main() {
  const authUrl = 'http://localhost:9999';

  group('getSession', () {
    test('returns null when there is no session', () async {
      final httpClient = RefreshTokenTrackingHttpClient();
      final client = AuthClient(
        url: authUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
        autoRefreshToken: false,
      );

      expect(await client.getSession(), isNull);
      expect(httpClient.requestCount, 0);
    });

    test(
      'returns the current session without a request when not expired',
      () async {
        final httpClient = RefreshTokenTrackingHttpClient();
        final client = AuthClient(
          url: authUrl,
          asyncStorage: TestAsyncStorage(),
          httpClient: httpClient,
          autoRefreshToken: false,
        );

        final data = getSessionData(DateTime.now().add(Duration(hours: 1)));
        await client.setInitialSession(data.sessionString);

        final session = await client.getSession();
        expect(session, isNotNull);
        expect(session!.accessToken, data.accessToken);
        expect(httpClient.requestCount, 0);
      },
    );

    test('refreshes an expired session on demand', () async {
      final httpClient = RefreshTokenTrackingHttpClient();
      final client = AuthClient(
        url: authUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
        autoRefreshToken: false,
      );

      await client.setInitialSession(createExpiredSessionForUser1());
      expect(client.currentSession?.isExpired, isTrue);

      final session = await client.getSession();
      expect(session, isNotNull);
      expect(session!.isExpired, isFalse);
      expect(httpClient.requestCount, 1);
    });

    test('de-duplicates concurrent on-demand refreshes', () async {
      final httpClient = RefreshTokenTrackingHttpClient(
        responseDelay: Duration(milliseconds: 50),
      );
      final client = AuthClient(
        url: authUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
        autoRefreshToken: false,
      );

      await client.setInitialSession(createExpiredSessionForUser1());

      final sessions = await Future.wait([
        client.getSession(),
        client.getSession(),
      ]);

      expect(sessions[0]?.accessToken, isNotNull);
      expect(sessions[0]?.accessToken, sessions[1]?.accessToken);
      expect(
        httpClient.requestCount,
        1,
        reason: 'Concurrent getSession calls should share a single refresh',
      );
    });

    test('throws when an expired session cannot be refreshed', () async {
      final client = AuthClient(
        url: authUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: InvalidRefreshTokenHttpClient(),
      );

      final subscription = client.onAuthStateChange.listen(
        (_) {},
        onError: (_) {},
      );

      await client.setInitialSession(createExpiredSessionForUser1());

      await expectLater(
        client.getSession(),
        throwsA(isA<AuthException>()),
      );
      expect(client.currentSession, isNull);

      await subscription.cancel();
    });

    test(
      'returns the still-valid session when a refresh fails but the access '
      'token has not actually expired',
      () async {
        // Every refresh fails with a retryable server error.
        final httpClient = MockSupabaseHttpClient()
          ..stub({'msg': 'unavailable'}, statusCode: 500);
        final client = AuthClient(
          url: authUrl,
          asyncStorage: TestAsyncStorage(),
          httpClient: httpClient,
          autoRefreshToken: false,
        );

        final subscription = client.onAuthStateChange.listen(
          (_) {},
          onError: (_) {},
        );

        // Expired by the margin, but the access token is still valid for
        // another 20 seconds.
        final data = getSessionData(DateTime.now().add(Duration(seconds: 20)));
        await client.setInitialSession(data.sessionString);
        expect(client.currentSession?.isExpired, isTrue);

        final session = await client.getSession();
        expect(session, isNotNull);
        expect(session!.accessToken, data.accessToken);
        expect(httpClient.requests, isNotEmpty);

        await subscription.cancel();
      },
      timeout: Timeout(Duration(seconds: 30)),
    );
  });
}
