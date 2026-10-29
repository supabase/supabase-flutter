import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

Matcher _formatExceptionNaming(String name) => isA<FormatException>().having(
  (error) => error.message,
  'message',
  contains(name),
);

Matcher _throwsFormatExceptionNaming(String name) =>
    throwsA(_formatExceptionNaming(name));

const _timestamp = '2026-01-01T00:00:00Z';

Map<String, dynamic> _ssoProviderJson() => {
  'id': testUserId,
  'saml': {
    'entity_id': 'https://idp.example.com/metadata',
    'attribute_mapping': {
      'keys': {
        'email': {'name': 'mail'},
      },
    },
  },
  'domains': [
    {'domain': 'acme.com'},
  ],
  'created_at': _timestamp,
  'updated_at': _timestamp,
};

Map<String, dynamic> _customProviderJson() => {
  'id': testUserId,
  'provider_type': 'oidc',
  'identifier': 'custom:acme',
  'name': 'Acme',
  'client_id': 'client-id',
  'scopes': ['openid'],
  'discovery_document': {
    'issuer': 'https://idp.example.com',
    'authorization_endpoint': 'https://idp.example.com/authorize',
    'token_endpoint': 'https://idp.example.com/token',
    'jwks_uri': 'https://idp.example.com/jwks',
  },
  'created_at': _timestamp,
  'updated_at': _timestamp,
};

Map<String, dynamic> _oauthClientJson() => {
  'client_id': 'client-id',
  'client_type': 'public',
  'redirect_uris': ['https://example.com/callback'],
  'grant_types': ['authorization_code'],
  'response_types': ['code'],
  'created_at': _timestamp,
  'updated_at': _timestamp,
};

