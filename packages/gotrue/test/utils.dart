import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';

/// Email of a user with unverified factor
const email1 = 'fake1@email.com';

/// Email of a user with verified factor
const email2 = 'fake2@email.com';

/// Phone of [userId1]
const phone1 = '166600000000';

/// User id of user with [email1] and [phone1]
const userId1 = '18bc7a4e-c095-4573-93dc-e0be29bada97';

/// User id of user with [email2]
const userId2 = '28bc7a4e-c095-4573-93dc-e0be29bada97';

/// Factor ID of user with [email1]
const factorId1 = '1d3aa138-da96-4aea-8217-af07daa6b82d';

/// Factor ID of user with [email2]
const factorId2 = '2d3aa138-da96-4aea-8217-af07daa6b82d';

final password = 'secret';

String getNewEmail() {
  final timestamp =
      (DateTime.now().microsecondsSinceEpoch / (1000 * 1000)).round();
  return 'fake$timestamp@email.com';
}

String getNewPhone() {
  final timestamp =
      (DateTime.now().microsecondsSinceEpoch / (1000 * 1000)).round();
  return '$timestamp';
}

String getServiceRoleToken() {
  return JWT(
    {
      'role': 'service_role',
    },
  ).sign(
    SecretKey(
        env['GOTRUE_JWT_SECRET'] ?? '37c304f8-51aa-419a-a1af-06154e63707a'),
  );
}

class TestAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _map = {};
  @override
  Future<String?> getItem({required String key}) async {
    return _map[key];
  }

  @override
  Future<void> removeItem({required String key}) async {
    _map.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _map[key] = value;
  }
}
