## 0.8.1

 - **REFACTOR**: share the JsonFields helper through supabase_common ([#2082](https://github.com/supabase/supabase-flutter/issues/2082)). ([f45bc196](https://github.com/supabase/supabase-flutter/commit/f45bc19652ba4627e6d951d5a3605e2fa7c41eb6))
 - **FIX**(realtime): read decoded JSON through JsonFields ([#2085](https://github.com/supabase/supabase-flutter/issues/2085)). ([84e18263](https://github.com/supabase/supabase-flutter/commit/84e182632087c852214dd1c03fd645fbf8af3e29))
 - **FIX**: check the shape of auth payloads and onError results instead of catching TypeError ([#2081](https://github.com/supabase/supabase-flutter/issues/2081)). ([48cd29f2](https://github.com/supabase/supabase-flutter/commit/48cd29f2a2c36bc4f12a2b1c3bf6ce7013154881))
 - **FIX**: check input shapes instead of catching TypeError and NoSuchMethodError ([#2080](https://github.com/supabase/supabase-flutter/issues/2080)). ([b4d8fc01](https://github.com/supabase/supabase-flutter/commit/b4d8fc015466c9ba8065cec62963543d6c233108))

## 0.8.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**(postgrest): a dedicated type for json and jsonb columns ([#2063](https://github.com/supabase/supabase-flutter/issues/2063)). ([fe3cbec3](https://github.com/supabase/supabase-flutter/commit/fe3cbec34cad3909040d4d471cbf79d13baf9fc1))

## 0.7.0

> Note: This release has breaking changes.

 - **FIX**(typegen): disambiguate embeds of opposite-direction keys and junction tables, alias embeds named like columns ([#2020](https://github.com/supabase/supabase-flutter/issues/2020)). ([587a2535](https://github.com/supabase/supabase-flutter/commit/587a2535f3da4875f3e0961d2e44e7abf38a3f67))
 - **FIX**(typegen): respect formatter settings on stdout and fail loudly on bad input ([#2023](https://github.com/supabase/supabase-flutter/issues/2023)). ([428d3052](https://github.com/supabase/supabase-flutter/commit/428d3052ebe8e2ca38bd90fa1d50f485873c1afd))
 - **FEAT**: ship agent skills with supabase_flutter, supabase, supabase_typegen and supabase_test ([#2011](https://github.com/supabase/supabase-flutter/issues/2011)). ([3f415f4e](https://github.com/supabase/supabase-flutter/commit/3f415f4e88a7d7c328583fb310480bd64d4bea9a))
 - **DOCS**: update every README to the v3 API ([#2008](https://github.com/supabase/supabase-flutter/issues/2008)). ([9357d479](https://github.com/supabase/supabase-flutter/commit/9357d479e5a12a1b72176e2846d714831da6b0f7))
 - **BREAKING** **FIX**(typegen): stop renaming generated types that clash with supabase_flutter and Flutter names ([#2047](https://github.com/supabase/supabase-flutter/issues/2047)). ([3d6a2b87](https://github.com/supabase/supabase-flutter/commit/3d6a2b874bc509f55887f44f4be093981e60c371))
 - **BREAKING** **FIX**(typegen): suffix names that clash with SDK and Flutter types, and decode unknown enum labels and infinite timestamps ([#2044](https://github.com/supabase/supabase-flutter/issues/2044)). ([96e7e88f](https://github.com/supabase/supabase-flutter/commit/96e7e88fcc4b87bbcf75c8579d78933adbe34010))
 - **BREAKING** **FIX**(postgrest): send DateTime filter operands with their offset from UTC ([#2024](https://github.com/supabase/supabase-flutter/issues/2024)). ([5248812b](https://github.com/supabase/supabase-flutter/commit/5248812bae286d9bdf16ccf9b57215db900ba2d8))

## 0.6.0

> Note: This release has breaking changes.

 - **FIX**(supabase): reject stream filters on integer vector columns ([#2000](https://github.com/supabase/supabase-flutter/issues/2000)). ([48ac11c6](https://github.com/supabase/supabase-flutter/commit/48ac11c62ee27ffb3f6762d6e357a0a927550517))
 - **FIX**(typegen): read built-in type names only from pg_catalog ([#1990](https://github.com/supabase/supabase-flutter/issues/1990)). ([18d2f426](https://github.com/supabase/supabase-flutter/commit/18d2f4262fd7188019f523e3d6d89b41376ce243))
 - **FIX**(typegen): keep a schema or function name with a line break inside one doc comment code span ([#1976](https://github.com/supabase/supabase-flutter/issues/1976)). ([55c05659](https://github.com/supabase/supabase-flutter/commit/55c05659b173214bfb669c29fa5664a5718de3aa))
 - **FEAT**(postgrest): retry typed calls of stable and immutable functions over GET ([#1982](https://github.com/supabase/supabase-flutter/issues/1982)). ([5ca35d92](https://github.com/supabase/supabase-flutter/commit/5ca35d92b3e079911c98f9949a58af54a33cb0b6))
 - **FEAT**(typegen): non-null view columns from postgrest-typegen 0.6.0 ([#1968](https://github.com/supabase/supabase-flutter/issues/1968)). ([c9f89d51](https://github.com/supabase/supabase-flutter/commit/c9f89d5193bd368e4af9f478dedea091ead2c382))
 - **BREAKING** **REFACTOR**: move the Postgres value types to supabase_common ([#1993](https://github.com/supabase/supabase-flutter/issues/1993)). ([abd3148a](https://github.com/supabase/supabase-flutter/commit/abd3148ac21a1792412eb767683eaa0541598b0c))
 - **BREAKING** **FIX**(typegen): read oid and xid8 columns as numbers ([#1992](https://github.com/supabase/supabase-flutter/issues/1992)). ([a0261a9d](https://github.com/supabase/supabase-flutter/commit/a0261a9d4aed7593bab52b94728ba47d5919c3c1))
 - **BREAKING** **FIX**(typegen): map string-serialized catalog types to String ([#1991](https://github.com/supabase/supabase-flutter/issues/1991)). ([2a0e6865](https://github.com/supabase/supabase-flutter/commit/2a0e686516415861136c216a014f17c91a2f382c))
 - **BREAKING** **FIX**(postgrest): key aggregates and casts by their own expression ([#1988](https://github.com/supabase/supabase-flutter/issues/1988)). ([5609af7f](https://github.com/supabase/supabase-flutter/commit/5609af7f3c38525daf22218eec1194fcac5b901d))
 - **BREAKING** **FEAT**(typegen): read multirange columns into a multirange type ([#1999](https://github.com/supabase/supabase-flutter/issues/1999)). ([e5b8bdeb](https://github.com/supabase/supabase-flutter/commit/e5b8bdebc835d5c7ce8153b623c938980563a064))
 - **BREAKING** **FEAT**(typegen): read geometric columns into value types ([#1998](https://github.com/supabase/supabase-flutter/issues/1998)). ([995cf727](https://github.com/supabase/supabase-flutter/commit/995cf7271ea46dc8530f6a896365a21beca9840a))
 - **BREAKING** **FEAT**(typegen): read inet and cidr columns into a network address type ([#1997](https://github.com/supabase/supabase-flutter/issues/1997)). ([ed69ae31](https://github.com/supabase/supabase-flutter/commit/ed69ae312021cdfdad5f54f9e59f064dd54d6ed3))
 - **BREAKING** **FEAT**(typegen): read int2vector and oidvector columns as integer lists ([#1996](https://github.com/supabase/supabase-flutter/issues/1996)). ([a1526378](https://github.com/supabase/supabase-flutter/commit/a15263780dcfffd30c198346dd0ec2828a612964))
 - **BREAKING** **FEAT**(typegen): read pg_lsn and macaddr columns into value types ([#1994](https://github.com/supabase/supabase-flutter/issues/1994)). ([307fe4ad](https://github.com/supabase/supabase-flutter/commit/307fe4adbec1f63506054288512831cdc90b0f8f))
 - **BREAKING** **FEAT**(typegen): generate only from the document the Supabase CLI pipes in ([#1963](https://github.com/supabase/supabase-flutter/issues/1963)). ([b44859b8](https://github.com/supabase/supabase-flutter/commit/b44859b8fd9480d18bec2a16ef56ff18cf0accdc))

## 0.5.2

 - **FEAT**(typegen): generate typed RPC methods from rpcFunctions ([#1959](https://github.com/supabase/supabase-flutter/issues/1959)). ([82e457bb](https://github.com/supabase/supabase-flutter/commit/82e457bb197e698d21796ae1cb5fb6c09de8a6c5))

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
