## 0.1.0

 - Initial release. Apache Iceberg REST Catalog client extracted from storage_client.
 - **REFACTOR**: share the test helpers through supabase_common ([#1745](https://github.com/supabase/supabase-flutter/issues/1745)). ([bcb41fa4](https://github.com/supabase/supabase-flutter/commit/bcb41fa4d9ef840c0380e641d3e45968084090c8))
 - **REFACTOR**: share the auth callback parameters and secure random helpers ([#1744](https://github.com/supabase/supabase-flutter/issues/1744)). ([66ac4901](https://github.com/supabase/supabase-flutter/commit/66ac4901c684b83faae96e13ac560d7efdac158e))
 - **FEAT**: introduce the supabase_testing package ([#1747](https://github.com/supabase/supabase-flutter/issues/1747)). ([5a3aa9b4](https://github.com/supabase/supabase-flutter/commit/5a3aa9b4265385e3d747ca70ad499102fa388ee9))
 - **BREAKING** **REFACTOR**(storage): share one SortDirection enum across the packages ([#1752](https://github.com/supabase/supabase-flutter/issues/1752)). ([38396ed5](https://github.com/supabase/supabase-flutter/commit/38396ed5a40d04f24096a816bfead0d57f440394))
 - **BREAKING** **REFACTOR**: rework logging to emit only through the supabase logger hierarchy ([#1741](https://github.com/supabase/supabase-flutter/issues/1741)). ([d1642c80](https://github.com/supabase/supabase-flutter/commit/d1642c80c60d93cf3bf7919b0cef775470275ed9))
 - **BREAKING** **REFACTOR**(storage): move the Iceberg catalog into its own package ([#1711](https://github.com/supabase/supabase-flutter/issues/1711)). ([26fc503d](https://github.com/supabase/supabase-flutter/commit/26fc503d8a452f2ce6292c55bcee1f32784fb52d))
