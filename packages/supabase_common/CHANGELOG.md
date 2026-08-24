## 3.0.0-dev.1

> Note: This release has breaking changes.

 - **REFACTOR**: share the test helpers through supabase_common ([#1745](https://github.com/supabase/supabase-flutter/issues/1745)). ([bcb41fa4](https://github.com/supabase/supabase-flutter/commit/bcb41fa4d9ef840c0380e641d3e45968084090c8))
 - **REFACTOR**: share the auth callback parameters and secure random helpers ([#1744](https://github.com/supabase/supabase-flutter/issues/1744)). ([66ac4901](https://github.com/supabase/supabase-flutter/commit/66ac4901c684b83faae96e13ac560d7efdac158e))
 - **REFACTOR**: share the HTTP request pieces between the fetch layers ([#1647](https://github.com/supabase/supabase-flutter/issues/1647)). ([a2a9eeaa](https://github.com/supabase/supabase-flutter/commit/a2a9eeaac4f8cc5d98199945283245b697e07a19))
 - **FIX**(supabase_lints): enable lines_longer_than_80_chars and fix all violations ([#1655](https://github.com/supabase/supabase-flutter/issues/1655)). ([a08b6577](https://github.com/supabase/supabase-flutter/commit/a08b6577d002d0c7ae0d484ddd6da802922be37b))
 - **FIX**(supabase_common): accept uppercase and mixed-case UUIDs in validation ([#1656](https://github.com/supabase/supabase-flutter/issues/1656)). ([691690cf](https://github.com/supabase/supabase-flutter/commit/691690cfc748456794216028e92dd7075c263055))
 - **FEAT**: introduce the supabase_testing package ([#1747](https://github.com/supabase/supabase-flutter/issues/1747)). ([5a3aa9b4](https://github.com/supabase/supabase-flutter/commit/5a3aa9b4265385e3d747ca70ad499102fa388ee9))
 - **FEAT**: resolve an access token per request on the standalone clients ([#1742](https://github.com/supabase/supabase-flutter/issues/1742)). ([dd61782a](https://github.com/supabase/supabase-flutter/commit/dd61782a35f1a99af95f5457b5a3393b3d7939b9))
 - **FEAT**(storage): expose the service error code on StorageException ([#1657](https://github.com/supabase/supabase-flutter/issues/1657)). ([4f9cabfe](https://github.com/supabase/supabase-flutter/commit/4f9cabfe94bec8800721f1153ed6c40f659157ec))
 - **DOCS**: fix inaccurate dartdoc comments across all packages ([#1659](https://github.com/supabase/supabase-flutter/issues/1659)). ([090ee978](https://github.com/supabase/supabase-flutter/commit/090ee9781ccdc7a749902830697d51251aa9f052))
 - **BREAKING** **REFACTOR**(storage): share one SortDirection enum across the packages ([#1752](https://github.com/supabase/supabase-flutter/issues/1752)). ([38396ed5](https://github.com/supabase/supabase-flutter/commit/38396ed5a40d04f24096a816bfead0d57f440394))
 - **BREAKING** **REFACTOR**: rework logging to emit only through the supabase logger hierarchy ([#1741](https://github.com/supabase/supabase-flutter/issues/1741)). ([d1642c80](https://github.com/supabase/supabase-flutter/commit/d1642c80c60d93cf3bf7919b0cef775470275ed9))
 - **BREAKING** **REFACTOR**: share one retry configuration across the clients ([#1738](https://github.com/supabase/supabase-flutter/issues/1738)). ([3b2a4855](https://github.com/supabase/supabase-flutter/commit/3b2a4855a5d2e83af17d3cd280189c6a89170741))
 - **BREAKING** **REFACTOR**: spell out abbreviations in the public API ([#1712](https://github.com/supabase/supabase-flutter/issues/1712)). ([29286f43](https://github.com/supabase/supabase-flutter/commit/29286f4309a74da769ed7aad569daacba6dee7ae))
 - **BREAKING** **REFACTOR**: share one exponential backoff calculation ([#1646](https://github.com/supabase/supabase-flutter/issues/1646)). ([8bc93f5d](https://github.com/supabase/supabase-flutter/commit/8bc93f5d8ccd72351dc1789e30a4aa9c8e8de1fa))
 - **BREAKING** **REFACTOR**: split every service exception into a client and an api base ([#1644](https://github.com/supabase/supabase-flutter/issues/1644)). ([0202c332](https://github.com/supabase/supabase-flutter/commit/0202c33249828dc96a778af5fd72520ca5234a46))
 - **BREAKING** **REFACTOR**: share a single HttpMethod enum across the packages ([#1678](https://github.com/supabase/supabase-flutter/issues/1678)). ([23d55c37](https://github.com/supabase/supabase-flutter/commit/23d55c376fe8e2aa0ff4083f2ff39488fe827979))
 - **BREAKING** **FIX**(supabase_flutter): persist the session with SharedPreferencesAsync ([#1680](https://github.com/supabase/supabase-flutter/issues/1680)). ([41500b73](https://github.com/supabase/supabase-flutter/commit/41500b73e207cc812c2d42e4e4f4a79127e0502b))
 - **BREAKING** **FEAT**: rename the storage_client package to supabase_storage ([#1715](https://github.com/supabase/supabase-flutter/issues/1715)). ([6b0388f2](https://github.com/supabase/supabase-flutter/commit/6b0388f209c87dc57ee7281d211fff241e13ec6a))
 - **BREAKING** **FEAT**: rename the realtime_client package to supabase_realtime ([#1714](https://github.com/supabase/supabase-flutter/issues/1714)). ([d37bed56](https://github.com/supabase/supabase-flutter/commit/d37bed567711c8ed68590a002bb3f1a45432abcb))
 - **BREAKING** **FEAT**: rename the functions_client package to supabase_functions ([#1713](https://github.com/supabase/supabase-flutter/issues/1713)). ([eb4f3773](https://github.com/supabase/supabase-flutter/commit/eb4f3773e74dd62be5a768433d0a2497d643f110))
 - **BREAKING** **FEAT**: rename the gotrue package to supabase_auth ([#1697](https://github.com/supabase/supabase-flutter/issues/1697)). ([563b502e](https://github.com/supabase/supabase-flutter/commit/563b502ee64d161defddeceaaacc43615f39b75c))
 - **BREAKING** **FEAT**: use DateTime for all timestamp fields ([#1663](https://github.com/supabase/supabase-flutter/issues/1663)). ([bad3af8f](https://github.com/supabase/supabase-flutter/commit/bad3af8f88735caac5334b6d0a6e21fa02a220fb))

## 0.1.2

 - **REFACTOR**(supabase_common): share the local stack test configuration ([#1640](https://github.com/supabase/supabase-flutter/issues/1640)). ([a08f06d3](https://github.com/supabase/supabase-flutter/commit/a08f06d3b746d1fa5e3cd17c3370fe10466cb69b))

## 0.1.1

 - **REFACTOR**: extract shared code into supabase_common package ([#1573](https://github.com/supabase/supabase-flutter/issues/1573)). ([46601bbb](https://github.com/supabase/supabase-flutter/commit/46601bbb80ca2f52929f8e0c2a6e5456d3e32360))
 - **FIX**(supabase_common): align platform stats casing with other SDKs ([#1596](https://github.com/supabase/supabase-flutter/issues/1596)). ([97a6fa6e](https://github.com/supabase/supabase-flutter/commit/97a6fa6eb1f7d5f58b693a5e175fbfe4fe7d2c17))

## 0.1.0

 - Initial release. Shared internal utilities extracted from the Supabase client packages.
