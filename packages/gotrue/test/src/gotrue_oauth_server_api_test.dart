import 'dart:convert';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../custom_http_client.dart';
import '../utils.dart';

void main() {
  const gotrueUrl = 'http://127.0.0.1:54421/auth/v1';

  group('OAuth 2.1 Server User API', () {
    test('getAuthorizationDetails parses response correctly', () async {
      final mockResponse = {
        'authorization_id': 'auth-id-123',
        'client': {
          'client_id': 'client-id-abc',
          'client_name': 'My App',
          'client_uri': 'https://myapp.com',
          'redirect_uris': ['https://myapp.com/callback'],
          'client_type': 'public',
          'registration_type': 'dynamic',
          'grant_types': ['authorization_code'],
          'response_types': ['code'],
          'token_endpoint_auth_method': 'none',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        },
        'scope': 'openid profile',
        'state': 'state-xyz',
        'redirect_uri': 'https://myapp.com/callback',
      };

      final httpClient = MockedHttpClient(mockResponse);
      final client = GoTrueClient(
        url: gotrueUrl,
        httpClient: httpClient,
      );

      final details =
          await client.oauthServer.getAuthorizationDetails('auth-id-123');

      expect(details.authorizationId, 'auth-id-123');
      expect(details.client.clientId, 'client-id-abc');
      expect(details.client.clientName, 'My App');
      expect(details.scope, 'openid profile');
      expect(details.state, 'state-xyz');
      expect(details.redirectUri, 'https://myapp.com/callback');
    });

    test('approveAuthorization sends correct request and parses response',
        () async {
      final mockResponse = {
        'redirect_url':
            'https://myapp.com/callback?code=code-123&state=state-xyz',
      };

      var requestSent = false;

      final client = GoTrueClient(
        url: gotrueUrl,
        httpClient: _MockRequestVerifierClient((request) async {
          requestSent = true;
          expect(request.method, 'POST');
          expect(request.url.path,
              endsWith('/oauth/authorizations/auth-id-123/consent'));

          if (request is http.Request) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['action'], 'approve');
            expect(body['skip_browser_redirect'], true);
          }
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(mockResponse))),
            200,
            request: request,
          );
        }),
      );

      final consent = await client.oauthServer.approveAuthorization(
        'auth-id-123',
        skipBrowserRedirect: true,
      );

      expect(requestSent, isTrue);
      expect(consent.redirectUrl,
          'https://myapp.com/callback?code=code-123&state=state-xyz');
    });

    test('denyAuthorization sends correct request and parses response',
        () async {
      final mockResponse = {
        'redirect_url':
            'https://myapp.com/callback?error=access_denied&state=state-xyz',
      };

      var requestSent = false;

      final client = GoTrueClient(
        url: gotrueUrl,
        httpClient: _MockRequestVerifierClient((request) async {
          requestSent = true;
          expect(request.method, 'POST');
          expect(request.url.path,
              endsWith('/oauth/authorizations/auth-id-123/consent'));

          if (request is http.Request) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['action'], 'deny');
            expect(body.containsKey('skip_browser_redirect'), isFalse);
          }
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(mockResponse))),
            200,
            request: request,
          );
        }),
      );

      final consent = await client.oauthServer.denyAuthorization(
        'auth-id-123',
      );

      expect(requestSent, isTrue);
      expect(consent.redirectUrl,
          'https://myapp.com/callback?error=access_denied&state=state-xyz');
    });
  });
}

class _MockRequestVerifierClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      _onSend;

  _MockRequestVerifierClient(this._onSend);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _onSend(request);
  }
}
