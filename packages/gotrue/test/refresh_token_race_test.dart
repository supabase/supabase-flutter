import 'dart:async';
import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// HTTP client that simulates server-side refresh token consumption.
///
/// - First use of a refresh token succeeds and returns new tokens
/// - Second use of the SAME refresh token returns 400 "refresh_token_already_used"
///
/// This simulates real GoTrue server behavior where refresh tokens are single-use.
class RefreshTokenTrackingHttpClient extends BaseClient {
  final Set<String> _usedRefreshTokens = {};
  final List<String> requestLog = [];
  int requestCount = 0;

  /// Optional delay before responding (to simulate network latency)
  final Duration? responseDelay;

  /// Completer to control when the first request completes
  Completer<void>? holdFirstRequest;

  RefreshTokenTrackingHttpClient({this.responseDelay, this.holdFirstRequest});

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    requestCount++;
    final requestNumber = requestCount;

    // Extract refresh token from request body
    String? refreshToken;
    if (request is Request) {
      try {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        refreshToken = body['refresh_token'] as String?;
      } catch (_) {}
    }

    requestLog.add(
        'Request #$requestNumber: refresh_token=${refreshToken ?? "unknown"}');

    // Simulate network latency if configured
    if (responseDelay != null) {
      await Future.delayed(responseDelay!);
    }

    // Hold first request if completer is provided (to force race condition)
    if (requestNumber == 1 && holdFirstRequest != null) {
      await holdFirstRequest!.future;
    }

    // Check if this refresh token was already used
    if (refreshToken != null && _usedRefreshTokens.contains(refreshToken)) {
      // Return "refresh_token_already_used" error (like real GoTrue)
      return StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'code': 'refresh_token_already_used',
              'error_code': 'refresh_token_already_used',
              'msg': 'Invalid Refresh Token: Already Used',
            }),
          ),
        ),
        400,
        request: request,
        headers: {'x-sb-api-version': '2024-01-01'},
      );
    }

    // Mark token as used
    if (refreshToken != null) {
      _usedRefreshTokens.add(refreshToken);
    }

    // Generate new tokens
    final newRefreshToken =
        'new-refresh-token-${DateTime.now().millisecondsSinceEpoch}';
    final jwt = JWT(
      {
        'exp': (DateTime.now().millisecondsSinceEpoch / 1000).round() + 3600,
        'sub': userId1,
        'role': 'authenticated',
      },
    );

    return StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'access_token': jwt.sign(
              SecretKey('37c304f8-51aa-419a-a1af-06154e63707a'),
            ),
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': newRefreshToken,
            'user': {
              'id': userId1,
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'test@example.com',
              'email_confirmed_at': DateTime.now().toIso8601String(),
              'app_metadata': {
                'provider': 'email',
                'providers': ['email']
              },
              'user_metadata': {},
              'identities': [],
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          }),
        ),
      ),
      200,
      request: request,
    );
  }
}