void main() {
  late MockSupabaseHttpClient httpClient;
  late AuthClient client;

  setUp(() async {
    httpClient = MockSupabaseHttpClient();
    client = AuthClient(
      url: 'http://localhost:9999',
      httpClient: httpClient,
      autoRefreshToken: false,
      asyncStorage: TestAsyncStorage(),
    );
    await signInTestUser(client);
  });

  tearDown(() => client.dispose());

  group('MFA', () {
    test(
      'enroll throws a FormatException for a totp that is not an object',
      () {
        httpClient.stub(
          {'id': 'factor-id', 'type': 'totp', 'totp': 'svg'},
          method: HttpMethod.post,
          path: '/factors',
        );

        expect(client.mfa.enroll(), _throwsFormatExceptionNaming('totp'));
      },
    );

    test('enroll throws a FormatException for a non-string secret', () {
      httpClient.stub(
        {
          'id': 'factor-id',
          'type': 'totp',
          'totp': {'qr_code': 'svg', 'secret': 1, 'uri': 'otpauth://totp'},
        },
        method: HttpMethod.post,
        path: '/factors',
      );

      expect(client.mfa.enroll(), _throwsFormatExceptionNaming('secret'));
    });

    test('enroll throws a FormatException for a phone of the wrong type', () {
      expect(
        () => AuthMFAEnrollResponse.fromJson({
          'id': 'factor-id',
          'type': 'phone',
          'phone': 1,
        }),
        _throwsFormatExceptionNaming('phone'),
      );
    });

    for (final (field, value) in [
      ('id', 1),
      ('total', '3'),
      ('remaining', null),
    ]) {
      test('recovery codes status throws for $field holding $value', () {
        final json = {'id': 'factor-id', 'total': 3, 'remaining': 2};

        expect(
          () => AuthMFARecoveryCodesStatusResponse.fromJson({
            ...json,
            field: value,
          }),
          _throwsFormatExceptionNaming(field),
        );
      });
    }

    test('recovery codes throw a FormatException for codes of the wrong '
        'type', () {
      expect(
        () => AuthMFARecoveryCodesGenerateResponse.fromJson({
          'id': 'factor-id',
          'total': 1,
          'codes': [1],
        }),
        _throwsFormatExceptionNaming('codes'),
      );
    });

    test('admin listFactors throws a FormatException for a body that is not '
        'a list', () {
      httpClient.stub(
        {'factors': <dynamic>[]},
        method: HttpMethod.get,
        path: '/admin/users/$testUserId/factors',
      );

      expect(
        client.admin.mfa.listFactors(userId: testUserId),
        _throwsFormatExceptionNaming('factors'),
      );
    });

    test('getAuthenticatorAssuranceLevel throws a FormatException for an amr '
        'that is not a list', () async {
      await signInTestUser(client, claims: {'aal': 'aal1', 'amr': 'password'});

      expect(
        client.mfa.getAuthenticatorAssuranceLevel,
        _throwsFormatExceptionNaming('amr'),
      );
    });
  });

  group('admin', () {
    test(
      'listUsers throws a FormatException for users that are not a list',
      () {
        httpClient.stub({'users': 'none'}, path: '/admin/users');

        expect(
          client.admin.listUsers(),
          _throwsFormatExceptionNaming('users'),
        );
      },
    );

    test('listUsers throws a FormatException for a missing users list', () {
      httpClient.stub(<String, dynamic>{}, path: '/admin/users');

      expect(
        client.admin.listUsers(),
        _throwsFormatExceptionNaming('users'),
      );
    });

    test('listUsers throws a FormatException for a non-string aud', () {
      httpClient.stub({
        'users': [testUserJson()],
        'aud': 1,
      }, path: '/admin/users');

      expect(client.admin.listUsers(), _throwsFormatExceptionNaming('aud'));
    });

    test('listUsers throws a FormatException for a body that is not an '
        'object', () {
      httpClient.stub([testUserJson()], path: '/admin/users');

      expect(
        client.admin.listUsers(),
        _throwsFormatExceptionNaming('user list'),
      );
    });

    test('listClients throws a FormatException for a non-numeric total', () {
      httpClient.stub({
        'clients': [_oauthClientJson()],
        'total': '1',
      }, path: '/admin/oauth/clients');

      expect(
        client.admin.oauth.listClients(),
        _throwsFormatExceptionNaming('total'),
      );
    });

    for (final (field, value) in [
      ('client_id', 1),
      ('redirect_uris', 'https://example.com/callback'),
      ('grant_types', [1]),
    ]) {
      test('OAuthClient.fromJson throws for $field holding $value', () {
        expect(
          () => OAuthClient.fromJson({..._oauthClientJson(), field: value}),
          _throwsFormatExceptionNaming(field),
        );
      });
    }

    test('admin listPasskeys throws a FormatException for an element that is '
        'not an object', () {
      httpClient.stub(
        [1],
        method: HttpMethod.get,
        path: '/admin/users/$testUserId/passkeys',
      );

      expect(
        client.admin.passkey.listPasskeys(userId: testUserId),
        _throwsFormatExceptionNaming('passkeys'),
      );
    });
  });

  group('OAuth server', () {
    test(
      'listGrants throws a FormatException for a body that is not a list',
      () {
        httpClient.stub(
          {'grants': <dynamic>[]},
          method: HttpMethod.get,
          path: '/user/oauth/grants',
        );

        expect(
          client.oauth.listGrants(),
          _throwsFormatExceptionNaming('grants'),
        );
      },
    );

    test(
      'listGrants throws a FormatException for scopes of the wrong type',
      () {
        httpClient.stub(
          [
            {
              'client': {'id': 'client-id'},
              'scopes': [1],
              'granted_at': _timestamp,
            },
          ],
          method: HttpMethod.get,
          path: '/user/oauth/grants',
        );

        expect(
          client.oauth.listGrants(),
          _throwsFormatExceptionNaming('scopes'),
        );
      },
    );

    for (final (field, value) in [
      ('authorization_id', 1),
      ('redirect_uri', null),
      ('client', 'client-id'),
      ('scope', <dynamic>[]),
    ]) {
      test('authorization details throw for $field holding $value', () {
        final json = {
          'authorization_id': 'authorization-id',
          'redirect_uri': 'https://example.com/callback',
          'client': {'id': 'client-id'},
          'user': {'id': testUserId},
        };

        expect(
          () => OAuthAuthorizationDetailsResponse.fromJson({
            ...json,
            field: value,
          }),
          _throwsFormatExceptionNaming(field),
        );
      });
    }

    test('the redirect response throws for a non-string redirect_url', () {
      expect(
        () => OAuthAuthorizationResponse.fromJson({'redirect_url': 1}),
        _throwsFormatExceptionNaming('redirect_url'),
      );
    });
  });

  group('SSO', () {
    test('reads a well formed provider', () {
      final provider = SSOProvider.fromJson(_ssoProviderJson());

      expect(provider.domains, ['acme.com']);
      expect(provider.saml?.attributeMapping?.keys['email']?.name, 'mail');
    });

    for (final (field, value) in [
      ('id', 1),
      ('disabled', 'no'),
      ('saml', 'entity'),
      ('domains', 'acme.com'),
      ('domain', 1),
      ('created_at', 1),
    ]) {
      test('SSOProvider.fromJson throws for $field holding $value', () {
        final json = _ssoProviderJson();
        if (field == 'domain') {
          json['domains'] = [
            {'domain': value},
          ];
        } else {
          json[field] = value;
        }

        expect(
          () => SSOProvider.fromJson(json),
          _throwsFormatExceptionNaming(field),
        );
      });
    }

    test('SAMLAttributeMapping.fromJson throws for an attribute that is not '
        'an object', () {
      expect(
        () => SAMLAttributeMapping.fromJson({
          'keys': {'email': 'mail'},
        }),
        _throwsFormatExceptionNaming('email'),
      );
    });

    test('listProviders throws a FormatException for items that are not a '
        'list', () {
      httpClient.stub({'items': 'none'}, path: '/admin/sso/providers');

      expect(
        client.admin.sso.listProviders(),
        _throwsFormatExceptionNaming('items'),
      );
    });
  });

  group('custom providers', () {
    test('reads a well formed provider', () {
      final provider = CustomOAuthProvider.fromJson(_customProviderJson());

      expect(provider.scopes, ['openid']);
      expect(provider.discoveryDocument?.issuer, 'https://idp.example.com');
    });

    for (final (field, value) in [
      ('name', 1),
      ('scopes', 'openid'),
      ('pkce_enabled', 'yes'),
      ('authorization_params', 'prompt=consent'),
      ('discovery_document', 'https://idp.example.com'),
    ]) {
      test('CustomOAuthProvider.fromJson throws for $field holding $value', () {
        expect(
          () => CustomOAuthProvider.fromJson({
            ..._customProviderJson(),
            field: value,
          }),
          _throwsFormatExceptionNaming(field),
        );
      });
    }

    test('OIDCDiscoveryDocument.fromJson throws for a non-string issuer', () {
      expect(
        () => OIDCDiscoveryDocument.fromJson({
          ..._customProviderJson()['discovery_document'],
          'issuer': 1,
        }),
        _throwsFormatExceptionNaming('issuer'),
      );
    });

    test('listProviders throws a FormatException for providers of the wrong '
        'type', () {
      httpClient.stub({
        'providers': [1],
      }, path: '/admin/custom-providers');

      expect(
        client.admin.customProviders.listProviders(),
        _throwsFormatExceptionNaming('providers'),
      );
    });
  });

  group('passkeys', () {
    test(
      'list throws a FormatException for an element that is not an object',
      () {
        httpClient.stub(['passkey'], method: HttpMethod.get, path: '/passkeys');

        expect(client.passkey.list(), _throwsFormatExceptionNaming('passkeys'));
      },
    );

    test('Passkey.fromJson throws for a non-string friendly_name', () {
      expect(
        () => Passkey.fromJson({
          'id': 'passkey-id',
          'friendly_name': 1,
          'created_at': _timestamp,
        }),
        _throwsFormatExceptionNaming('friendly_name'),
      );
    });

    for (final (field, value) in [
      ('challenge_id', 1),
      ('options', 'options'),
    ]) {
      test('registration options throw for $field holding $value', () {
        final json = {
          'challenge_id': 'challenge-id',
          'options': <String, dynamic>{},
          'expires_at': 1735689900,
        };

        expect(
          () => PasskeyRegistrationOptionsResponse.fromJson({
            ...json,
            field: value,
          }),
          _throwsFormatExceptionNaming(field),
        );
      });
    }
  });

  group('JWT claims', () {
    for (final (field, value) in [
      ('iss', 1),
      ('sub', 1),
      ('exp', '1735689900'),
      ('iat', true),
      ('jti', 1),
    ]) {
      test('JwtPayload.fromJson throws for $field holding $value', () {
        expect(
          () => JwtPayload.fromJson({field: value}),
          _throwsFormatExceptionNaming(field),
        );
      });
    }

    test('decodeJwt throws AuthInvalidJwtException naming the claim', () {
      expect(
        () => decodeJwt(unsignedTestJwt({'sub': testUserId, 'exp': 'soon'})),
        throwsA(
          isA<AuthInvalidJwtException>().having(
            (error) => error.message,
            'message',
            allOf(contains('FormatException'), contains('"exp"')),
          ),
        ),
      );
    });

    test('JwtHeader.fromJson throws for a missing alg', () {
      expect(
        () => JwtHeader.fromJson({'typ': 'JWT'}),
        _throwsFormatExceptionNaming('alg'),
      );
    });

    test('JWKSet.fromJson throws for keys that are not objects', () {
      expect(
        () => JWKSet.fromJson({
          'keys': ['key'],
        }),
        _throwsFormatExceptionNaming('keys'),
      );
    });

    test('JWK.fromJson throws for key_ops of the wrong type', () {
      expect(
        () => JWK.fromJson({
          'kty': 'EC',
          'key_ops': [1],
        }),
        _throwsFormatExceptionNaming('key_ops'),
      );
    });
  });

  group('auth responses', () {
    test(
      'signUp throws a FormatException for a body that is not an object',
      () {
        httpClient.stub(
          [testUserJson()],
          method: HttpMethod.post,
          path: '/signup',
        );

        expect(
          client.signUp(phone: '+15555550100', password: 'password'),
          _throwsFormatExceptionNaming('response body'),
        );
      },
    );

    test('resend throws a FormatException for a non-string message_id', () {
      httpClient.stub(
        {'message_id': 1},
        method: HttpMethod.post,
        path: '/resend',
      );

      expect(
        client.resend(type: OtpType.sms, phone: '+15555550100'),
        _throwsFormatExceptionNaming('message_id'),
      );
    });

    test('resend reads the message_id', () async {
      httpClient.stub(
        {'message_id': 'message-id'},
        method: HttpMethod.post,
        path: '/resend',
      );

      final response = await client.resend(
        type: OtpType.sms,
        phone: '+15555550100',
      );

      expect(response.messageId, 'message-id');
      expect(
        httpClient.requestsTo('/resend', method: HttpMethod.post),
        hasLength(1),
      );
    });

    test('a token response with a malformed user still throws '
        'AuthRetryableFetchException', () {
      httpClient.stub(
        testSessionResponseJson(
          accessToken: unsignedTestJwt({'sub': testUserId}),
          user: {...testUserJson(), 'email': 1},
        ),
        method: HttpMethod.post,
        path: '/token',
      );

      expect(
        client.signInWithPassword(email: 'fake1@email.com', password: 'x'),
        throwsA(
          isA<AuthRetryableFetchException>().having(
            (error) => error.cause,
            'cause',
            _formatExceptionNaming('email'),
          ),
        ),
      );
    });
  });

  group('a response body that is not an object', () {
    final calls = <String, Future<Object> Function()>{
      'getUser': () => client.getUser(),
      'updateUser': () =>
          client.updateUser(UserAttributes(data: {'name': 'Ada'})),
      'admin.getUserById': () => client.admin.getUserById(testUserId),
      'admin.sso.getProvider': () => client.admin.sso.getProvider(testUserId),
      'admin.customProviders.getProvider': () =>
          client.admin.customProviders.getProvider('custom:acme'),
      'mfa.challenge': () => client.mfa.challenge(factorId: testUserId),
      'mfa.recoveryCodes.getStatus': () => client.mfa.recoveryCodes.getStatus(),
      'oauth.getAuthorizationDetails': () =>
          client.oauth.getAuthorizationDetails('authorization-id'),
      'passkey.update': () => client.passkey.update(
        passkeyId: 'passkey-id',
        friendlyName: 'Laptop',
      ),
    };

    for (final MapEntry(key: name, value: call) in calls.entries) {
      test('$name throws a FormatException', () {
        httpClient.stub(['unexpected']);

        expect(call(), _throwsFormatExceptionNaming('response body'));
      });
    }
  });

  group('a malformed error body', () {
    Future<UserResponse> failWith(Object body) {
      httpClient.stub(
        body,
        method: HttpMethod.get,
        path: '/user',
        statusCode: 400,
      );
      return client.getUser();
    }

    Matcher throwsApiException(String message) => throwsA(
      isA<AuthApiException>()
          .having((error) => error.message, 'message', message)
          .having((error) => error.statusCode, 'statusCode', 400),
    );

    test('skips a message that is not a string', () {
      expect(
        failWith({'msg': 1, 'message': 'Readable message'}),
        throwsApiException('Readable message'),
      );
    });

    test('falls back to the error field', () {
      expect(
        failWith({'msg': <dynamic>[], 'error': 1}),
        throwsApiException('1'),
      );
    });

    test('falls back to the whole body', () {
      expect(failWith({'msg': true}), throwsApiException('{msg: true}'));
    });

    test('accepts a body that is not an object', () {
      expect(failWith([1]), throwsApiException('[1]'));
    });

    for (final (description, weakPassword, reasons) in [
      ('not an object', 'short', <String>[]),
      ('reasons that are not a list', {'reasons': 'length'}, <String>[]),
      (
        'reasons that are not all strings',
        {
          'reasons': ['length', 1],
        },
        ['length'],
      ),
    ]) {
      test('a weak_password that is $description still throws '
          'AuthWeakPasswordException', () {
        expect(
          failWith({
            'code': 'weak_password',
            'msg': 'Password is too weak',
            'weak_password': weakPassword,
          }),
          throwsA(
            isA<AuthWeakPasswordException>()
                .having(
                  (error) => error.message,
                  'message',
                  'Password is too weak',
                )
                .having((error) => error.reasons, 'reasons', reasons),
          ),
        );
      });
    }
  });
}
