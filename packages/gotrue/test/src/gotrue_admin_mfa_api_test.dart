import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils.dart';

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

  test('list factors', () async {
    final res = await client.admin.mfa.listFactors(userId: userId2);
    expect(res.factors.length, 1);
    final factor = res.factors.first;
    expect(factor.createdAt.difference(DateTime.now()) < Duration(seconds: 2),
        true);
    expect(factor.updatedAt.difference(DateTime.now()) < Duration(seconds: 2),
        true);
    expect(factor.id, factorId2);
  });

  test('delete factor', () async {
    final res = await client.admin.mfa.deleteFactor(
      userId: userId2,
      factorId: factorId2,
    );

    expect(res.id, factorId2);
  });
}
