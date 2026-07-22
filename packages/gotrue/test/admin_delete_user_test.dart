import 'dart:convert';

import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

class _CapturingHttpClient extends BaseClient {
  Request? lastRequest;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastRequest = request as Request;
    return StreamedResponse(const Stream.empty(), 200, request: request);
  }
}

void main() {
  const userId = 'ef507d02-ce6a-4b3a-a8a6-6f0e14740136';

  late _CapturingHttpClient httpClient;
  late GoTrueClient client;

  setUp(() {
    httpClient = _CapturingHttpClient();
    client = GoTrueClient(
      url: 'http://localhost:9999',
      httpClient: httpClient,
    );
  });

  test('deleteUser defaults to a hard delete', () async {
    await client.admin.deleteUser(userId);

    final body = jsonDecode(httpClient.lastRequest!.body);
    expect(body, {'should_soft_delete': false});
  });

  test('deleteUser sends should_soft_delete when soft deleting', () async {
    await client.admin.deleteUser(userId, shouldSoftDelete: true);

    final request = httpClient.lastRequest!;
    expect(request.method, 'DELETE');
    expect(request.url.path, endsWith('/admin/users/$userId'));

    final body = jsonDecode(request.body);
    expect(body, {'should_soft_delete': true});
  });
}
