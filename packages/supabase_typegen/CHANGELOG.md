## 0.5.1

 - **FIX**(typegen): suffix a member named like a generated type ([#1921](https://github.com/supabase/supabase-flutter/issues/1921)). ([cf5624fa](https://github.com/supabase/supabase-flutter/commit/cf5624faff47f50546ce00348afb24cebc6b81ec))
 - **FIX**(typegen): suffix a schema object named function so the generated code compiles ([#1920](https://github.com/supabase/supabase-flutter/issues/1920)). ([9d27de5c](https://github.com/supabase/supabase-flutter/commit/9d27de5c725cbc5ff102bf5f18c274f76dbb0603))
 - **FIX**(typegen): generate a decoder for an enum named without ASCII letters ([#1919](https://github.com/supabase/supabase-flutter/issues/1919)). ([cf0256d9](https://github.com/supabase/supabase-flutter/commit/cf0256d908a935775fc6681a95159d2c31ebb5e1))
 - **FIX**(typegen): suffix members named like a core type so the generated code compiles ([#1914](https://github.com/supabase/supabase-flutter/issues/1914)). ([c885dd74](https://github.com/supabase/supabase-flutter/commit/c885dd7476f057f9444c4f7151f93da214252792))
 - **FEAT**(postgrest): add computed fields and computed relationships to the typed table surface ([#1905](https://github.com/supabase/supabase-flutter/issues/1905)). ([69e46365](https://github.com/supabase/supabase-flutter/commit/69e4636557617f2ea6c85fba1e69fc0f56b5ec76))
 - **FEAT**(supabase_typegen): default the generated import to the Supabase package the project depends on ([#1904](https://github.com/supabase/supabase-flutter/issues/1904)). ([a5c20985](https://github.com/supabase/supabase-flutter/commit/a5c20985d30c8d4ae138c5f4f8d77c68505bb489))

## 0.5.0

> Note: This release has breaking changes.

 - **FIX**(typegen): keep the document order of foreign keys when partitioning relationships ([#1894](https://github.com/supabase/supabase-flutter/issues/1894)). ([e1f4a83b](https://github.com/supabase/supabase-flutter/commit/e1f4a83b58e742067b831ffe0e496ae96ca02c69))
 - **FIX**(typegen): suffix a schema object named ArgumentError so the generated enums compile ([#1893](https://github.com/supabase/supabase-flutter/issues/1893)). ([03783d9e](https://github.com/supabase/supabase-flutter/commit/03783d9e203a4915a57cc6ea161e5fbef636372b))
 - **FIX**(supabase_typegen): order the view copies of a foreign key deterministically ([#1883](https://github.com/supabase/supabase-flutter/issues/1883)). ([6975f620](https://github.com/supabase/supabase-flutter/commit/6975f6205ae69b8c26e083a900dd5ae026f8d057))
 - **FEAT**(postgrest): type the embedded rows of a relation ([#1891](https://github.com/supabase/supabase-flutter/issues/1891)). ([0281f352](https://github.com/supabase/supabase-flutter/commit/0281f3527490df26bf6ae28a5a09566a129e57c9))
 - **BREAKING** **FEAT**(postgrest): type a partial select as a partial row instead of the full row ([#1897](https://github.com/supabase/supabase-flutter/issues/1897)). ([9378ac89](https://github.com/supabase/supabase-flutter/commit/9378ac891afb573f80992cea00dfb0efd73f583e))

## 0.4.0

> Note: This release has breaking changes.

 - **FIX**(supabase_typegen): format generated code for language version 3.8 ([#1874](https://github.com/supabase/supabase-flutter/issues/1874)). ([787b43f9](https://github.com/supabase/supabase-flutter/commit/787b43f911720fecad70964fb1c491ec09e26ace))
 - **BREAKING** **FEAT**(typegen): convert array elements the way their scalar columns are converted ([#1876](https://github.com/supabase/supabase-flutter/issues/1876)). ([727b82cc](https://github.com/supabase/supabase-flutter/commit/727b82ccc9e03a04b168080ffb30e5ad46c318fe))
 - **BREAKING** **FEAT**(typegen): map date, time and interval columns to PostgrestDate, PostgrestTime and PostgrestInterval ([#1875](https://github.com/supabase/supabase-flutter/issues/1875)). ([443190b2](https://github.com/supabase/supabase-flutter/commit/443190b2a0332d09e2eea2cf591d00e89646a1dc))
 - **BREAKING** **FEAT**(typegen): map pgvector columns to List<double> instead of Object? ([#1873](https://github.com/supabase/supabase-flutter/issues/1873)). ([74a957fd](https://github.com/supabase/supabase-flutter/commit/74a957fdf04968a0e7f9bbc43bdeb9f1b5dbca8a))

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
