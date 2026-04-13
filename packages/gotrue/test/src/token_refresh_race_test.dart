import 'dart:async';
import 'dart:convert';

import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

import '../utils.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> get _mockUserJson => {
      'id': 'mock-user-id',
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'mock@example.com',
      'app_metadata': {
        'provider': 'email',
        'providers': ['email'],
      },
      'user_metadata': {},
      'created_at': '2024-01-01T00:00:00.000Z',
      'updated_at': '2024-01-01T00:00:00.000Z',
    };

String _makeRawJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  const sig = 'AAAA';
  return '$header.$body.$sig';
}

String _freshAccessToken({String sub = 'mock-user-id'}) {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final iat = exp - 3600;
  return _makeRawJwt({'exp': exp, 'iat': iat, 'sub': sub});
}

String _tokenResponseJson({
  String refreshToken = 'new-refresh-token',
}) {
  final at = _freshAccessToken();
  return jsonEncode({
    'access_token': at,
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': refreshToken,
    'user': _mockUserJson,
  });
}

// ---------------------------------------------------------------------------
// Mock HTTP client with controllable delay on /token requests
// ---------------------------------------------------------------------------

class _DelayedTokenMockClient extends BaseClient {
  int tokenRequestCount = 0;

  /// Completer that controls when the /token response is released.
  /// When null, /token responds immediately.
  Completer<void>? tokenGate;

  /// If set, /token returns this status code instead of 200.
  int? tokenStatusOverride;

  /// The refresh token to include in the /token response.
  String responseRefreshToken = 'new-refresh-token';

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final path = request.url.path;

    // POST /token — refresh
    if (path.contains('/token')) {
      tokenRequestCount++;

      // Wait for the gate to open before responding.
      if (tokenGate != null) {
        await tokenGate!.future;
      }

      if (tokenStatusOverride != null) {
        return StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Token has been revoked',
          }))),
          tokenStatusOverride!,
        );
      }

      return StreamedResponse(
        Stream.value(utf8.encode(_tokenResponseJson(
          refreshToken: responseRefreshToken,
        ))),
        200,
      );
    }

    // GET /user
    if (path.endsWith('/user')) {
      return StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(_mockUserJson))),
        200,
      );
    }

    // POST /logout
    if (path.contains('/logout')) {
      return StreamedResponse(Stream.empty(), 204);
    }

    return StreamedResponse(Stream.empty(), 404);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _DelayedTokenMockClient mockClient;
  late GoTrueClient client;

  GoTrueClient makeClient() {
    return GoTrueClient(
      url: 'https://example.supabase.co',
      httpClient: mockClient,
      asyncStorage: TestAsyncStorage(),
      autoRefreshToken: false,
    );
  }

  setUp(() {
    mockClient = _DelayedTokenMockClient();
    client = makeClient();
  });

  group('Token refresh race conditions', () {
    test('signOut during in-flight refresh does not restore session', () async {
      // Gate the /token response so we can interleave a signOut.
      mockClient.tokenGate = Completer<void>();

      // Start a refresh (it will block on the gate).
      final refreshFuture = client.setSession('old-refresh-token');

      // Give the event loop a tick so the HTTP request is in-flight.
      await Future<void>.delayed(Duration.zero);

      // Sign out while refresh is pending.
      await client.signOut();
      expect(client.currentSession, isNull);

      // Release the /token response.
      mockClient.tokenGate!.complete();

      // The refresh should complete without error (result is discarded).
      await refreshFuture;

      // Session must still be null — signOut must not be undone.
      expect(client.currentSession, isNull);
    });

    test('signIn during in-flight refresh preserves new session', () async {
      mockClient.tokenGate = Completer<void>();

      // Start a refresh with the old token (blocked on gate).
      final refreshFuture = client.setSession('old-refresh-token');
      await Future<void>.delayed(Duration.zero);

      // Meanwhile, set a new session via the fast path (valid access token).
      // This bypasses the refresh queue entirely and writes _currentSession
      // immediately, bumping _sessionVersion.
      final freshAt = _freshAccessToken();
      await client.setSession(
        'new-signin-refresh-token',
        accessToken: freshAt,
      );
      expect(client.currentSession?.refreshToken, 'new-signin-refresh-token');

      // Release the old refresh response.
      mockClient.tokenGate!.complete();
      await refreshFuture;

      // The old refresh must NOT have overwritten the new session.
      expect(
        client.currentSession?.refreshToken,
        'new-signin-refresh-token',
      );
    });

    test('concurrent refresh with same token deduplicates', () async {
      // Fire two refreshSession calls concurrently with the same token.
      final results = await Future.wait([
        client.setSession('same-token'),
        client.setSession('same-token'),
      ]);

      // Both should return the same access token (same network request).
      expect(results[0].session?.accessToken, isNotNull);
      expect(
        results[0].session?.accessToken,
        results[1].session?.accessToken,
      );

      // Only one /token request should have been made.
      expect(mockClient.tokenRequestCount, 1);
    });

    test('concurrent refresh with different tokens serializes', () async {
      final completionOrder = <String>[];

      mockClient.responseRefreshToken = 'response-A';
      final future1 = client.setSession('token-A').then((r) {
        completionOrder.add('A');
        return r;
      });

      mockClient.responseRefreshToken = 'response-B';
      final future2 = client.setSession('token-B').then((r) {
        completionOrder.add('B');
        return r;
      });

      await Future.wait([future1, future2]);

      // Two separate HTTP requests should have been made.
      expect(mockClient.tokenRequestCount, 2);

      // They should have executed sequentially: A before B.
      expect(completionOrder, ['A', 'B']);
    });

    test('dispose completes active refresh with error', () async {
      mockClient.tokenGate = Completer<void>();

      final refreshFuture = client.setSession('some-token');
      await Future<void>.delayed(Duration.zero);

      client.dispose();

      await expectLater(
        refreshFuture,
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Disposed',
        )),
      );
    });

    test(
        'refresh failure does not sign out '
        'if session changed during refresh', () async {
      mockClient.tokenGate = Completer<void>();
      mockClient.tokenStatusOverride = 400; // non-retryable error

      // Start a refresh that will fail.
      final refreshFuture = client.setSession('old-token');
      await Future<void>.delayed(Duration.zero);

      // While the refresh is pending, set a new valid session (fast path).
      final freshAt = _freshAccessToken();
      await client.setSession(
        'new-refresh-token',
        accessToken: freshAt,
      );
      expect(client.currentSession, isNotNull);
      expect(client.currentSession?.refreshToken, 'new-refresh-token');

      // Release the failing refresh response.
      mockClient.tokenGate!.complete();

      // The refresh should fail, but not sign out the user.
      await expectLater(refreshFuture, throwsA(isA<AuthException>()));

      // New session must still be intact.
      expect(client.currentSession, isNotNull);
      expect(client.currentSession?.refreshToken, 'new-refresh-token');
    });

    test('signOut event is emitted when refresh fails and session is unchanged',
        () async {
      final events = <AuthChangeEvent>[];
      client.onAuthStateChange.listen((state) {
        events.add(state.event);
      });

      // Set an initial session.
      final freshAt = _freshAccessToken();
      await client.setSession('initial-token', accessToken: freshAt);
      events.clear();

      // Now make a refresh that will fail with a non-retryable error.
      mockClient.tokenStatusOverride = 400;

      try {
        await client.refreshSession('initial-token');
      } catch (_) {}

      // Without any concurrent session changes, the failure should sign out.
      expect(client.currentSession, isNull);
      expect(events, contains(AuthChangeEvent.signedOut));
    });
  });
}
