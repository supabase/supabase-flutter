import 'dart:async';
import 'dart:convert';

import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart';
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
        'providers': ['email']
      },
      'user_metadata': {},
      'created_at': '2024-01-01T00:00:00.000Z',
      'updated_at': '2024-01-01T00:00:00.000Z',
    };

/// Mock HTTP client for setSession tests.
///
/// Handles `GET /user` (returns [_mockUserJson]) and
/// `POST /token` (returns a fresh session via the refresh path).
class _SetSessionMockClient extends BaseClient {
  int userCallCount = 0;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (request.url.path.endsWith('/user')) {
      userCallCount++;
      return StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(_mockUserJson))),
        200,
      );
    }

    if (request.url.path.contains('/token')) {
      // Refresh-token fallback response with a freshly minted access token.
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      final iat = exp - 3600;
      final freshAt =
          _makeRawJwt({'exp': exp, 'iat': iat, 'sub': 'mock-user-id'});
      return StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'access_token': freshAt,
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'new-refresh-token',
          'user': _mockUserJson,
        }))),
        200,
      );
    }

    return StreamedResponse(Stream.empty(), 404);
  }
}

/// Crafts a JWT by base64url-encoding [payload] directly.
///
/// Unlike using dart_jsonwebtoken, this gives exact control over every claim —
/// no auto-injected `iat`, no claim overrides. The signature is a stub;
/// [decodeJwt] does not verify signatures.
String _makeRawJwt(Map<String, dynamic> payload) {
  final header =
      base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  const sig = 'AAAA';
  return '$header.$body.$sig';
}

void main() {
  late _SetSessionMockClient mockClient;
  late GoTrueClient client;

  setUp(() {
    mockClient = _SetSessionMockClient();
    client = GoTrueClient(
      url: 'https://example.supabase.co',
      httpClient: mockClient,
      asyncStorage: TestAsyncStorage(),
    );
  });

  group('setSession — validation edge cases', () {
    test(
        'empty refresh token with a non-null access token throws before '
        'inspecting the access token', () async {
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      final at =
          _makeRawJwt({'exp': exp, 'iat': exp - 3600, 'sub': 'mock-user-id'});

      await expectLater(
        () => client.setSession('', accessToken: at),
        throwsA(isA<AuthSessionMissingException>()),
      );
      // No network call should have been made.
      expect(mockClient.userCallCount, 0);
    });

    test(
        'access token with exp within the 30-second expiry margin is treated '
        'as expired and falls back to the refresh-token path', () async {
      final timeNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // exp is 20 s in the future, inside the 30 s Constants.expiryMargin.
      final at = _makeRawJwt(
          {'exp': timeNow + 20, 'iat': timeNow - 3580, 'sub': 'mock-user-id'});

      final response =
          await client.setSession('some-refresh-token', accessToken: at);

      expect(response.session, isNotNull);
      // The returned token must be the freshly refreshed one, not our near-expired JWT.
      expect(response.session?.accessToken, isNot(equals(at)));
      expect(mockClient.userCallCount, 0); // /user was NOT called
    });

    test(
        'access token with no exp claim is treated as expired and falls back '
        'to the refresh-token path', () async {
      // JWT without an exp claim: decodeJwt succeeds but exp == null.
      final at = _makeRawJwt({'role': 'authenticated', 'sub': 'mock-user-id'});

      final response =
          await client.setSession('some-refresh-token', accessToken: at);

      expect(response.session, isNotNull);
      expect(response.session?.accessToken, isNot(equals(at)));
      expect(mockClient.userCallCount, 0);
    });
  });

  group('setSession — fast path session fields', () {
    test('expiresIn equals exp minus iat when both claims are present',
        () async {
      final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
      final exp = iat + 3600;
      final at = _makeRawJwt({'exp': exp, 'iat': iat, 'sub': 'mock-user-id'});

      final response =
          await client.setSession('some-refresh-token', accessToken: at);

      // expiresIn should be the total token lifetime (exp - iat = 3600).
      expect(response.session?.expiresIn, equals(exp - iat));
    });

    test('expiresIn is null when iat claim is absent', () async {
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      // JWT without iat.
      final at = _makeRawJwt({'exp': exp, 'sub': 'mock-user-id'});

      final response =
          await client.setSession('some-refresh-token', accessToken: at);

      expect(response.session?.expiresIn, isNull);
    });

    test('expiresAt matches the exp claim in the JWT', () async {
      final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
      final exp = iat + 3600;
      final at = _makeRawJwt({'exp': exp, 'iat': iat, 'sub': 'mock-user-id'});

      final response =
          await client.setSession('some-refresh-token', accessToken: at);

      // expiresAt is re-derived from the JWT's own exp, not from expiresIn.
      expect(response.session?.expiresAt, equals(exp));
    });

    test('returned session preserves the supplied access and refresh tokens',
        () async {
      final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
      final exp = iat + 3600;
      const refreshToken = 'my-refresh-token';
      final at = _makeRawJwt({'exp': exp, 'iat': iat, 'sub': 'mock-user-id'});

      final response = await client.setSession(refreshToken, accessToken: at);

      expect(response.session?.accessToken, equals(at));
      expect(response.session?.refreshToken, equals(refreshToken));
      expect(response.session?.tokenType, equals('bearer'));
    });
  });

  group('setSession — auth state events', () {
    test('fast path emits signedIn (not tokenRefreshed)', () async {
      final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
      final exp = iat + 3600;
      final at = _makeRawJwt({'exp': exp, 'iat': iat, 'sub': 'mock-user-id'});

      expect(
        client.onAuthStateChange,
        emits(predicate<AuthState>((s) => s.event == AuthChangeEvent.signedIn)),
      );

      await client.setSession('some-refresh-token', accessToken: at);
    });

    test('expired-fallback path emits tokenRefreshed (not signedIn)', () async {
      final timeNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // Clearly expired token (exp well in the past).
      final at = _makeRawJwt(
          {'exp': timeNow - 100, 'iat': timeNow - 3700, 'sub': 'mock-user-id'});

      expect(
        client.onAuthStateChange,
        emits(predicate<AuthState>(
            (s) => s.event == AuthChangeEvent.tokenRefreshed)),
      );

      await client.setSession('some-refresh-token', accessToken: at);
    });
  });
}
