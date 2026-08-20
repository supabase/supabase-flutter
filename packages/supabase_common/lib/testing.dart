/// Test helpers for apps and packages built on the Supabase clients.
///
/// Holds the mock HTTP clients, JWT builders, auth fixtures and realtime
/// frames that the test suites of the client packages themselves run on,
/// published so that apps can test code that talks to Supabase without a
/// running stack. Also holds the configuration of the local Supabase CLI
/// stack that the integration tests of this repository run against.
///
/// Everything here is annotated with `@visibleForTesting`, so the analyzer
/// warns when a helper leaks outside of test code. It is a separate library
/// because none of it is part of the runtime API of the packages.
library;

export 'src/testing/local_stack.dart';
export 'src/testing/mock_http_clients.dart';
export 'src/testing/realtime_frames.dart';
export 'src/testing/session_fixture.dart';
export 'src/testing/test_jwt.dart';
