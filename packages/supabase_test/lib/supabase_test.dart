/// Test helpers for apps and packages built on the Supabase clients.
///
/// Holds the mock HTTP client, JWT builders, auth fixtures and realtime
/// frames an app needs to test code that talks to Supabase without a running
/// stack. The test suites of the client packages themselves run on the same
/// primitives, and keep the fixtures only they need in
/// `package:supabase_test/internal.dart`.
///
/// Everything here is annotated with `@visibleForTesting`, so the analyzer
/// warns when a helper leaks outside of test code.
library;

export 'src/mock_http_clients.dart';
export 'src/mock_supabase_http_client.dart';
export 'src/realtime_frames.dart';
export 'src/session_fixture.dart';
export 'src/test_jwt.dart';
export 'src/test_supabase_client.dart';
