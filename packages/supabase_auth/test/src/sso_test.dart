import 'dart:convert';

import 'package:http/http.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import '../utils.dart';

class _CapturingMockHttpClient extends BaseClient {
  _CapturingMockHttpClient({required this.responseBody});

  final Map<String, dynamic> responseBody;

  Request? capturedRequest;
  Map<String, dynamic>? capturedBody;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (request is Request) {
      capturedRequest = request;
      if (request.body.isNotEmpty) {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
      }
    }
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(responseBody))),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  const authUrl = 'http://localhost:54321/auth/v1';

  group('getSSOSignInUrl', () {
    test('returns Uri when called with providerId', () async {
      final mockClient = _CapturingMockHttpClient(
        responseBody: {
          'url':
              'https://idp.example.com/sso/saml/login?id=test-id'
              '&code_challenge=xyz',
        },
      );

      final client = AuthClient(
        url: authUrl,
        httpClient: mockClient,
        asyncStorage: TestAsyncStorage(),
        flowType: AuthFlowType.implicit,
      );

      final uri = await client.getSSOSignInUrl(
        providerId: 'b7b84310-745a-4e3a-9721-cb233b8a1c97',
      );

      expect(uri, isA<Uri>());
      expect(
        uri,
        equals(
          Uri.parse(
            'https://idp.example.com/sso/saml/login?id=test-id'
            '&code_challenge=xyz',
          ),
        ),
      );
      expect(uri.host, equals('idp.example.com'));
      expect(uri.queryParameters['id'], equals('test-id'));
      expect(
        mockClient.capturedBody?['provider_id'],
        equals('b7b84310-745a-4e3a-9721-cb233b8a1c97'),
      );
      expect(mockClient.capturedBody?['skip_http_redirect'], isTrue);
    });

    test(
      'returns Uri when called with domain, redirectTo, and captcha',
      () async {
        final mockClient = _CapturingMockHttpClient(
          responseBody: {
            'url':
                'https://idp.example.com/sso/oidc/auth?domain=company.com'
                '&redirect_to=my-app%3A%2F%2Fcallback',
          },
        );

        final client = AuthClient(
          url: authUrl,
          httpClient: mockClient,
          asyncStorage: TestAsyncStorage(),
          flowType: AuthFlowType.pkce,
        );

        final uri = await client.getSSOSignInUrl(
          domain: 'company.com',
          redirectTo: 'my-app://callback',
          captchaToken: 'test-captcha-token',
        );

        expect(uri, isA<Uri>());
        expect(uri.scheme, equals('https'));
        expect(uri.host, equals('idp.example.com'));
        expect(mockClient.capturedBody?['domain'], equals('company.com'));
        expect(
          mockClient.capturedBody?['redirect_to'],
          equals('my-app://callback'),
        );
        expect(
          mockClient.capturedBody?['gotrue_meta_security'],
          equals({'captcha_token': 'test-captcha-token'}),
        );
        expect(mockClient.capturedBody?['code_challenge'], isNotNull);
        expect(
          mockClient.capturedBody?['code_challenge_method'],
          equals('s256'),
        );
      },
    );

    test(
      'throws AssertionError if neither providerId nor domain is provided',
      () async {
        final client = AuthClient(
          url: authUrl,
          asyncStorage: TestAsyncStorage(),
        );

        expect(
          () => client.getSSOSignInUrl(),
          throwsA(isA<AssertionError>()),
        );
      },
    );
  });
}
