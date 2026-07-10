import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  late GotrueOauthApiFixture fixture;

  setUp(() async {
    fixture = GotrueOauthApiFixture();
  });

  group('OAuthAuthorizationDetailsResponse', () {
    test('can parse a valid JSON', () {
      final json = {
        'authorization_id': '6abuj667j4nmdotzu3w2ro5r33xezvae',
        'redirect_uri': 'http://localhost:50200/onboarding/auth/consent',
        'client': {
          'id': '7263e727-435b-4d38-a5ff-a14c954b8680',
          'name': 'OAuth test client',
        },
        'user': {
          'id': '1bee2038-51fe-4f93-8fbb-442df18657ff',
          'email': 'translator.user@mail.com',
        },
        'scope': 'email',
      };

      final actual = OAuthAuthorizationDetailsResponse.fromJson(json);

      expect(
        actual.authorizationId,
        equals('6abuj667j4nmdotzu3w2ro5r33xezvae'),
      );
      expect(actual.scope, equals('email'));
      expect(
        actual.redirectUri,
        equals('http://localhost:50200/onboarding/auth/consent'),
      );
      expect(
        actual.client.clientId,
        equals('7263e727-435b-4d38-a5ff-a14c954b8680'),
      );
      expect(actual.client.clientName, equals('OAuth test client'));
      expect(actual.user.id, equals('1bee2038-51fe-4f93-8fbb-442df18657ff'));
      expect(actual.user.email, equals('translator.user@mail.com'));
    });

    test('throws ArgumentError when user information is missing', () {
      final json = {
        'authorization_id': '6abuj667j4nmdotzu3w2ro5r33xezvae',
        'redirect_uri': 'http://localhost:50200/onboarding/auth/consent',
        'client': {
          'id': '7263e727-435b-4d38-a5ff-a14c954b8680',
          'name': 'OAuth test client',
        },
        'scope': 'email',
      };

      expect(
        () => OAuthAuthorizationDetailsResponse.fromJson(json),
        throwsFormatException,
      );
    });

    test('parses a redirect-only body into a redirect response', () {
      final json = {
        'redirect_url':
            'http://127.0.0.1:3000/oauth/callback?code=367ba316-8f55-43cd',
      };

      final actual = OAuthAuthorizationResponse.fromJson(json);

      expect(actual, isA<OAuthAuthorizationRedirectResponse>());
      expect(
        (actual as OAuthAuthorizationRedirectResponse).redirectUrl,
        equals('http://127.0.0.1:3000/oauth/callback?code=367ba316-8f55-43cd'),
      );
    });
  });

  group('OAuthGrant', () {
    test('can parse a valid JSON', () {
      final json = {
        'client': {
          'id': '7263e727-435b-4d38-a5ff-a14c954b8680',
          'name': 'OAuth test client',
          'uri': 'https://example.com',
          'logo_uri': 'https://example.com/logo.png',
        },
        'scopes': ['email', 'profile'],
        'granted_at': '2026-07-08T08:40:13.212Z',
      };

      final actual = OAuthGrant.fromJson(json);

      expect(
        actual.client.clientId,
        equals('7263e727-435b-4d38-a5ff-a14c954b8680'),
      );
      expect(actual.client.clientName, equals('OAuth test client'));
      expect(actual.client.clientUri, equals('https://example.com'));
      expect(actual.client.logoUri, equals('https://example.com/logo.png'));
      expect(actual.scopes, equals(['email', 'profile']));
      expect(
        actual.grantedAt,
        equals(DateTime.parse('2026-07-08T08:40:13.212Z')),
      );
    });

    test('defaults scopes to an empty list when missing', () {
      final json = {
        'client': {
          'id': '7263e727-435b-4d38-a5ff-a14c954b8680',
          'name': 'OAuth test client',
        },
        'granted_at': '2026-07-08T08:40:13.212Z',
      };

      final actual = OAuthGrant.fromJson(json);

      expect(actual.scopes, isEmpty);
    });
  });

  group('OAuth server', () {
    test('get authorization details', () async {
      final sut = await fixture.build();
      final clientParameters = CreateOAuthClientParams(
        clientName: 'Test OAuth Client',
        redirectUris: ['http://127.0.0.1:3000/oauth/callback'],
        responseTypes: [OAuthClientResponseType.code],
        scope: 'email',
      );
      final client = await fixture.sutCreatesOAuthClient(clientParameters);
      final auth = await fixture.sutLogsIn(password: password, email: email1);
      final authorizationId = await fixture.sutAuthorizesClient(client);

      final response = await sut.oauth.getAuthorizationDetails(authorizationId);

      expect(response, isA<OAuthAuthorizationDetailsResponse>());
      final details = response as OAuthAuthorizationDetailsResponse;
      expect(details.authorizationId, equals(authorizationId));
      expect(details.scope, equals(clientParameters.scope));
      expect(details.redirectUri, equals(clientParameters.redirectUris.first));
      expect(details.client.clientId, equals(client.clientId));
      expect(details.client.clientName, equals(client.clientName));
      expect(details.user.id, equals(auth.user?.id));
      expect(details.user.email, equals(email1));
    });

    test('approve authorization request', () async {
      final sut = await fixture.build();
      final clientParameters = CreateOAuthClientParams(
        clientName: 'Test OAuth Client',
        redirectUris: ['http://127.0.0.1:3000/oauth/callback'],
      );
      final client = await fixture.sutCreatesOAuthClient(clientParameters);
      final authorizationId = await fixture.sutAuthorizesClient(client);
      await fixture.sutLogsIn(password: password, email: email1);

      await sut.oauth.getAuthorizationDetails(authorizationId);
      final response = await sut.oauth.approveAuthorization(authorizationId);

      expect(
        response.redirectUrl,
        startsWith(clientParameters.redirectUris.first),
      );
      expect(response.redirectUrl, contains('code='));
    });

    test('denies authorization request', () async {
      final sut = await fixture.build();
      final clientParameters = CreateOAuthClientParams(
        clientName: 'Test OAuth Client',
        redirectUris: ['http://127.0.0.1:3000/oauth/callback'],
      );
      final client = await fixture.sutCreatesOAuthClient(clientParameters);
      final authorizationId = await fixture.sutAuthorizesClient(client);
      await fixture.sutLogsIn(password: password, email: email1);

      await sut.oauth.getAuthorizationDetails(authorizationId);
      final response = await sut.oauth.denyAuthorization(authorizationId);

      expect(
        response.redirectUrl,
        startsWith(clientParameters.redirectUris.first),
      );
      expect(response.redirectUrl, contains('error=access_denied'));
      expect(
        response.redirectUrl,
        contains('error_description=User+denied+the+request'),
      );
    });

    test('approving authorization without getting details throws', () async {
      final sut = await fixture.build();
      final clientParameters = CreateOAuthClientParams(
        clientName: 'Test OAuth Client',
        redirectUris: ['http://127.0.0.1:3000/oauth/callback'],
      );
      final client = await fixture.sutCreatesOAuthClient(clientParameters);
      final authorizationId = await fixture.sutAuthorizesClient(client);
      await fixture.sutLogsIn(password: password, email: email1);

      await expectLater(
        () async => sut.oauth.approveAuthorization(authorizationId),
        throwsA(
          isAnAuthApiException(
            statusCode: equals('404'),
            code: equals('oauth_authorization_not_found'),
          ),
        ),
      );
    });

    test('lists grants after approving an authorization', () async {
      final sut = await fixture.build();
      final clientParameters = CreateOAuthClientParams(
        clientName: 'Test OAuth Client',
        redirectUris: ['http://127.0.0.1:3000/oauth/callback'],
        responseTypes: [OAuthClientResponseType.code],
        scope: 'email',
      );
      final client = await fixture.sutCreatesOAuthClient(clientParameters);
      await fixture.sutLogsIn(password: password, email: email1);
      final authorizationId = await fixture.sutAuthorizesClient(client);
      await sut.oauth.getAuthorizationDetails(authorizationId);
      await sut.oauth.approveAuthorization(authorizationId);

      final grants = await sut.oauth.listGrants();

      expect(grants, hasLength(1));
      expect(grants.first.client.clientId, equals(client.clientId));
      expect(grants.first.scopes, contains('email'));
    });

    test('revokes a grant', () async {
      final sut = await fixture.build();
      final clientParameters = CreateOAuthClientParams(
        clientName: 'Test OAuth Client',
        redirectUris: ['http://127.0.0.1:3000/oauth/callback'],
        responseTypes: [OAuthClientResponseType.code],
        scope: 'email',
      );
      final client = await fixture.sutCreatesOAuthClient(clientParameters);
      await fixture.sutLogsIn(password: password, email: email1);
      final authorizationId = await fixture.sutAuthorizesClient(client);
      await sut.oauth.getAuthorizationDetails(authorizationId);
      await sut.oauth.approveAuthorization(authorizationId);
      expect(await sut.oauth.listGrants(), hasLength(1));

      await sut.oauth.revokeGrant(client.clientId);

      expect(await sut.oauth.listGrants(), isEmpty);
    });

    test(
      'getting details for a new authorization after the client was already '
      'approved does not throw',
      () async {
        final sut = await fixture.build();
        final clientParameters = CreateOAuthClientParams(
          clientName: 'Test OAuth Client',
          redirectUris: ['http://127.0.0.1:3000/oauth/callback'],
          responseTypes: [OAuthClientResponseType.code],
          scope: 'email',
        );
        final client = await fixture.sutCreatesOAuthClient(clientParameters);
        await fixture.sutLogsIn(password: password, email: email1);

        // First authorization: fetch details and approve to record consent.
        final firstAuthorizationId = await fixture.sutAuthorizesClient(client);
        await sut.oauth.getAuthorizationDetails(firstAuthorizationId);
        await sut.oauth.approveAuthorization(firstAuthorizationId);

        // Second authorization for the same client, by the same user.
        final secondAuthorizationId = await fixture.sutAuthorizesClient(client);

        final response = await sut.oauth.getAuthorizationDetails(
          secondAuthorizationId,
        );

        expect(response, isA<OAuthAuthorizationRedirectResponse>());
        final redirect = response as OAuthAuthorizationRedirectResponse;
        expect(
          redirect.redirectUrl,
          startsWith(clientParameters.redirectUris.first),
        );
        expect(redirect.redirectUrl, contains('code='));
      },
    );
  });
}