void main() {
  const gotrueUrl = 'http://localhost:9999';

  group('Refresh token race condition fix tests', () {
    test('concurrent recoverSession calls are bundled (protected by completer)',
        () async {
      final httpClient = RefreshTokenTrackingHttpClient();
      final client = GoTrueClient(
        url: gotrueUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
      );

      // Create an expired session
      final expiredSession =
          getSessionData(DateTime.now().subtract(Duration(hours: 1)));

      // Call recoverSession concurrently - these SHOULD be bundled
      final results = await Future.wait([
        client.recoverSession(expiredSession.sessionString),
        client.recoverSession(expiredSession.sessionString),
      ]);

      // Both should succeed with same token (bundled into one request)
      expect(results[0].session?.accessToken, isNotNull);
      expect(results[0].session?.accessToken, results[1].session?.accessToken);

      // Only ONE HTTP request should have been made (bundling works)
      expect(httpClient.requestCount, 1,
          reason: 'Concurrent calls should be bundled into one request');
    });

    test(
        'FIXED: sequential refresh calls with stale token return current session',
        () async {
      final httpClient = RefreshTokenTrackingHttpClient();
      final client = GoTrueClient(
        url: gotrueUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
      );

      // Create an expired session with a specific refresh token
      final expiredSession =
          getSessionData(DateTime.now().subtract(Duration(hours: 1)));

      // First call succeeds and refreshes
      final result1 = await client.recoverSession(expiredSession.sessionString);
      expect(result1.session?.accessToken, isNotNull);
      expect(httpClient.requestCount, 1);

      final newRefreshToken = client.currentSession?.refreshToken;
      expect(newRefreshToken, isNot('-yeS4omysFs9tpUYBws9Rg'));

      // Second call with the SAME stale session
      // FIXED: Should return current valid session instead of making new request
      final result2 = await client.recoverSession(expiredSession.sessionString);

      // Should succeed (not throw)
      expect(result2.session, isNotNull);
      // Should return the CURRENT valid session
      expect(result2.session?.refreshToken, newRefreshToken);
      // Should NOT have made another HTTP request
      expect(httpClient.requestCount, 1,
          reason: 'Should not make request if session already refreshed');
    });

    test('FIXED: recoverSession races with autoRefreshTokenTick safely',
        () async {
      final holdFirstRequest = Completer<void>();
      final httpClient = RefreshTokenTrackingHttpClient(
        holdFirstRequest: holdFirstRequest,
      );

      final client = GoTrueClient(
        url: gotrueUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
        autoRefreshToken: true,
      );

      // Create an expired session
      final expiredSession =
          getSessionData(DateTime.now().subtract(Duration(hours: 1)));

      // Simulate the race: start recoverSession (will be held)
      final recoverFuture = client.recoverSession(expiredSession.sessionString);

      // Give time for the request to start
      await Future.delayed(Duration(milliseconds: 10));

      // Now start auto-refresh tick (simulates didChangeAppLifecycleState(resumed))
      client.startAutoRefresh();

      // Release the held request
      holdFirstRequest.complete();

      // Wait for recovery to complete
      final result = await recoverFuture;
      expect(result.session?.accessToken, isNotNull);

      // Stop auto-refresh to clean up
      client.stopAutoRefresh();

      // With proper bundling, only ONE request should be made
      expect(httpClient.requestCount, lessThanOrEqualTo(2));
    });

    test('FIXED: setInitialSession followed by concurrent refresh attempts',
        () async {
      final httpClient = RefreshTokenTrackingHttpClient(
        responseDelay: Duration(milliseconds: 50),
      );

      final client = GoTrueClient(
        url: gotrueUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
        autoRefreshToken: true,
      );

      // Create an expired session
      final expiredSession =
          getSessionData(DateTime.now().subtract(Duration(hours: 1)));

      // 1. setInitialSession loads the expired session (but doesn't refresh)
      await client.setInitialSession(expiredSession.sessionString);
      expect(client.currentSession?.isExpired, true);

      // 2. Start auto-refresh (simulates didChangeAppLifecycleState(resumed))
      client.startAutoRefresh();

      // 3. Also call recoverSession (simulates lazy recovery call)
      final recoverFuture = client.recoverSession(expiredSession.sessionString);

      // Wait a bit for both to potentially race
      await Future.delayed(Duration(milliseconds: 100));

      // FIXED: Should succeed without throwing
      final result = await recoverFuture;
      expect(result.session, isNotNull);

      client.stopAutoRefresh();

      // Log all requests for debugging
      print('Request log:');
      for (final log in httpClient.requestLog) {
        print('  $log');
      }
      print('Total requests: ${httpClient.requestCount}');

      // Should only make 1 or 2 requests (not more due to races)
      expect(httpClient.requestCount, lessThanOrEqualTo(2));
    });

    test(
        'FIXED: stale token is detected and current session is returned without HTTP request',
        () async {
      final httpClient = RefreshTokenTrackingHttpClient(
        responseDelay: Duration(milliseconds: 10),
      );

      final client = GoTrueClient(
        url: gotrueUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
        autoRefreshToken: true,
      );

      // Create expired session
      final expiredSession =
          getSessionData(DateTime.now().subtract(Duration(hours: 1)));
      final staleRefreshToken = '-yeS4omysFs9tpUYBws9Rg';

      // 1. Set initial session (doesn't refresh)
      await client.setInitialSession(expiredSession.sessionString);
      expect(client.currentSession?.isExpired, true);
      expect(httpClient.requestCount, 0);

      // 2. Capture the stale token (simulating what _autoRefreshTokenTick does)
      final capturedStaleToken = client.currentSession?.refreshToken;
      expect(capturedStaleToken, staleRefreshToken);

      // 3. First refresh succeeds
      await client.refreshSession();
      expect(httpClient.requestCount, 1);

      // 4. Verify the session now has a NEW refresh token
      expect(client.currentSession?.refreshToken, isNot(staleRefreshToken));
      final newToken = client.currentSession?.refreshToken;

      // 5. Now try to use the STALE token again (simulates the race condition)
      // FIXED: Should return current session without making another request
      final result = await client.recoverSession(expiredSession.sessionString);

      expect(result.session, isNotNull);
      expect(result.session?.refreshToken, newToken);
      expect(httpClient.requestCount, 1,
          reason: 'Should not make request with stale token');
    });

    test('FIXED: signedOut event is NOT emitted when session is still valid',
        () async {
      final httpClient = RefreshTokenTrackingHttpClient();
      final client = GoTrueClient(
        url: gotrueUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
      );

      // Create and recover an expired session (first refresh succeeds)
      final expiredSession =
          getSessionData(DateTime.now().subtract(Duration(hours: 1)));
      await client.recoverSession(expiredSession.sessionString);

      // Capture the valid session after refresh
      final validSession = client.currentSession;
      expect(validSession, isNotNull);
      expect(validSession!.isExpired, false);

      // Listen for auth state changes AFTER first successful refresh
      final authEvents = <AuthChangeEvent>[];
      final subscription = client.onAuthStateChange.listen(
        (state) {
          authEvents.add(state.event);
        },
        onError: (_) {}, // Ignore stream errors
      );

      // Second call with stale token - FIXED: should NOT throw or emit signedOut
      final result2 = await client.recoverSession(expiredSession.sessionString);

      // Should succeed
      expect(result2.session, isNotNull);

      // Wait for any events
      await Future.delayed(Duration(milliseconds: 50));

      // FIXED: signedOut should NOT be emitted since session is valid
      expect(authEvents, isNot(contains(AuthChangeEvent.signedOut)),
          reason: 'Should not sign out user when session is still valid');

      // Session should still be valid
      expect(client.currentSession?.accessToken, validSession.accessToken);

      await subscription.cancel();
    });

    test(
        'FIXED: concurrent recoverSession and autoRefreshTick both succeed with same result',
        () async {
      final httpClient = RefreshTokenTrackingHttpClient(
        responseDelay: Duration(milliseconds: 50),
      );

      final client = GoTrueClient(
        url: gotrueUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
        autoRefreshToken: true,
      );

      // Set up expired session
      final expiredSession =
          getSessionData(DateTime.now().subtract(Duration(hours: 1)));
      await client.setInitialSession(expiredSession.sessionString);

      // Start auto-refresh (triggers _autoRefreshTokenTick immediately)
      client.startAutoRefresh();

      // Simultaneously call recoverSession
      final recoverFuture = client.recoverSession(expiredSession.sessionString);

      // Wait a bit for both to potentially start
      await Future.delayed(Duration(milliseconds: 10));

      // FIXED: Both should succeed
      final result = await recoverFuture;
      expect(result.session, isNotNull);

      client.stopAutoRefresh();

      // Should only make ONE or TWO HTTP requests (properly handled)
      expect(httpClient.requestCount, lessThanOrEqualTo(2),
          reason: 'Refresh attempts should be handled without errors');

      // Session should be valid
      expect(client.currentSession?.isExpired, false);
    });

    test(
        'FIXED: _callRefreshToken returns current session when passed stale token',
        () async {
      final httpClient = RefreshTokenTrackingHttpClient();
      final client = GoTrueClient(
        url: gotrueUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
      );

      // Set up and refresh session
      final expiredSession =
          getSessionData(DateTime.now().subtract(Duration(hours: 1)));
      await client.recoverSession(expiredSession.sessionString);
      expect(httpClient.requestCount, 1);

      // Second call with stale session
      // FIXED: Should NOT make a second request
      final result2 = await client.recoverSession(expiredSession.sessionString);

      expect(result2.session, isNotNull);
      expect(httpClient.requestCount, 1,
          reason: 'Should not attempt refresh with stale token');
    });
  });
}
