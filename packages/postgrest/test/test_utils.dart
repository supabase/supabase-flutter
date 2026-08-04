/// Shared configuration for the postgrest_client integration tests that run
/// against the local Supabase CLI stack.
///
/// Requests go through the API gateway, which requires an apikey. The
/// service_role key is used so the tests have unrestricted access to the test
/// tables, matching the previous Docker setup where PostgREST ran as the
/// postgres role.
library;

import 'package:supabase_common/testing.dart';

const rootUrl = localStackRestUrl;

const serviceRoleKey = localStackServiceRoleKey;

const apiHeaders = {
  'apikey': serviceRoleKey,
  'Authorization': 'Bearer $serviceRoleKey',
};
