import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  const userId = 'ef507d02-ce6a-4b3a-a8a6-6f0e14740136';

  late MockSupabaseHttpClient httpClient;
  late AuthClient client;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stub(null);
    client = AuthClient(
      url: 'http://localhost:9999',
      httpClient: httpClient,
      asyncStorage: TestAsyncStorage(),
    );
  });

  test('deleteUser defaults to a hard delete', () async {
    await client.admin.deleteUser(userId);

    expect(httpClient.requests.last.jsonBody, {'should_soft_delete': false});
  });

  test('deleteUser sends should_soft_delete when soft deleting', () async {
    await client.admin.deleteUser(userId, shouldSoftDelete: true);

    final request = httpClient.requests.last;
    expect(request.method, 'DELETE');
    expect(request.url.path, endsWith('/admin/users/$userId'));
    expect(request.jsonBody, {'should_soft_delete': true});
  });
}
