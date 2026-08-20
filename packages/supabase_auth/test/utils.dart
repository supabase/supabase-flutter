import 'package:dotenv/dotenv.dart';
import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_common/testing.dart';

export 'package:supabase_common/testing.dart';
export 'package:supabase_testing/supabase_testing.dart';

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

/// The `GOTRUE_`-prefixed keys are the names these overrides had before the
/// package was renamed, and are still honoured so existing `.env` files keep
/// working.
String getAuthUrl(DotEnv env) =>
    env['SUPABASE_AUTH_URL'] ?? env['GOTRUE_URL'] ?? localStackAuthUrl;

String getServiceRoleToken(DotEnv env) =>
    env['SUPABASE_AUTH_SERVICE_ROLE_TOKEN'] ??
    env['GOTRUE_SERVICE_ROLE_TOKEN'] ??
    localStackServiceRoleKey;

String getAnonToken(DotEnv env) =>
    env['SUPABASE_AUTH_TOKEN'] ?? env['GOTRUE_TOKEN'] ?? localStackAnonKey;

class TestAsyncStorage extends MemoryAuthAsyncStorage {}
