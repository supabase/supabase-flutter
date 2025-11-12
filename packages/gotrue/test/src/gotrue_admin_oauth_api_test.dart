import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  final env = DotEnv();

  env.load(); // Load env variables from .env file

  final gotrueUrl = env['GOTRUE_URL'] ?? 'http://localhost:9998';
  final serviceRoleToken = JWT(
    {'role': 'service_role'},
  ).sign(
    SecretKey(
        env['GOTRUE_JWT_SECRET'] ?? '37c304f8-51aa-419a-a1af-06154e63707a'),
  );

  late GoTrueClient client;

  setUp(() async {
    final res = await http.post(
        Uri.parse('http://localhost:3000/rpc/reset_and_init_auth_data'),
        headers: {'x-forwarded-for': '127.0.0.1'});
    if (res.body.isNotEmpty) throw res.body;

    client = GoTrueClient(
      url: gotrueUrl,
      headers: {
        'Authorization': 'Bearer $serviceRoleToken',
        'apikey': serviceRoleToken,
        'x-forwarded-for': '127.0.0.1'
      },
    );
  });

  group('OAuth client management', () {
    test('create OAuth client', () async {
      final params = CreateOAuthClientParams(
        clientName: 'Test OAuth Client',
        redirectUris: ['https://example.com/callback'],
        clientUri: 'https://example.com',
        scope: 'openid profile email',
      );

      final res = await client.admin.oauth.createClient(params);
      expect(res.client, isNotNull);
      expect(res.client?.clientName, 'Test OAuth Client');
      expect(res.client?.redirectUris, ['https://example.com/callback']);
      expect(res.client?.clientSecret, isNotNull);
      expect(res.client?.clientId, isNotNull);
    });

    test('list OAuth clients', () async {
      // First create a client
      final params = CreateOAuthClientParams(
        clientName: 'Test OAuth Client for List',
        redirectUris: ['https://example.com/callback'],
      );
      await client.admin.oauth.createClient(params);

      final res = await client.admin.oauth.listClients();
      expect(res.clients, isNotEmpty);
      // aud is optional
    });

    test('get OAuth client by ID', () async {
      // First create a client
      final params = CreateOAuthClientParams(
        clientName: 'Test OAuth Client for Get',
        redirectUris: ['https://example.com/callback'],
      );
      final createRes = await client.admin.oauth.createClient(params);
      final clientId = createRes.client!.clientId;

      final res = await client.admin.oauth.getClient(clientId);
      expect(res.client, isNotNull);
      expect(res.client?.clientId, clientId);
      expect(res.client?.clientName, 'Test OAuth Client for Get');
    });

    test('update OAuth client', () async {
      // First create a client
      final createParams = CreateOAuthClientParams(
        clientName: 'Test OAuth Client for Update',
        redirectUris: ['https://example.com/callback'],
      );
      final createRes = await client.admin.oauth.createClient(createParams);
      final clientId = createRes.client!.clientId;

      // Update the client
      final updateParams = UpdateOAuthClientParams(
        clientName: 'Updated OAuth Client Name',
      );
      final updateRes =
          await client.admin.oauth.updateClient(clientId, updateParams);
      expect(updateRes.client, isNotNull);
      expect(updateRes.client?.clientId, clientId);
      expect(updateRes.client?.clientName, 'Updated OAuth Client Name');

      // Verify the update by getting the client again
      final getRes = await client.admin.oauth.getClient(clientId);
      expect(getRes.client?.clientName, 'Updated OAuth Client Name');
    });

    test('regenerate OAuth client secret', () async {
      // First create a client
      final params = CreateOAuthClientParams(
        clientName: 'Test OAuth Client for Regenerate',
        redirectUris: ['https://example.com/callback'],
      );
      final createRes = await client.admin.oauth.createClient(params);
      final clientId = createRes.client!.clientId;
      final originalSecret = createRes.client!.clientSecret;

      final res = await client.admin.oauth.regenerateClientSecret(clientId);
      expect(res.client, isNotNull);
      expect(res.client?.clientSecret, isNotNull);
      expect(res.client?.clientSecret, isNot(originalSecret));
    });

    test('delete OAuth client', () async {
      // First create a client
      final params = CreateOAuthClientParams(
        clientName: 'Test OAuth Client for Delete',
        redirectUris: ['https://example.com/callback'],
      );
      final createRes = await client.admin.oauth.createClient(params);
      final clientId = createRes.client!.clientId;

      // Delete returns 204 No Content with empty body
      final res = await client.admin.oauth.deleteClient(clientId);
      // The server returns 204 with no body, so client will be null
      expect(res.client, isNull);
    });
  });

  group('validates ids', () {
    test('getClient() validates ids', () {
      expect(() => client.admin.oauth.getClient('invalid-id'),
          throwsA(isA<ArgumentError>()));
    });

    test('deleteClient() validates ids', () {
      expect(() => client.admin.oauth.deleteClient('invalid-id'),
          throwsA(isA<ArgumentError>()));
    });

    test('regenerateClientSecret() validates ids', () {
      expect(() => client.admin.oauth.regenerateClientSecret('invalid-id'),
          throwsA(isA<ArgumentError>()));
    });

    test('updateClient() validates ids', () {
      final params = UpdateOAuthClientParams(clientName: 'Updated Name');
      expect(() => client.admin.oauth.updateClient('invalid-id', params),
          throwsA(isA<ArgumentError>()));
    });
  });
}
