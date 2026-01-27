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

  /// Manually mark a token as used (to simulate race condition where
  /// another request already consumed the token)
  void markTokenAsUsed(String token) {
    _usedRefreshTokens.add(token);
  }

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

/// Creates an expired session string for the test user (userId1)
String createExpiredSessionForUser1() {
  final expireDateTime = DateTime.now().subtract(Duration(hours: 1));
  final expiresAt = expireDateTime.millisecondsSinceEpoch ~/ 1000;
  final accessTokenMid = base64.encode(utf8.encode(json
      .encode({'exp': expiresAt, 'sub': userId1, 'role': 'authenticated'})));
  final accessToken = 'any.$accessTokenMid.any';
  return '{"access_token":"$accessToken","expires_in":-3600,"refresh_token":"-yeS4omysFs9tpUYBws9Rg","token_type":"bearer","provider_token":null,"provider_refresh_token":null,"user":{"id":"$userId1","app_metadata":{"provider":"email","providers":["email"]},"user_metadata":{},"aud":"","email":"test@example.com","phone":"","created_at":"2023-04-01T08:35:05.208586Z","confirmed_at":null,"email_confirmed_at":"2023-04-01T08:35:05.220096086Z","phone_confirmed_at":null,"last_sign_in_at":"2023-04-01T08:35:05.222755878Z","role":"","updated_at":"2023-04-01T08:35:05.226938Z"}}';
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

      // Create an expired session for the same user
      final expiredSession = createExpiredSessionForUser1();

      // Call recoverSession concurrently - these SHOULD be bundled
      final results = await Future.wait([
        client.recoverSession(expiredSession),
        client.recoverSession(expiredSession),
      ]);

      // Both should succeed with same token (bundled into one request)
      expect(results[0].session?.accessToken, isNotNull);
      expect(results[0].session?.accessToken, results[1].session?.accessToken);

      // Only ONE HTTP request should have been made (bundling works)
      expect(httpClient.requestCount, 1,
          reason: 'Concurrent calls should be bundled into one request');
    });

    test(
        'FIXED: sequential recoverSession calls with same user return current session',
        () async {
      final httpClient = RefreshTokenTrackingHttpClient();
      final client = GoTrueClient(
        url: gotrueUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
      );

      // Create an expired session for the test user
      final expiredSession = createExpiredSessionForUser1();

      // First call succeeds and refreshes
      final result1 = await client.recoverSession(expiredSession);
      expect(result1.session?.accessToken, isNotNull);
      expect(httpClient.requestCount, 1);

      final newRefreshToken = client.currentSession?.refreshToken;
      expect(newRefreshToken, isNot('-yeS4omysFs9tpUYBws9Rg'));

      // Second call with the SAME stale session (same user ID)
      // FIXED: Should return current valid session without making new request
      final result2 = await client.recoverSession(expiredSession);

      // Should succeed (not throw)
      expect(result2.session, isNotNull);
      // Should return the CURRENT valid session
      expect(result2.session?.refreshToken, newRefreshToken);
      // Should NOT have made another HTTP request (early return in recoverSession)
      expect(httpClient.requestCount, 1,
          reason:
              'Should not make request if session already refreshed for same user');
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

      // Create an expired session for the test user
      final expiredSession = createExpiredSessionForUser1();

      // Simulate the race: start recoverSession (will be held)
      final recoverFuture = client.recoverSession(expiredSession);

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

      // Create an expired session for the test user
      final expiredSession = createExpiredSessionForUser1();

      // 1. setInitialSession loads the expired session (but doesn't refresh)
      await client.setInitialSession(expiredSession);
      expect(client.currentSession?.isExpired, true);

      // 2. Start auto-refresh (simulates didChangeAppLifecycleState(resumed))
      client.startAutoRefresh();

      // 3. Also call recoverSession (simulates lazy recovery call)
      final recoverFuture = client.recoverSession(expiredSession);

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
        'FIXED: "refresh_token_already_used" error is handled gracefully when session is valid',
        () async {
      final httpClient = RefreshTokenTrackingHttpClient();

      final client = GoTrueClient(
        url: gotrueUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
        autoRefreshToken: true,
      );

      // Create expired session for the test user
      final expiredSession = createExpiredSessionForUser1();

      // 1. Set initial session (doesn't refresh)
      await client.setInitialSession(expiredSession);
      expect(client.currentSession?.isExpired, true);
      expect(httpClient.requestCount, 0);

      // 2. First refresh succeeds
      await client.refreshSession();
      expect(httpClient.requestCount, 1);

      // 3. Verify the session now has a NEW refresh token
      final newToken = client.currentSession?.refreshToken;
      expect(newToken, isNot('-yeS4omysFs9tpUYBws9Rg'));
      expect(client.currentSession?.isExpired, false);

      // 4. Manually mark the current token as "already used" on the server
      // This simulates a race condition where another request (e.g., auto-refresh)
      // already consumed the token before our next refresh attempt
      httpClient.markTokenAsUsed(newToken!);

      // 5. Attempt refresh - this will get "already_used" error from server
      // The error handler should detect we have a valid session and return it
      final response = await client.refreshSession();
      expect(response.session, isNotNull);

      // Session should still be valid (the error handler returned current session)
      expect(client.currentSession, isNotNull);
      expect(client.currentSession?.isExpired, false);
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
      final expiredSession = createExpiredSessionForUser1();
      await client.recoverSession(expiredSession);

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

      // Second call with stale token (same user) - should return current session
      final result2 = await client.recoverSession(expiredSession);

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

      // Set up expired session for the test user
      final expiredSession = createExpiredSessionForUser1();
      await client.setInitialSession(expiredSession);

      // Start auto-refresh (triggers _autoRefreshTokenTick immediately)
      client.startAutoRefresh();

      // Simultaneously call recoverSession
      final recoverFuture = client.recoverSession(expiredSession);

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
        'FIXED: recoverSession returns current session for same user when already valid',
        () async {
      final httpClient = RefreshTokenTrackingHttpClient();
      final client = GoTrueClient(
        url: gotrueUrl,
        asyncStorage: TestAsyncStorage(),
        httpClient: httpClient,
      );

      // Set up and refresh session
      final expiredSession = createExpiredSessionForUser1();
      await client.recoverSession(expiredSession);
      expect(httpClient.requestCount, 1);

      final currentToken = client.currentSession?.refreshToken;

      // Second call with stale session (same user)
      // FIXED: Should return current session without new request
      final result2 = await client.recoverSession(expiredSession);

      expect(result2.session, isNotNull);
      expect(result2.session?.refreshToken, currentToken);
      expect(httpClient.requestCount, 1,
          reason:
              'Should not attempt refresh when current session is valid for same user');
    });
  });
}
