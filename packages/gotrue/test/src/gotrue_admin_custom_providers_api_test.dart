import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  final env = DotEnv();

  env.load(); // Load env variables from .env file

  final gotrueUrl = env['GOTRUE_URL'] ?? 'http://127.0.0.1:54421/auth/v1';
  final serviceRoleToken = getServiceRoleToken(env);

  late GoTrueClient client;

  // The reset routine does not clear custom OAuth providers, so every test
  // uses a unique identifier and removes the provider it created.
  String newIdentifier() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'custom:flutter-test-$timestamp';
  }

  CreateCustomProviderParams oauth2Parameters(
    String identifier, {
    List<String>? customClaimsAllowlist,
  }) {
    return CreateCustomProviderParams(
      providerType: CustomProviderType.oauth2,
      identifier: identifier,
      name: 'Flutter Test Provider',
      clientId: 'test-client-id',
      clientSecret: 'test-client-secret',
      authorizationUrl: 'https://example.com/authorize',
      tokenUrl: 'https://example.com/token',
      userinfoUrl: 'https://example.com/userinfo',
      customClaimsAllowlist: customClaimsAllowlist,
    );
  }

  setUp(() async {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:54421/rest/v1/rpc/reset_and_init_auth_data'),
      headers: {
        'x-forwarded-for': '127.0.0.1',
        'apikey': serviceRoleToken,
        'Authorization': 'Bearer $serviceRoleToken',
      },
    );
    if (response.body.isNotEmpty) throw response.body;

    client = GoTrueClient(
      url: gotrueUrl,
      headers: {
        'Authorization': 'Bearer $serviceRoleToken',
        'apikey': serviceRoleToken,
        'x-forwarded-for': '127.0.0.1',
      },
    );
  });

  group('Custom OAuth provider management', () {
    test('create custom provider', () async {
      final identifier = newIdentifier();
      try {
        final provider = await client.admin.customProviders.createProvider(
          oauth2Parameters(identifier),
        );

        expect(provider.identifier, identifier);
        expect(provider.name, 'Flutter Test Provider');
        expect(provider.providerType, CustomProviderType.oauth2);
        expect(provider.clientId, 'test-client-id');
        expect(provider.id, isNotEmpty);
      } finally {
        await client.admin.customProviders.deleteProvider(identifier);
      }
    });

    test('create custom provider with custom_claims_allowlist', () async {
      final identifier = newIdentifier();
      try {
        // Exercises sending the custom_claims_allowlist field over the wire.
        final provider = await client.admin.customProviders.createProvider(
          oauth2Parameters(
            identifier,
            customClaimsAllowlist: ['groups', 'org_id', 'mail'],
          ),
        );

        expect(provider.identifier, identifier);
      } finally {
        await client.admin.customProviders.deleteProvider(identifier);
      }
    });

    test('list custom providers', () async {
      final identifier = newIdentifier();
      try {
        await client.admin.customProviders.createProvider(
          oauth2Parameters(identifier),
        );

        final providers = await client.admin.customProviders.listProviders();
        expect(
          providers.map((provider) => provider.identifier),
          contains(identifier),
        );
      } finally {
        await client.admin.customProviders.deleteProvider(identifier);
      }
    });

    test('list custom providers filtered by type', () async {
      final identifier = newIdentifier();
      try {
        await client.admin.customProviders.createProvider(
          oauth2Parameters(identifier),
        );

        final providers = await client.admin.customProviders.listProviders(
          type: CustomProviderType.oauth2,
        );
        expect(
          providers.every(
            (provider) => provider.providerType == CustomProviderType.oauth2,
          ),
          isTrue,
        );
        expect(
          providers.map((provider) => provider.identifier),
          contains(identifier),
        );
      } finally {
        await client.admin.customProviders.deleteProvider(identifier);
      }
    });

    test('get custom provider by identifier', () async {
      final identifier = newIdentifier();
      try {
        await client.admin.customProviders.createProvider(
          oauth2Parameters(identifier),
        );

        final provider = await client.admin.customProviders.getProvider(
          identifier,
        );
        expect(provider.identifier, identifier);
        expect(provider.name, 'Flutter Test Provider');
      } finally {
        await client.admin.customProviders.deleteProvider(identifier);
      }
    });

    test('update custom provider', () async {
      final identifier = newIdentifier();
      try {
        await client.admin.customProviders.createProvider(
          oauth2Parameters(identifier),
        );

        final updated = await client.admin.customProviders.updateProvider(
          identifier,
          const UpdateCustomProviderParams(
            name: 'Updated Provider Name',
            customClaimsAllowlist: ['groups'],
          ),
        );
        expect(updated.identifier, identifier);
        expect(updated.name, 'Updated Provider Name');

        final fetched = await client.admin.customProviders.getProvider(
          identifier,
        );
        expect(fetched.name, 'Updated Provider Name');
      } finally {
        await client.admin.customProviders.deleteProvider(identifier);
      }
    });

    test('delete custom provider', () async {
      final identifier = newIdentifier();
      await client.admin.customProviders.createProvider(
        oauth2Parameters(identifier),
      );

      await client.admin.customProviders.deleteProvider(identifier);

      // The provider no longer exists, so fetching it fails.
      expect(
        () => client.admin.customProviders.getProvider(identifier),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
