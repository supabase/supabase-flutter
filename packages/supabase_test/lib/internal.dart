/// Fixtures and mock clients the test suites of the Supabase client packages
/// themselves run on.
///
/// These are published so that the packages of the supabase-flutter monorepo
/// can share them, and are not part of the supported API of this package:
/// they change or disappear whenever the internal suites stop needing them.
/// Everything an app test needs is in `package:supabase_test/supabase_test.dart`.
library;

export 'src/internal_fixtures.dart';
export 'src/internal_http_clients.dart';