class GotrueOauthApiFixture {
  GotrueOauthApiFixture() {
    final env = DotEnv();
    env.load(); // Load env variables from .env file

    _gotrueUrl = env['GOTRUE_URL'] ?? 'http://127.0.0.1:54421/auth/v1';
    _serviceRoleToken = getServiceRoleToken(env);

    _client = GoTrueClient(
      url: _gotrueUrl,
      headers: {
        'Authorization': 'Bearer $_serviceRoleToken',
        'apikey': _serviceRoleToken,
        'x-forwarded-for': '127.0.0.1',
      },
    );
  }

  late final GoTrueClient _client;
  late final String _gotrueUrl;
  late final String _serviceRoleToken;

  Future<OAuthClient> sutCreatesOAuthClient(CreateOAuthClientParams request) {
    return _client.admin.oauth
        .createClient(request)
        .then((response) => response.client!);
  }

  Future<String> sutAuthorizesClient(OAuthClient client) async {
    // Don't follow redirects: the authorize endpoint returns a 302 to the
    // consent page with authorization_id as a query parameter.
    final httpClient = http.Client();
    final request = http.Request(
      'GET',
      Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: 54421,
        path: '/auth/v1/oauth/authorize',
        queryParameters: {
          'response_type': client.responseTypes.first.name,
          'client_id': client.clientId,
          'redirect_uri': client.redirectUris.first,
          'code_challenge': 'pkqGrzhFuuBOcRoR4elYl2ki1EiR3KtBdtQsEZdv8rM',
          'code_challenge_method': 'S256',
        },
      ),
    )..followRedirects = false;

    final streamed = await httpClient.send(request);
    httpClient.close();

    final location = streamed.headers['location']!;
    return Uri.parse(location).queryParameters['authorization_id']!;
  }

  Future<AuthResponse> sutLogsIn({
    required String email,
    required String password,
  }) {
    return _client.signInWithPassword(password: password, email: email);
  }

  Future<void> _reset() async {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:54421/rest/v1/rpc/reset_and_init_auth_data'),
      headers: {
        'x-forwarded-for': '127.0.0.1',
        'apikey': _serviceRoleToken,
        'Authorization': 'Bearer $_serviceRoleToken',
      },
    );
    if (response.body.isNotEmpty) throw response.body;
  }

  Future<GoTrueClient> build({bool reset = true}) async {
    if (reset) {
      await _reset();
    }

    return _client;
  }
}

Matcher isAnAuthApiException({Matcher? statusCode, Matcher? code}) =>
    isA<AuthApiException>()
        .having((e) => e.statusCode, 'statusCode', statusCode)
        .having((e) => e.code, 'code', code);
