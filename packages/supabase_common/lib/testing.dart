/// Test helpers shared by the suites of the client packages.
///
/// Holds the configuration of the local Supabase CLI stack that the
/// integration tests run against, and the fixtures and mock HTTP clients the
/// unit tests build on. Defined once here so the suites of the different
/// packages cannot drift apart. It is a separate library because none of it
/// is part of the runtime API of the packages.
library;

export 'src/testing/local_stack.dart';
export 'src/testing/mock_http_clients.dart';
export 'src/testing/realtime_frames.dart';
export 'src/testing/session_fixture.dart';
export 'src/testing/test_jwt.dart';
