import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import '../utils.dart';

// Minimal user payload accepted by User.fromJson.
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

void main() {
  late MockSupabaseHttpClient mockClient;
  late AuthClient client;

  setUp(() {
    mockClient = MockSupabaseHttpClient()
      ..stubUser(user: _mockUserJson)
      // Refresh-token fallback response with a freshly minted access token.
      ..stubHandler((_) {
        final expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
        return jsonResponse({
          'access_token': unsignedTestJwt({
            'exp': expiresAt,
            'iat': expiresAt - 3600,
            'sub': 'mock-user-id',
          }),
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'new-refresh-token',
          'user': _mockUserJson,
        });
      }, path: '/token');
    client = AuthClient(
      url: 'https://example.supabase.co',
      httpClient: mockClient,
      asyncStorage: TestAsyncStorage(),
    );
  });

  group('setSession — validation edge cases', () {
    test('empty refresh token with a non-null access token throws before '
        'inspecting the access token', () async {
      final expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      final accessToken = unsignedTestJwt({
        'exp': expiresAt,
        'iat': expiresAt - 3600,
        'sub': 'mock-user-id',
      });

      await expectLater(
        client.setSession('', accessToken: accessToken),
        throwsA(isA<AuthSessionMissingException>()),
      );
      // No network call should have been made.
      expect(mockClient.requestsTo('/user'), isEmpty);
    });

    test('access token with exp within the 30-second expiry margin is treated '
        'as expired and falls back to the refresh-token path', () async {
      final timeNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // exp is 20 s in the future, inside the 30 s AuthConstants.expiryMargin.
      final accessToken = unsignedTestJwt({
        'exp': timeNow + 20,
        'iat': timeNow - 3580,
        'sub': 'mock-user-id',
      });

      final response = await client.setSession(
        'some-refresh-token',
        accessToken: accessToken,
      );

      expect(response.session, isNotNull);
      // The returned token must be the freshly refreshed one, not our
      // near-expired JWT.
      expect(response.session?.accessToken, isNot(equals(accessToken)));
      expect(mockClient.requestsTo('/user'), isEmpty); // /user was NOT called
    });

    test('access token with no exp claim is treated as expired and falls back '
        'to the refresh-token path', () async {
      // JWT without an exp claim: decodeJwt succeeds but exp == null.
      final accessToken = unsignedTestJwt({
        'role': 'authenticated',
        'sub': 'mock-user-id',
      });

      final response = await client.setSession(
        'some-refresh-token',
        accessToken: accessToken,
      );

      expect(response.session, isNotNull);
      expect(response.session?.accessToken, isNot(equals(accessToken)));
      expect(mockClient.requestsTo('/user'), isEmpty);
    });
  });

  group('setSession — fast path session fields', () {
    test(
      'expiresIn equals exp minus iat when both claims are present',
      () async {
        final issuedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
        final expiresAt = issuedAt + 3600;
        final accessToken = unsignedTestJwt({
          'exp': expiresAt,
          'iat': issuedAt,
          'sub': 'mock-user-id',
        });

        final response = await client.setSession(
          'some-refresh-token',
          accessToken: accessToken,
        );

        // expiresIn should be the total token lifetime (exp - iat = 3600).
        expect(response.session?.expiresIn, equals(expiresAt - issuedAt));
      },
    );

    test('expiresIn is null when iat claim is absent', () async {
      final expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      // JWT without iat.
      final accessToken = unsignedTestJwt({
        'exp': expiresAt,
        'sub': 'mock-user-id',
      });

      final response = await client.setSession(
        'some-refresh-token',
        accessToken: accessToken,
      );

      expect(response.session?.expiresIn, isNull);
    });

    test('expiresAt matches the exp claim in the JWT', () async {
      final issuedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
      final expiresAt = issuedAt + 3600;
      final accessToken = unsignedTestJwt({
        'exp': expiresAt,
        'iat': issuedAt,
        'sub': 'mock-user-id',
      });

      final response = await client.setSession(
        'some-refresh-token',
        accessToken: accessToken,
      );

      // expiresAt is re-derived from the JWT's own exp, not from expiresIn.
      expect(
        response.session?.expiresAt,
        equals(
          DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true),
        ),
      );
    });

    test(
      'returned session preserves the supplied access and refresh tokens',
      () async {
        final issuedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
        final expiresAt = issuedAt + 3600;
        const refreshToken = 'my-refresh-token';
        final accessToken = unsignedTestJwt({
          'exp': expiresAt,
          'iat': issuedAt,
          'sub': 'mock-user-id',
        });

        final response = await client.setSession(
          refreshToken,
          accessToken: accessToken,
        );

        expect(response.session?.accessToken, equals(accessToken));
        expect(response.session?.refreshToken, equals(refreshToken));
        expect(response.session?.tokenType, equals('bearer'));
      },
    );
  });

  group('setSession — auth state events', () {
    test('fast path emits signedIn (not tokenRefreshed)', () async {
      final issuedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
      final expiresAt = issuedAt + 3600;
      final accessToken = unsignedTestJwt({
        'exp': expiresAt,
        'iat': issuedAt,
        'sub': 'mock-user-id',
      });

      expect(
        client.onAuthStateChange,
        emitsInOrder([
          predicate<AuthState>(
            (s) => s.event == AuthChangeEvent.initialSession,
          ),
          predicate<AuthState>((s) => s.event == AuthChangeEvent.signedIn),
        ]),
      );

      await client.setSession('some-refresh-token', accessToken: accessToken);
    });

    test('expired-fallback path emits tokenRefreshed (not signedIn)', () async {
      final timeNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // Clearly expired token (exp well in the past).
      final accessToken = unsignedTestJwt({
        'exp': timeNow - 100,
        'iat': timeNow - 3700,
        'sub': 'mock-user-id',
      });

      expect(
        client.onAuthStateChange,
        emitsInOrder([
          predicate<AuthState>(
            (s) => s.event == AuthChangeEvent.initialSession,
          ),
          predicate<AuthState>(
            (s) => s.event == AuthChangeEvent.tokenRefreshed,
          ),
        ]),
      );

      await client.setSession('some-refresh-token', accessToken: accessToken);
    });
  });
}
