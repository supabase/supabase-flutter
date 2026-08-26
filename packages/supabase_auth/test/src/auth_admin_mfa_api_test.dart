import 'package:dotenv/dotenv.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  final env = DotEnv();

  env.load(); // Load env variables from .env file

  final authUrl = getAuthUrl(env);
  final serviceRoleToken = getServiceRoleToken(env);

  late AuthClient client;

  setUp(() async {
    final response = await http.post(
      Uri.parse(resetAuthDataUrl),
      headers: {
        'x-forwarded-for': '127.0.0.1',
        'apikey': serviceRoleToken,
        'Authorization': 'Bearer $serviceRoleToken',
      },
    );
    if (response.body.isNotEmpty) throw response.body;

    client = AuthClient(
      url: authUrl,
      headers: {
        'Authorization': 'Bearer $serviceRoleToken',
        'apikey': serviceRoleToken,
        'x-forwarded-for': '127.0.0.1',
      },
      asyncStorage: TestAsyncStorage(),
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
