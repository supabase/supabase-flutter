import 'dart:convert';

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

String _signEs256(Map<String, dynamic> payload, {String keyId = _keyId}) {
  return JWT(payload, header: {'kid': keyId}).sign(
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

  group('a token whose header algorithm does not match the matched key', () {
    String withHeaderAlgorithm(String token, String algorithm) {
      final parts = token.split('.');
      final header =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
              )
              as Map<String, dynamic>;
      final forged = base64Url
          .encode(utf8.encode(jsonEncode({...header, 'alg': algorithm})))
          .replaceAll('=', '');
      return '$forged.${parts[1]}.${parts[2]}';
    }

    void stubKeyWithoutAlgorithm() {
      mockClient.stub({
        'keys': [
          {..._publicJwk}..remove('alg'),
        ],
      }, path: '/.well-known/jwks.json');
    }

    test('is rejected when the key declares another algorithm', () async {
      final token = withHeaderAlgorithm(
        _signEs256({'sub': 'user-id'}),
        'ES384',
      );

      await expectLater(
        () => client.getClaims(token),
        throwsA(isA<AuthInvalidJwtException>()),
      );
      expect(mockClient.requestsTo('/user'), isEmpty);
    });

    test('is rejected when the key type cannot produce it', () async {
      stubKeyWithoutAlgorithm();
      final token = withHeaderAlgorithm(
        _signEs256({'sub': 'user-id'}),
        'RS256',
      );

      await expectLater(
        () => client.getClaims(token),
        throwsA(isA<AuthInvalidJwtException>()),
      );
      expect(mockClient.requestsTo('/user'), isEmpty);
    });

    test('is rejected when the curve does not fit the algorithm', () async {
      stubKeyWithoutAlgorithm();
      final token = withHeaderAlgorithm(
        _signEs256({'sub': 'user-id'}),
        'ES384',
      );

      await expectLater(
        () => client.getClaims(token),
        throwsA(isA<AuthInvalidJwtException>()),
      );
    });

    test('is rejected when an OKP key is not an EdDSA curve', () async {
      mockClient.stub({
        'keys': [
          {'kty': 'OKP', 'crv': 'X25519', 'kid': _keyId, 'x': 'AAAA'},
        ],
      }, path: '/.well-known/jwks.json');
      final token = withHeaderAlgorithm(
        _signEs256({'sub': 'user-id'}),
        'EdDSA',
      );

      await expectLater(
        () => client.getClaims(token),
        throwsA(isA<AuthInvalidJwtException>()),
      );
    });

    test('is accepted when only the key type and curve are declared', () async {
      stubKeyWithoutAlgorithm();

      final response = await client.getClaims(_signEs256({'sub': 'user-id'}));

      expect(response.claims.subject, 'user-id');
    });
  });

  test('getClaims() reuses the cached JWKS within its TTL', () async {
    final token = _signEs256({'sub': 'user-id'});

    await client.getClaims(token);
    client.jwksCachedAt = client.jwksCachedAt!.subtract(
      const Duration(minutes: 9),
    );
    await client.getClaims(token);

    expect(mockClient.requestsTo('/.well-known/jwks.json'), hasLength(1));
    expect(mockClient.requestsTo('/user'), isEmpty);
  });

  test('getClaims() refetches the JWKS once its TTL has passed', () async {
    final token = _signEs256({'sub': 'user-id'});
    await client.getClaims(token);
    client.jwksCachedAt = client.jwksCachedAt!.subtract(
      const Duration(minutes: 11),
    );
    mockClient
      ..stub({
        'keys': [
          {..._publicJwk, 'kid': 'es256-rotated-key'},
        ],
      }, path: '/.well-known/jwks.json')
      ..stub(
        {'code': 'bad_jwt', 'msg': 'invalid JWT: signed with a revoked key'},
        path: '/user',
        statusCode: 401,
      );

    await expectLater(
      () => client.getClaims(token),
      throwsA(isA<AuthApiException>()),
    );

    expect(mockClient.requestsTo('/.well-known/jwks.json'), hasLength(2));
    expect(mockClient.requestsTo('/user'), hasLength(1));
  });

  test('concurrent getClaims() calls share one JWKS request', () async {
    final token = _signEs256({'sub': 'user-id'});

    await Future.wait([
      client.getClaims(token),
      client.getClaims(token),
      client.getClaims(token),
    ]);

    expect(mockClient.requestsTo('/.well-known/jwks.json'), hasLength(1));
    expect(mockClient.requestsTo('/user'), isEmpty);
  });

  test(
    'concurrent getClaims() calls share one JWKS refetch after the TTL',
    () async {
      final token = _signEs256({'sub': 'user-id'});
      await client.getClaims(token);
      client.jwksCachedAt = client.jwksCachedAt!.subtract(
        const Duration(minutes: 11),
      );

      await Future.wait([client.getClaims(token), client.getClaims(token)]);

      expect(mockClient.requestsTo('/.well-known/jwks.json'), hasLength(2));
    },
  );

  group('a token with an unknown kid', () {
    late String unknownKeyToken;

    setUp(() async {
      await client.getClaims(_signEs256({'sub': 'user-id'}));
      unknownKeyToken = _signEs256({
        'sub': 'user-id',
      }, keyId: 'es256-unknown-key');
      mockClient.stubUser();
    });

    test('is verified through the Auth server right after a fetch', () async {
      await client.getClaims(unknownKeyToken);
      await client.getClaims(unknownKeyToken);

      expect(mockClient.requestsTo('/.well-known/jwks.json'), hasLength(1));
      expect(mockClient.requestsTo('/user'), hasLength(2));
    });

    test('refetches the JWKS once the refetch interval has passed', () async {
      client.jwksCachedAt = client.jwksCachedAt!.subtract(
        const Duration(seconds: 31),
      );
      mockClient.stub({
        'keys': [
          _publicJwk,
          {..._publicJwk, 'kid': 'es256-unknown-key'},
        ],
      }, path: '/.well-known/jwks.json');

      await client.getClaims(unknownKeyToken);
      await client.getClaims(unknownKeyToken);

      expect(mockClient.requestsTo('/.well-known/jwks.json'), hasLength(2));
      expect(mockClient.requestsTo('/user'), isEmpty);
    });
  });

  test('an empty JWKS starts the unknown kid refetch interval', () async {
    final token = _signEs256({'sub': 'user-id'});
    mockClient
      ..stub({'keys': <Object>[]}, path: '/.well-known/jwks.json')
      ..stubUser();

    await client.getClaims(token);
    await client.getClaims(token);

    expect(mockClient.requestsTo('/.well-known/jwks.json'), hasLength(1));
    expect(mockClient.requestsTo('/user'), hasLength(2));
  });

  test('an empty JWKS replaces the cached keys', () async {
    final token = _signEs256({'sub': 'user-id'});
    await client.getClaims(token);
    client.jwksCachedAt = client.jwksCachedAt!.subtract(
      const Duration(minutes: 11),
    );
    mockClient
      ..stub({'keys': <Object>[]}, path: '/.well-known/jwks.json')
      ..stubUser();

    await client.getClaims(token);
    await client.getClaims(token);

    expect(mockClient.requestsTo('/.well-known/jwks.json'), hasLength(2));
    expect(mockClient.requestsTo('/user'), hasLength(2));
  });
}
