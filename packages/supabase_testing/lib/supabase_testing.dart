/// Test helpers for apps and packages built on the Supabase clients.
///
/// Holds the mock HTTP clients, JWT builders, auth fixtures and realtime
/// frames that the test suites of the client packages themselves run on,
/// published so that apps can test code that talks to Supabase without a
/// running stack.
///
/// Everything here is annotated with `@visibleForTesting`, so the analyzer
/// warns when a helper leaks outside of test code.
library;

export 'src/mock_http_clients.dart';
export 'src/realtime_frames.dart';
export 'src/session_fixture.dart';
export 'src/test_jwt.dart';
