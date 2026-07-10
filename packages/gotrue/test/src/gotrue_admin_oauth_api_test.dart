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

  group('OAuth client management', () {
    test('create OAuth client', () async {
      final parameters = CreateOAuthClientParams(
        clientName: 'Test OAuth Client',
        redirectUris: ['https://example.com/callback'],
        clientUri: 'https://example.com',
        scope: 'openid profile email',
      );

      final response = await client.admin.oauth.createClient(parameters);
      expect(response.client, isNotNull);
      expect(response.client?.clientName, 'Test OAuth Client');
      expect(response.client?.redirectUris, ['https://example.com/callback']);
      expect(response.client?.clientSecret, isNotNull);
      expect(response.client?.clientId, isNotNull);
    });

    test('list OAuth clients', () async {
      // First create a client
      final parameters = CreateOAuthClientParams(
        clientName: 'Test OAuth Client for List',
        redirectUris: ['https://example.com/callback'],
      );
      await client.admin.oauth.createClient(parameters);

      final response = await client.admin.oauth.listClients();
      expect(response.clients, isNotEmpty);
      // aud is optional
    });

    test('get OAuth client by ID', () async {
      // First create a client
      final parameters = CreateOAuthClientParams(
        clientName: 'Test OAuth Client for Get',
        redirectUris: ['https://example.com/callback'],
      );
      final createResponse = await client.admin.oauth.createClient(parameters);
      final clientId = createResponse.client!.clientId;

      final response = await client.admin.oauth.getClient(clientId);
      expect(response.client, isNotNull);
      expect(response.client?.clientId, clientId);
      expect(response.client?.clientName, 'Test OAuth Client for Get');
    });

    test('update OAuth client', () async {
      // First create a client
      final createParameters = CreateOAuthClientParams(
        clientName: 'Test OAuth Client for Update',
        redirectUris: ['https://example.com/callback'],
      );
      final createResponse = await client.admin.oauth.createClient(
        createParameters,
      );
      final clientId = createResponse.client!.clientId;

      // Update the client
      final updateParameters = UpdateOAuthClientParams(
        clientName: 'Updated OAuth Client Name',
      );
      final updateResponse = await client.admin.oauth.updateClient(
        clientId,
        updateParameters,
      );
      expect(updateResponse.client, isNotNull);
      expect(updateResponse.client?.clientId, clientId);
      expect(updateResponse.client?.clientName, 'Updated OAuth Client Name');

      // Verify the update by getting the client again
      final getResponse = await client.admin.oauth.getClient(clientId);
      expect(getResponse.client?.clientName, 'Updated OAuth Client Name');
    });

    test('regenerate OAuth client secret', () async {
      // First create a client
      final parameters = CreateOAuthClientParams(
        clientName: 'Test OAuth Client for Regenerate',
        redirectUris: ['https://example.com/callback'],
      );
      final createResponse = await client.admin.oauth.createClient(parameters);
      final clientId = createResponse.client!.clientId;
      final originalSecret = createResponse.client!.clientSecret;

      final response = await client.admin.oauth.regenerateClientSecret(
        clientId,
      );
      expect(response.client, isNotNull);
      expect(response.client?.clientSecret, isNotNull);
      expect(response.client?.clientSecret, isNot(originalSecret));
    });

    test('delete OAuth client', () async {
      // First create a client
      final parameters = CreateOAuthClientParams(
        clientName: 'Test OAuth Client for Delete',
        redirectUris: ['https://example.com/callback'],
      );
      final createResponse = await client.admin.oauth.createClient(parameters);
      final clientId = createResponse.client!.clientId;

      // Delete returns 204 No Content with empty body
      final response = await client.admin.oauth.deleteClient(clientId);
      // The server returns 204 with no body, so client will be null
      expect(response.client, isNull);
    });
  });

  group('validates ids', () {
    test('getClient() validates ids', () {
      expect(
        () => client.admin.oauth.getClient('invalid-id'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deleteClient() validates ids', () {
      expect(
        () => client.admin.oauth.deleteClient('invalid-id'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('regenerateClientSecret() validates ids', () {
      expect(
        () => client.admin.oauth.regenerateClientSecret('invalid-id'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('updateClient() validates ids', () {
      final parameters = UpdateOAuthClientParams(clientName: 'Updated Name');
      expect(
        () => client.admin.oauth.updateClient('invalid-id', parameters),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
