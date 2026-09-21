import 'package:supabase_auth/src/auth_admin_oauth_api.dart';
import 'package:test/test.dart';

void main() {
  group('OAuthClientListResponse', () {
    test('fromJson parses a page of clients', () {
      final response = OAuthClientListResponse.fromJson({
        'clients': [
          {
            'client_id': '8f2a1c33-3a1e-4f56-9f0b-2d1d5b8a91c4',
            'client_name': 'Test OAuth Client',
            'client_type': 'public',
            'token_endpoint_auth_method': 'none',
            'registration_type': 'dynamic',
            'redirect_uris': ['https://example.com/callback'],
            'grant_types': ['authorization_code', 'refresh_token'],
            'response_types': ['code'],
            'created_at': '2025-01-01T00:00:00.000Z',
            'updated_at': '2025-01-02T03:04:05.000Z',
          },
        ],
        'aud': 'authenticated',
        'nextPage': 2,
        'lastPage': 5,
        'total': 42,
      });

      expect(response.clients, hasLength(1));
      expect(response.clients.first.clientName, 'Test OAuth Client');
      expect(response.audience, 'authenticated');
      expect(response.nextPage, 2);
      expect(response.lastPage, 5);
      expect(response.total, 42);
    });

    test('fromJson parses a response without any clients', () {
      final response = OAuthClientListResponse.fromJson({});

      expect(response.clients, isEmpty);
      expect(response.audience, isNull);
      expect(response.nextPage, isNull);
      expect(response.lastPage, isNull);
      expect(response.total, 0);
    });
  });
}
