import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

const _keyId = 'es256-test-key';

const _privateKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgU5tTXVLtdEGz6Bh/
XWOSQLV3vZRowQ4Z9K7LsDd7qIOhRANCAASBy2x7Sh02aXcbrcd9TsEhnjM5jc+t
zCULvTTfUoafCpP7sRWi7dgHeYLniWRp8ygSInepsXyWKo17LMRNbzkQ
-----END PRIVATE KEY-----''';

const _publicJwk = {
  'kty': 'EC',
  'use': 'sig',
  'crv': 'P-256',
  'alg': 'ES256',
  'kid': _keyId,
  'x': 'gctse0odNml3G63HfU7BIZ4zOY3PrcwlC70031KGnwo',
  'y': 'k_uxFaLt2Ad5gueJZGnzKBIid6mxfJYqjXssxE1vORA',
};

String _signEs256(Map<String, dynamic> payload) {
  return JWT(payload, header: {'kid': _keyId}).sign(
    ECPrivateKey(_privateKeyPem),
    algorithm: JWTAlgorithm.ES256,
    expiresIn: const Duration(hours: 1),
  );
}

void main() {
  late AuthClient client;
  late MockSupabaseHttpClient mockClient;

  setUp(() {
    mockClient = MockSupabaseHttpClient()
      ..stub({
        'keys': [_publicJwk],
      }, path: '/.well-known/jwks.json');
    client = AuthClient(
      url: 'https://example.com',
      httpClient: mockClient,
      asyncStorage: TestAsyncStorage(),
    );
  });

  test('getClaims() verifies an ES256 token against the JWKS', () async {
    final token = _signEs256({'sub': 'user-id', 'role': 'authenticated'});

    final response = await client.getClaims(token);

    expect(response.claims.subject, 'user-id');
    expect(response.header.algorithm, 'ES256');
    expect(mockClient.requestsTo('/user'), isEmpty);
  });

  test('getClaims() rejects an ES256 token with a tampered payload', () async {
    final token = _signEs256({'sub': 'user-id'});
    final parts = token.split('.');
    final forgedPayload = _signEs256({'sub': 'other-user'}).split('.')[1];

    await expectLater(
      () => client.getClaims('${parts[0]}.$forgedPayload.${parts[2]}'),
      throwsA(isA<AuthInvalidJwtException>()),
    );
  });
}
