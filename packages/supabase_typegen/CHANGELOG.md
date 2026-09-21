## 0.3.0

> Note: This release has breaking changes.

 - **FIX**(supabase_typegen): look up the configuration from an explicit directory ([#1867](https://github.com/supabase/supabase-flutter/issues/1867)). ([d0cee6c0](https://github.com/supabase/supabase-flutter/commit/d0cee6c0878ea43170982e6a505f7a422feac5f7))
 - **BREAKING** **FIX**(typegen): map bytea columns to Uint8List instead of String ([#1866](https://github.com/supabase/supabase-flutter/issues/1866)). ([2bb3ff02](https://github.com/supabase/supabase-flutter/commit/2bb3ff027968c4a590182876da03822a4104a375))
 - **BREAKING** **FEAT**(typegen): generate types for every exposed schema and route typed tables to their schema ([#1861](https://github.com/supabase/supabase-flutter/issues/1861)). ([6f9e716b](https://github.com/supabase/supabase-flutter/commit/6f9e716b9a55d8bf64ccad1829ee77bdbfc87caa))
 - **BREAKING** **FEAT**(postgrest): carry primary keys and relation columns on PostgrestTable and emit them from typegen ([#1859](https://github.com/supabase/supabase-flutter/issues/1859)). ([04ce54cf](https://github.com/supabase/supabase-flutter/commit/04ce54cfb96f64d69e1670522f2ef68183a7feb9))

## 0.2.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**(postgrest): only accept the table's Insert and Update types on the typed builder ([#1849](https://github.com/supabase/supabase-flutter/issues/1849)). ([333cc5c3](https://github.com/supabase/supabase-flutter/commit/333cc5c3df57c76a40530437f8415b7621b761bd))

## 0.1.4

 - **FEAT**(supabase_typegen): introspect the database through the Supabase CLI ([#1837](https://github.com/supabase/supabase-flutter/issues/1837)). ([78d0f7aa](https://github.com/supabase/supabase-flutter/commit/78d0f7aae4e35799883bd8a4219b6b2e86d166fc))

## 0.1.3

 - **FEAT**(supabase_typegen): emit relation members from foreign key metadata ([#1809](https://github.com/supabase/supabase-flutter/issues/1809)). ([9efd2d19](https://github.com/supabase/supabase-flutter/commit/9efd2d194012868cb85017f89a0b0a465fd81826))
 - **FEAT**(postgrest): add typed ranges to the column-expression surface ([#1808](https://github.com/supabase/supabase-flutter/issues/1808)). ([5ad78b9e](https://github.com/supabase/supabase-flutter/commit/5ad78b9e42afd618b0a67e0bdc0c3f2f203f8df6))
 - **FEAT**(postgrest): route where, order and select through column expressions ([#1795](https://github.com/supabase/supabase-flutter/issues/1795)). ([2c350e5d](https://github.com/supabase/supabase-flutter/commit/2c350e5d29cdfc31370f56850d1a61f8ef10316e))

## 0.1.2

 - **FEAT**: add supabase_typegen package generating typed table definitions ([#1635](https://github.com/supabase/supabase-flutter/issues/1635)). ([6cfea7b1](https://github.com/supabase/supabase-flutter/commit/6cfea7b1cf4d4d7101f5971e4659fb1888e58506))

## 0.1.1

 - **FEAT**(typegen): add supabase_typegen skeleton package ([#1636](https://github.com/supabase/supabase-flutter/issues/1636)). ([91f26da0](https://github.com/supabase/supabase-flutter/commit/91f26da084369e88ad378127632d9326cef863a0))

## 0.1.0

 - Initial placeholder release reserving the `supabase_typegen` package name.
