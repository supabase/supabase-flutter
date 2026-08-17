import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'mocks/sso_mock_client.dart';
import 'utils.dart';

void main() {
  const providerId = 'b7b84310-745a-4e3a-9721-cb233b8a1c97';
  const redirectUrl =
      'https://idp.example.com/sso/saml/login?id=test-id&scope=openid';

  group('getSSOSignInUrl with mocked server', () {
    late SSOMockClient mockClient;

    setUp(() {
      mockClient = SSOMockClient(redirectUrl: redirectUrl);
    });

    AuthClient createClient({AuthFlowType flowType = AuthFlowType.pkce}) {
      final client = AuthClient(
        url: 'http://localhost:9999',
        httpClient: mockClient,
        autoRefreshToken: false,
        asyncStorage: TestAsyncStorage(),
        flowType: flowType,
      );
      addTearDown(client.dispose);
      return client;
    }

    test('returns the redirect URL as a Uri with addressable parts', () async {
      final uri = await createClient().getSSOSignInUrl(providerId: providerId);

      expect(uri.scheme, 'https');
      expect(uri.host, 'idp.example.com');
      expect(uri.path, '/sso/saml/login');
      expect(uri.queryParameters, {'id': 'test-id', 'scope': 'openid'});
    });

    test('posts the provider id to the sso endpoint', () async {
      await createClient().getSSOSignInUrl(providerId: providerId);

      expect(mockClient.lastUri?.path, endsWith('/sso'));
      expect(
        mockClient.lastRequestBody,
        containsPair('provider_id', providerId),
      );
      expect(
        mockClient.lastRequestBody,
        containsPair('skip_http_redirect', true),
      );
      expect(mockClient.lastRequestBody, isNot(contains('domain')));
    });

    test('posts the domain, redirect target and captcha token', () async {
      await createClient().getSSOSignInUrl(
        domain: 'company.com',
        redirectTo: 'my-app://callback',
        captchaToken: 'test-captcha-token',
      );

      expect(mockClient.lastRequestBody, containsPair('domain', 'company.com'));
      expect(
        mockClient.lastRequestBody,
        containsPair('redirect_to', 'my-app://callback'),
      );
      expect(
        mockClient.lastRequestBody,
        containsPair('gotrue_meta_security', {
          'captcha_token': 'test-captcha-token',
        }),
      );
      expect(mockClient.lastRequestBody, isNot(contains('provider_id')));
    });

    test('sends a PKCE challenge in the PKCE flow', () async {
      await createClient(
        flowType: AuthFlowType.pkce,
      ).getSSOSignInUrl(providerId: providerId);

      expect(mockClient.lastRequestBody?['code_challenge'], isNotEmpty);
      expect(mockClient.lastRequestBody?['code_challenge_method'], 's256');
    });

    test('sends no PKCE challenge in the implicit flow', () async {
      await createClient(
        flowType: AuthFlowType.implicit,
      ).getSSOSignInUrl(providerId: providerId);

      expect(mockClient.lastRequestBody?['code_challenge'], isNull);
      expect(mockClient.lastRequestBody?['code_challenge_method'], isNull);
    });

    test('throws when neither a provider id nor a domain is given', () async {
      await expectLater(
        createClient().getSSOSignInUrl(),
        throwsA(isA<AssertionError>()),
      );

      expect(mockClient.lastRequestBody, isNull);
    });
  });
}
