## 0.4.1

 - Update a dependency to the latest release.

## 0.4.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**(postgrest): execute typed table builders through a PostgrestTableExecutor and add SupabaseClientPlugin ([#1857](https://github.com/supabase/supabase-flutter/issues/1857)). ([3ecb09b1](https://github.com/supabase/supabase-flutter/commit/3ecb09b1ad2013277282b5f0c694f2272132a355))
 - **BREAKING** **FEAT**(postgrest): carry primary keys and relation columns on PostgrestTable and emit them from typegen ([#1859](https://github.com/supabase/supabase-flutter/issues/1859)). ([04ce54cf](https://github.com/supabase/supabase-flutter/commit/04ce54cfb96f64d69e1670522f2ef68183a7feb9))

## 0.3.0

> Note: This release has breaking changes.

 - **BREAKING** **REFACTOR**(auth): return Session from the auth methods that always issue one ([#1845](https://github.com/supabase/supabase-flutter/issues/1845)). ([b63898ea](https://github.com/supabase/supabase-flutter/commit/b63898ead6223941da0f7bb4b7437092c59377d7))
 - **BREAKING** **FEAT**(postgrest): only accept the table's Insert and Update types on the typed builder ([#1849](https://github.com/supabase/supabase-flutter/issues/1849)). ([333cc5c3](https://github.com/supabase/supabase-flutter/commit/333cc5c3df57c76a40530437f8415b7621b761bd))

## 0.2.1

 - **FEAT**(storage): add file versioning and bucket lifecycle policies ([#1834](https://github.com/supabase/supabase-flutter/issues/1834)). ([564576ad](https://github.com/supabase/supabase-flutter/commit/564576adb75ada73b2f68573a0dfa82b5a91c3f1))

## 0.2.0

> Note: This release has breaking changes.

 - **REFACTOR**: rename supabase_testing to supabase_test ([#1812](https://github.com/supabase/supabase-flutter/issues/1812)). ([1e15663d](https://github.com/supabase/supabase-flutter/commit/1e15663dbe8c673866f2e23191e185297dd4ae01))
 - **FIX**(supabase_test): match stub paths behind URL prefixes and widen the auth shorthands ([#1814](https://github.com/supabase/supabase-flutter/issues/1814)). ([83517082](https://github.com/supabase/supabase-flutter/commit/83517082a42bc4d3f3068fa63a1f1909bb165856))
 - **FEAT**(supabase_test): stub failures, stalls, status sequences and text bodies ([#1825](https://github.com/supabase/supabase-flutter/issues/1825)). ([e16317a6](https://github.com/supabase/supabase-flutter/commit/e16317a679dc0462e3e2a7ea9f540d46116b8952))
 - **FEAT**(supabase_flutter): test initialization helper for widget tests ([#1819](https://github.com/supabase/supabase-flutter/issues/1819)). ([4136f0e4](https://github.com/supabase/supabase-flutter/commit/4136f0e4f765e2ec98fe13e7c8ebe5603407814d))
 - **FEAT**(supabase_test): match table and rpc stubs on the schema ([#1820](https://github.com/supabase/supabase-flutter/issues/1820)). ([07583bb4](https://github.com/supabase/supabase-flutter/commit/07583bb4158986cc413867bf4cea7b5876c3fbeb))
 - **FEAT**(supabase_test): mock realtime transport for testing streams and channels ([#1818](https://github.com/supabase/supabase-flutter/issues/1818)). ([b2e26633](https://github.com/supabase/supabase-flutter/commit/b2e26633d16512a9b7cc594b5b6c257efb4668fc))
 - **FEAT**(supabase_test): storage endpoint shorthands ([#1817](https://github.com/supabase/supabase-flutter/issues/1817)). ([64cc72a7](https://github.com/supabase/supabase-flutter/commit/64cc72a79f9d8e2eb883a9db0605301c9172bea7))
 - **FEAT**(supabase_test): match stubs on query parameters ([#1816](https://github.com/supabase/supabase-flutter/issues/1816)). ([7d2a589c](https://github.com/supabase/supabase-flutter/commit/7d2a589ccdf415bdba11e66d34a48f6774085e7c))
 - **FEAT**(supabase_test): shape PostgREST responses and answer requests from handlers ([#1813](https://github.com/supabase/supabase-flutter/issues/1813)). ([fda7bb56](https://github.com/supabase/supabase-flutter/commit/fda7bb56a72c6c9c4a12c1f260c6fef15c76930a))
 - **BREAKING** **FEAT**(auth): let AuthClient own session persistence through one storage ([#1805](https://github.com/supabase/supabase-flutter/issues/1805)). ([a587f5af](https://github.com/supabase/supabase-flutter/commit/a587f5afbeee19ae069722b6b6a39b6c22dfb2c5))

## 0.1.1

 - Update a dependency to the latest release.

## 0.1.0

 - Initial release. Test helpers for apps built on the Supabase clients, extracted from the internal test suites.
