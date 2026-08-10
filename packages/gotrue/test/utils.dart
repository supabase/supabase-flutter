import 'dart:convert';

import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:supabase_common/testing.dart';

export 'package:supabase_common/testing.dart';

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
  final timestamp = (DateTime.now().microsecondsSinceEpoch / (1000 * 1000))
      .round();
  return 'fake$timestamp@email.com';
}

String getNewPhone() {
  final timestamp = (DateTime.now().microsecondsSinceEpoch / (1000 * 1000))
      .round();
  return '$timestamp';
}

/// Endpoint of the local Supabase CLI stack that resets the auth fixtures.
const resetAuthDataUrl = '$localStackRestUrl/rpc/reset_and_init_auth_data';

String getServiceRoleToken(DotEnv env) =>
    env['GOTRUE_SERVICE_ROLE_TOKEN'] ?? localStackServiceRoleKey;

String getAnonToken(DotEnv env) => env['GOTRUE_TOKEN'] ?? localStackAnonKey;

/// User id embedded in the session produced by [getSessionData].
const sessionDataUserId = '4d2583da-8de4-49d3-9cd1-37a9a74f55bd';

/// Construct session data for a given expiration date
({String accessToken, String sessionString}) getSessionData(
  DateTime expireDateTime,
) {
  final expiresAt = expireDateTime.millisecondsSinceEpoch ~/ 1000;
  final accessTokenMid = base64.encode(
    utf8.encode(
      json.encode({
        'exp': expiresAt,
        'sub': '1234567890',
        'role': 'authenticated',
      }),
    ),
  );
  final accessToken = 'any.$accessTokenMid.any';
  final sessionString =
      '{"access_token":"$accessToken","expires_in":'
      '${expireDateTime.difference(DateTime.now()).inSeconds},"refresh_token":"'
      '-yeS4omysFs9tpUYBws9Rg","token_type":"bearer","provider_token":null,"pro'
      'vider_refresh_token":null,"user":{"id":"$sessionDataUserId","app_metadat'
      'a":{"provider":"email","providers":["email"]},"user_metadata":{"Hello":"'
      'World"},"aud":"","email":"fake1680338105@email.com","phone":"","created_'
      'at":"2023-04-01T08:35:05.208586Z","confirmed_at":null,"email_confirmed_a'
      't":"2023-04-01T08:35:05.220096086Z","phone_confirmed_at":null,"last_sign'
      '_in_at":"2023-04-01T08:35:05.222755878Z","role":"","updated_at":"2023-04'
      '-01T08:35:05.226938Z"}}';
  return (accessToken: accessToken, sessionString: sessionString);
}

class TestAsyncStorage implements GotrueAsyncStorage {
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
