/// Configuration of the local Supabase CLI stack that the integration tests of
/// the client packages run against.
///
/// Defined once here so the suites of the different packages cannot drift
/// apart. It is a separate library because none of it is part of the runtime
/// API of the packages.
library;

export 'src/testing/local_stack.dart';
