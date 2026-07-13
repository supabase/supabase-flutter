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

  test('list factors', () async {
    final response = await client.admin.mfa.listFactors(userId: userId2);
    expect(response.factors, hasLength(1));
    final factor = response.factors.first;
    expect(
      factor.createdAt.difference(DateTime.now()) < Duration(seconds: 2),
      isTrue,
    );
    expect(
      factor.updatedAt.difference(DateTime.now()) < Duration(seconds: 2),
      isTrue,
    );
    expect(factor.id, factorId2);
  });

  test('delete factor', () async {
    final response = await client.admin.mfa.deleteFactor(
      userId: userId2,
      factorId: factorId2,
    );

    expect(response.id, factorId2);
  });
}
