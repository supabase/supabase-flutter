import 'package:gotrue/gotrue.dart';
import 'package:test/test.dart';

void main() {
  group('CreateCustomProviderParams serialization', () {
    test('serializes required fields', () {
      final params = CreateCustomProviderParams(
        providerType: CustomProviderType.oauth2,
        identifier: 'custom:mycompany',
        name: 'My Company',
        clientId: 'client-id',
        clientSecret: 'client-secret',
      );

      final json = params.toJson();

      expect(json['provider_type'], 'oauth2');
      expect(json['identifier'], 'custom:mycompany');
      expect(json['name'], 'My Company');
      expect(json['client_id'], 'client-id');
      expect(json['client_secret'], 'client-secret');
    });

    test('omits custom_claims_allowlist when not provided', () {
      final params = CreateCustomProviderParams(
        providerType: CustomProviderType.oidc,
        identifier: 'custom:mycompany',
        name: 'My Company',
        clientId: 'client-id',
        clientSecret: 'client-secret',
      );

      expect(params.toJson().containsKey('custom_claims_allowlist'), isFalse);
    });

    test('serializes custom_claims_allowlist when provided', () {
      final params = CreateCustomProviderParams(
        providerType: CustomProviderType.oidc,
        identifier: 'custom:mycompany',
        name: 'My Company',
        clientId: 'client-id',
        clientSecret: 'client-secret',
        customClaimsAllowlist: ['groups', 'org_id', 'mail'],
      );

      expect(
        params.toJson()['custom_claims_allowlist'],
        ['groups', 'org_id', 'mail'],
      );
    });

    test('serializes an empty custom_claims_allowlist', () {
      final params = CreateCustomProviderParams(
        providerType: CustomProviderType.oidc,
        identifier: 'custom:mycompany',
        name: 'My Company',
        clientId: 'client-id',
        clientSecret: 'client-secret',
        customClaimsAllowlist: [],
      );

      expect(params.toJson()['custom_claims_allowlist'], isEmpty);
    });
  });

  group('UpdateCustomProviderParams serialization', () {
    test('omits custom_claims_allowlist when not provided', () {
      const params = UpdateCustomProviderParams(name: 'New name');

      final json = params.toJson();
      expect(json.containsKey('custom_claims_allowlist'), isFalse);
      expect(json['name'], 'New name');
    });

    test('serializes custom_claims_allowlist when provided', () {
      const params = UpdateCustomProviderParams(
        customClaimsAllowlist: ['groups'],
      );

      expect(params.toJson()['custom_claims_allowlist'], ['groups']);
    });
  });

  group('CustomOAuthProvider deserialization', () {
    Map<String, dynamic> baseJson() => {
          'id': '00000000-0000-0000-0000-000000000000',
          'provider_type': 'oidc',
          'identifier': 'custom:mycompany',
          'name': 'My Company',
          'client_id': 'client-id',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-02T00:00:00Z',
        };

    test('parses custom_claims_allowlist when present', () {
      final json = baseJson()
        ..['custom_claims_allowlist'] = ['groups', 'org_id', 'mail'];

      final provider = CustomOAuthProvider.fromJson(json);

      expect(provider.customClaimsAllowlist, ['groups', 'org_id', 'mail']);
      expect(provider.providerType, CustomProviderType.oidc);
      expect(provider.identifier, 'custom:mycompany');
    });

    test('leaves custom_claims_allowlist null when absent', () {
      final provider = CustomOAuthProvider.fromJson(baseJson());

      expect(provider.customClaimsAllowlist, isNull);
    });

    test('parses the discovery document when present', () {
      final json = baseJson()
        ..['discovery_document'] = {
          'issuer': 'https://issuer.example.com',
          'authorization_endpoint': 'https://issuer.example.com/authorize',
          'token_endpoint': 'https://issuer.example.com/token',
          'jwks_uri': 'https://issuer.example.com/jwks',
        };

      final provider = CustomOAuthProvider.fromJson(json);

      expect(provider.discoveryDocument, isNotNull);
      expect(provider.discoveryDocument?.issuer, 'https://issuer.example.com');
    });
  });
}
