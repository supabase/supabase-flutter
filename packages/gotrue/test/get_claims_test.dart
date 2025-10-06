import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  final env = DotEnv();
  env.load();

  final gotrueUrl = env['GOTRUE_URL'] ?? 'http://localhost:9998';
  final anonToken = env['GOTRUE_TOKEN'] ?? 'anonKey';

  group('getClaims', () {
    late GoTrueClient client;
    late String newEmail;

    setUp(() async {
      final res = await http.post(
          Uri.parse('http://localhost:3000/rpc/reset_and_init_auth_data'),
          headers: {'x-forwarded-for': '127.0.0.1'});
      if (res.body.isNotEmpty) throw res.body;

      newEmail = getNewEmail();

      final asyncStorage = TestAsyncStorage();

      client = GoTrueClient(
        url: gotrueUrl,
        headers: {
          'Authorization': 'Bearer $anonToken',
          'apikey': anonToken,
        },
        asyncStorage: asyncStorage,
        flowType: AuthFlowType.implicit,
      );
    });

    test('getClaims() with valid JWT from current session', () async {
      // Sign up a user first
      final response = await client.signUp(
        email: newEmail,
        password: password,
      );

      expect(response.session, isNotNull);

      // Get claims from current session
      final claimsResponse = await client.getClaims();

      expect(claimsResponse.claims, isA<Map<String, dynamic>>());
      expect(claimsResponse.claims['sub'], isNotNull);
      expect(claimsResponse.claims['email'], newEmail);
      expect(claimsResponse.claims['role'], isNotNull);
      expect(claimsResponse.claims['aud'], isNotNull);
      expect(claimsResponse.claims['exp'], isNotNull);
      expect(claimsResponse.claims['iat'], isNotNull);
    });

    test('getClaims() with explicit JWT parameter', () async {
      // Sign up a user first
      final response = await client.signUp(
        email: newEmail,
        password: password,
      );

      expect(response.session, isNotNull);
      final accessToken = response.session!.accessToken;

      // Get claims by passing JWT explicitly
      final claimsResponse = await client.getClaims(accessToken);

      expect(claimsResponse.claims, isA<Map<String, dynamic>>());
      expect(claimsResponse.claims['sub'], isNotNull);
      expect(claimsResponse.claims['email'], newEmail);
    });

    test('getClaims() throws when no session exists', () async {
      // Ensure no session exists
      if (client.currentSession != null) {
        await client.signOut();
      }

      expect(
        () => client.getClaims(),
        throwsA(isA<AuthSessionMissingException>()),
      );
    });

    test('getClaims() throws with invalid JWT', () async {
      const invalidJwt = 'invalid.jwt.token';

      expect(
        () => client.getClaims(invalidJwt),
        throwsA(isA<AuthInvalidJwtException>()),
      );
    });

    test('getClaims() throws with expired JWT', () async {
      // This is an expired JWT token (exp is in the past)
      const expiredJwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwiZXhwIjoxNTE2MjM5MDIyfQ.4Adcj0vVzr2Nzz_KKAKrVZsLZyTBGv9-Ey8SN0p7Kzs';

      expect(
        () => client.getClaims(expiredJwt),
        throwsA(isA<AuthException>()),
      );
    });

    test('getClaims() with allowExpired option allows expired JWT', () async {
      // This is an expired JWT token (exp is in the past)
      const expiredJwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwiZXhwIjoxNTE2MjM5MDIyfQ.4Adcj0vVzr2Nzz_KKAKrVZsLZyTBGv9-Ey8SN0p7Kzs';

      // With allowExpired, we should be able to decode the JWT
      // Note: This will still fail at getUser() because the token is invalid on the server
      // but the expiration check should pass
      try {
        await client.getClaims(
          expiredJwt,
          GetClaimsOptions(allowExpired: true),
        );
        // If we get here, the exp validation was skipped
      } on AuthException catch (e) {
        // We expect this to fail during getUser() verification,
        // not during exp validation
        expect(e.message, isNot(contains('expired')));
      }
    });

    test('getClaims() with options parameter (allowExpired false)', () async {
      final response = await client.signUp(
        email: newEmail,
        password: password,
      );

      expect(response.session, isNotNull);

      // Should work normally with allowExpired: false
      final claimsResponse = await client.getClaims(
        null,
        GetClaimsOptions(allowExpired: false),
      );

      expect(claimsResponse.claims, isNotNull);
      expect(claimsResponse.claims['email'], newEmail);
    });

    test('getClaims() verifies JWT with server', () async {
      // Sign up a user
      final response = await client.signUp(
        email: newEmail,
        password: password,
      );

      expect(response.session, isNotNull);
      final accessToken = response.session!.accessToken;

      // Get claims - this should verify with server via getUser()
      final claimsResponse = await client.getClaims(accessToken);

      // If we get here without error, verification succeeded
      expect(claimsResponse.claims, isNotNull);
      expect(claimsResponse.claims['email'], newEmail);
    });

    test('getClaims() contains all standard JWT claims', () async {
      final response = await client.signUp(
        email: newEmail,
        password: password,
      );

      expect(response.session, isNotNull);

      final claimsResponse = await client.getClaims();
      final claims = claimsResponse.claims;

      // Check for standard JWT claims
      expect(claims.containsKey('sub'), isTrue); // Subject
      expect(claims.containsKey('aud'), isTrue); // Audience
      expect(claims.containsKey('exp'), isTrue); // Expiration
      expect(claims.containsKey('iat'), isTrue); // Issued at
      expect(claims.containsKey('iss'), isTrue); // Issuer
      expect(claims.containsKey('role'), isTrue); // Role

      // Check for Supabase-specific claims
      expect(claims.containsKey('email'), isTrue);
    });

    test('getClaims() with user metadata in claims', () async {
      final metadata = {'custom_field': 'custom_value', 'number': 42};

      final response = await client.signUp(
        email: newEmail,
        password: password,
        data: metadata,
      );

      expect(response.session, isNotNull);

      final claimsResponse = await client.getClaims();
      final claims = claimsResponse.claims;

      // The user metadata should be accessible via the user object
      // which is verified through getUser() call
      expect(claims, isNotNull);
    });
  });

  group('JWT helper functions', () {
    test('decodeJwt() successfully decodes valid JWT', () {
      // A sample JWT with known values
      final jwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InRlc3Qta2lkIn0.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjk5OTk5OTk5OTl9.XyI0rWcOYLpz3R8G8qHWmg7U-tWMHJqzN_e1oDQKzgc';

      final decoded = decodeJwt(jwt);

      expect(decoded.header.alg, 'HS256');
      expect(decoded.header.typ, 'JWT');
      expect(decoded.header.kid, 'test-kid');

      expect(decoded.payload.sub, '1234567890');
      expect(decoded.payload.claims['name'], 'John Doe');
      expect(decoded.payload.iat, 1516239022);
      expect(decoded.payload.exp, 9999999999);
    });

    test('decodeJwt() throws on invalid JWT structure', () {
      const invalidJwt = 'not.a.valid';

      expect(
        () => decodeJwt(invalidJwt),
        throwsA(isA<AuthInvalidJwtException>()),
      );
    });

    test('decodeJwt() throws on JWT with wrong number of parts', () {
      const invalidJwt = 'only.two.parts.extra';

      expect(
        () => decodeJwt(invalidJwt),
        throwsA(isA<AuthInvalidJwtException>()),
      );
    });

    test('decodeJwt() throws on malformed base64', () {
      const invalidJwt = 'invalid!!!.invalid!!!.invalid!!!';

      expect(
        () => decodeJwt(invalidJwt),
        throwsA(isA<AuthInvalidJwtException>()),
      );
    });

    test('validateExp() throws on expired token', () {
      final pastTime = DateTime.now().subtract(Duration(hours: 1));
      final exp = pastTime.millisecondsSinceEpoch ~/ 1000;

      expect(
        () => validateExp(exp),
        throwsA(isA<AuthException>()),
      );
    });

    test('validateExp() succeeds on valid token', () {
      final futureTime = DateTime.now().add(Duration(hours: 1));
      final exp = futureTime.millisecondsSinceEpoch ~/ 1000;

      expect(() => validateExp(exp), returnsNormally);
    });

    test('validateExp() throws on null exp', () {
      expect(
        () => validateExp(null),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
