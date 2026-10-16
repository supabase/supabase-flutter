import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  const userId = 'ef507d02-ce6a-4b3a-a8a6-6f0e14740136';
  const factorId = '2d3aa138-da96-4aea-8217-af07daa6b82d';
  final factorJson = {
    'id': factorId,
    'friendly_name': 'Work phone',
    'factor_type': 'phone',
    'status': 'verified',
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-02T00:00:00Z',
  };

  late MockSupabaseHttpClient httpClient;
  late AuthClient client;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stub(factorJson);
    client = AuthClient(
      url: 'http://localhost:9999',
      httpClient: httpClient,
      asyncStorage: TestAsyncStorage(),
    );
  });

  test('updateFactor sends a PUT to the factor path', () async {
    await client.admin.mfa.updateFactor(
      userId: userId,
      factorId: factorId,
      friendlyName: 'Work phone',
      phone: '+15555550100',
    );

    final requests = httpClient.requestsTo(
      '/admin/users/$userId/factors/$factorId',
      method: HttpMethod.put.value,
    );
    expect(requests, hasLength(1));
    expect(requests.single.jsonBody, {
      'friendly_name': 'Work phone',
      'phone': '+15555550100',
    });
  });

  test('updateFactor only sends the fields that are given', () async {
    await client.admin.mfa.updateFactor(
      userId: userId,
      factorId: factorId,
      phone: '+15555550100',
    );

    expect(httpClient.requests.last.jsonBody, {'phone': '+15555550100'});
  });

  test('updateFactor returns the updated factor', () async {
    final response = await client.admin.mfa.updateFactor(
      userId: userId,
      factorId: factorId,
      friendlyName: 'Work phone',
    );

    expect(response.factor, Factor.fromJson(factorJson));
  });
}
