import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

void main() {
  group('OAuthClient', () {
    final json = {
      'client_id': '8f2a1c33-3a1e-4f56-9f0b-2d1d5b8a91c4',
      'client_name': 'Test OAuth Client',
      'client_type': 'public',
      'token_endpoint_auth_method': 'none',
      'registration_type': 'dynamic',
      'client_uri': 'https://example.com',
      'redirect_uris': ['https://example.com/callback'],
      'grant_types': ['authorization_code', 'refresh_token'],
      'response_types': ['code'],
      'scope': 'openid profile email',
      'created_at': '2025-01-01T00:00:00.000Z',
      'updated_at': '2025-01-02T03:04:05.000Z',
    };

    test('fromJson parses all fields', () {
      final client = OAuthClient.fromJson(json);

      expect(client.clientId, '8f2a1c33-3a1e-4f56-9f0b-2d1d5b8a91c4');
      expect(client.clientName, 'Test OAuth Client');
      expect(client.clientType, OAuthClientType.public);
      expect(client.tokenEndpointAuthenticationMethod, 'none');
      expect(client.registrationType, OAuthClientRegistrationType.dynamic);
      expect(client.clientUri, 'https://example.com');
      expect(client.redirectUris, ['https://example.com/callback']);
      expect(client.grantTypes, [
        OAuthClientGrantType.authorizationCode,
        OAuthClientGrantType.refreshToken,
      ]);
      expect(client.responseTypes, [OAuthClientResponseType.code]);
      expect(client.scope, 'openid profile email');
      expect(client.createdAt, DateTime.parse('2025-01-01T00:00:00.000Z'));
      expect(client.updatedAt, DateTime.parse('2025-01-02T03:04:05.000Z'));
    });

    test('fromJson parses a client without a name', () {
      final client = OAuthClient.fromJson({...json}..remove('client_name'));

      expect(client.clientName, isNull);
      expect(client.clientId, '8f2a1c33-3a1e-4f56-9f0b-2d1d5b8a91c4');
    });
  });
}
