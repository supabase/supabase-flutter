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

const _rsaKeyId = 'rs256-test-key';

const _rsaPrivateKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDSQqOCgK/EU/21
UPOaD5ssqE5sj97kM5921JA4p+PQKNUAyJBYZZQHqRdmzWgr3K6siXoh3aPZMqF+
g0x4qZxUJXrYCtOlpSVrK6Qw9O45TX4IVDMtgOrhLPnWC5SYZC43r3s+UKMwV0E1
aStnnB3y0gOQYznWTAlIrdARncHjZ7NLTbvfPFSiBxWyTZmMLI7TzI8amukGcu6x
Ad/oYqjNwty6POAKFvlhP7j6cRJv+SsHeKZSVoUqoli0x89S3vA+P5Q61iQpk9+W
BCPWWfvqksVSJAj0vRykUVr+TMX5+lWyNK445uCIrQwfHGET+nNa0OAqVXRNHz4f
8P/Fp2QBAgMBAAECggEAMAZKhI9SFjy88UIZMfIolk2nBALkfSkRXjn06wvl6/C3
niMxXQ9ufUVw8+ksxv/z4bLQ85VFTGHVIyloORM8grfA1EG8z9PltRHVwdzf4LTD
ebGJsvYEMARu2CXy/c+8AroRI02VyH/VhBaOdG7jJEg1yi/v0POzFyekI7HtzDvE
BYFurbe915EZLKN5Jsju5iwjkdMSOm6A0ooVYG/oSaNkKS1JLOQzao0jE8A1rK5E
4/gMYhLzw5sRvRXt7TNX4BdE+uiPQ04q4Nx6FEACeZE1hZaihjytCrsoo6z24hgq
5ihBVdciyPjksGS+GVLf+ytPk/FqGHT8YGkAgjvoJQKBgQD893A+LdG6hAeUOYAp
fFurLguXyrrZeiNISR0mIV4SDAIsv+pHOwiiZNksCUgYXQXvMqguoQsCz8pnLeA0
Qo5c7RpUTtJJaWRiWsSs3bgsxpTHTslN5v4fs374/LfL5Y6rRZ1rMTulyl8xv9Qq
MhbU0RdhBd3qPgTqB9Ixnaq5FwKBgQDUyBmM02QTmsZ9+HDZ3hT17X79rLGpfeYT
MOUe12WUQCi9TsPFoVGdJIMviGNj2hHe6Xl/cAuIiUdBKxtWzrCRV8LyNRUtB+MK
QQ537wCKuQHj1VjqetG6Ih+b81wex5jzs2P7SQ8T0T3Vj8aogcsbXWQlFDP8VjqN
MOlqCXhKpwKBgDNgFX2rVJLqyZdC7lJ+nSdw3I3hcH1Gnu/JWZAq6q4DnlV0TKJW
zPQeQzT8VZYNHm1r/lgqANB7XwIBgS1b7wnUZaqFr5OVQfvvr03kYclGM2UfDScz
KJ1LmRf8S1+vqYADTWs9vn13UkoKSY6gSZ7DMFpWFLHEEr9tAzVsbgXVAoGBAMCW
P/HjXuATpXZcyB+ZT1Vr2RXXGZJz3isehTJN+KWfEICPashUg178rjP2eSbmOGiO
3yYGDppMzg5g6sS+HLfgPBUnEHyKd+dPDL5mtxHX86r37huEgJC80+k98fH17C0e
/+5vqNLh/tpt4HuhxmiFNeANkiPhE+u5CnqsCZFfAoGBAMRJMhSGyKgJAIP0ENYI
iWm8HH6Euu7T15SyKc1/3SfcDpWoLb2AZOVFWs/+dviPrque/3x/0KMLzb245ZCR
zt70o10sR9tP0w3BlDCDTi0tMUhBZ/Mn0EprBeM+YvznyUPw8GDDHkmpOhWkBFWu
gYJHXjWh4edMFED3mdlJN15l
-----END PRIVATE KEY-----''';

const _rsaPublicJwk = {
  'kty': 'RSA',
  'use': 'sig',
  'alg': 'RS256',
  'kid': _rsaKeyId,
  'n':
      '0kKjgoCvxFP9tVDzmg-bLKhObI_e5DOfdtSQOKfj0CjVAMiQWGWUB6kXZs1oK9yu'
      'rIl6Id2j2TKhfoNMeKmcVCV62ArTpaUlayukMPTuOU1-CFQzLYDq4Sz51guUmGQu'
      'N697PlCjMFdBNWkrZ5wd8tIDkGM51kwJSK3QEZ3B42ezS0273zxUogcVsk2ZjCyO'
      '08yPGprpBnLusQHf6GKozcLcujzgChb5YT-4-nESb_krB3imUlaFKqJYtMfPUt7w'
      'Pj-UOtYkKZPflgQj1ln76pLFUiQI9L0cpFFa_kzF-fpVsjSuOObgiK0MHxxhE_pz'
      'WtDgKlV0TR8-H_D_xadkAQ',
  'e': 'AQAB',
};

String _signEs256(
  Map<String, dynamic> payload, {
  String keyId = _keyId,
  Duration expiresIn = const Duration(hours: 1),
}) {
  return JWT(payload, header: {'kid': keyId}).sign(
    ECPrivateKey(_privateKeyPem),
    algorithm: JWTAlgorithm.ES256,
    expiresIn: expiresIn,
  );
}

String _signRs256(
  Map<String, dynamic> payload, {
  Duration expiresIn = const Duration(hours: 1),
}) {
  return JWT(payload, header: {'kid': _rsaKeyId}).sign(
    RSAPrivateKey(_rsaPrivateKeyPem),
    algorithm: JWTAlgorithm.RS256,
    expiresIn: expiresIn,
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

  group('an expired asymmetric token', () {
    const expired = Duration(hours: -1);

    test('is rejected by default for ES256', () async {
      final token = _signEs256({'sub': 'user-id'}, expiresIn: expired);

      await expectLater(
        () => client.getClaims(token),
        throwsA(isA<AuthException>()),
      );
    });

    test('is accepted for ES256 with allowExpired', () async {
      final token = _signEs256({'sub': 'user-id'}, expiresIn: expired);

      final response = await client.getClaims(
        token,
        const GetClaimsOptions(allowExpired: true),
      );

      expect(response.claims.subject, 'user-id');
      expect(response.header.algorithm, 'ES256');
      expect(mockClient.requestsTo('/user'), isEmpty);
    });

    test('is accepted for RS256 with allowExpired', () async {
      mockClient.stub({
        'keys': [_rsaPublicJwk],
      }, path: '/.well-known/jwks.json');
      final token = _signRs256({'sub': 'user-id'}, expiresIn: expired);

      final response = await client.getClaims(
        token,
        const GetClaimsOptions(allowExpired: true),
      );

      expect(response.claims.subject, 'user-id');
      expect(response.header.algorithm, 'RS256');
      expect(mockClient.requestsTo('/user'), isEmpty);
    });

    test('still fails signature verification with allowExpired', () async {
      final token = _signEs256({'sub': 'user-id'}, expiresIn: expired);
      final parts = token.split('.');
      final forgedPayload = _signEs256({
        'sub': 'other-user',
      }, expiresIn: expired).split('.')[1];

      await expectLater(
        () => client.getClaims(
          '${parts[0]}.$forgedPayload.${parts[2]}',
          const GetClaimsOptions(allowExpired: true),
        ),
        throwsA(isA<AuthInvalidJwtException>()),
      );
    });
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
