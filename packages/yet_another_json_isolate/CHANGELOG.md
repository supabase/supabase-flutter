## 3.0.0

> Note: This release has breaking changes.

 - **REFACTOR**(yet_another_json_isolate): rename conditional import files to idiomatic names ([#1777](https://github.com/supabase/supabase-flutter/issues/1777)). ([bb250795](https://github.com/supabase/supabase-flutter/commit/bb25079503413bf183743180b7a99cafd4572a14))
 - **PERF**(yet_another_json_isolate): process small payloads inline and large ones on short-lived isolates ([#1746](https://github.com/supabase/supabase-flutter/issues/1746)). ([7942c377](https://github.com/supabase/supabase-flutter/commit/7942c37770c5a12b18b27afc66b8595e67fdd22d))
 - **FIX**(supabase_lints): enable lines_longer_than_80_chars and fix all violations ([#1655](https://github.com/supabase/supabase-flutter/issues/1655)). ([a08b6577](https://github.com/supabase/supabase-flutter/commit/a08b6577d002d0c7ae0d484ddd6da802922be37b))
 - **DOCS**(yet_another_json_isolate): enable public_member_api_docs ([#1768](https://github.com/supabase/supabase-flutter/issues/1768)). ([8e736ecf](https://github.com/supabase/supabase-flutter/commit/8e736ecf652bfa2a83d5e76f2e52ace32a8a4b2c))
 - **DOCS**: fix inaccurate dartdoc comments across all packages ([#1659](https://github.com/supabase/supabase-flutter/issues/1659)). ([090ee978](https://github.com/supabase/supabase-flutter/commit/090ee9781ccdc7a749902830697d51251aa9f052))
 - **BREAKING** **REFACTOR**: process JSON through the AsyncJsonCodec interface ([#1751](https://github.com/supabase/supabase-flutter/issues/1751)). ([6969eb38](https://github.com/supabase/supabase-flutter/commit/6969eb3805cc1920f5a44902ae2ce660170c13b3))
 - **BREAKING** **REFACTOR**: remove analyzer ignores by fixing the underlying code ([#1675](https://github.com/supabase/supabase-flutter/issues/1675)). ([9f367d77](https://github.com/supabase/supabase-flutter/commit/9f367d77f8f1e1723a985885db0de45123dce6f4))
 - **BREAKING** **REFACTOR**: remove all deprecated APIs and dead public surface for v3 ([#1661](https://github.com/supabase/supabase-flutter/issues/1661)). ([1ffa0deb](https://github.com/supabase/supabase-flutter/commit/1ffa0deba0371585c7a4ac93795cf199a58e2353))
 - **BREAKING** **FIX**: release retained resources on dispose ([#1668](https://github.com/supabase/supabase-flutter/issues/1668)). ([d21d8c03](https://github.com/supabase/supabase-flutter/commit/d21d8c03dd2ebbad5713f28157e2c9445e13c7e0))

## 2.1.1

 - **FIX**: raise min Dart SDK to 3.4.0 across all packages ([#1409](https://github.com/supabase/supabase-flutter/issues/1409)). ([311f883f](https://github.com/supabase/supabase-flutter/commit/311f883f73406b60a0e95ea05e3444a4bab80c5a))

## 2.1.0

 - **FEAT**: Add debugName parameter to YAJsonIsolate. ([#1118](https://github.com/supabase/supabase-flutter/issues/1118)). ([23ffc0e9](https://github.com/supabase/supabase-flutter/commit/23ffc0e9e3145adf49f7bb3d85c0cf4191ba9b99))

## 2.0.3

 - **FIX**(yet_another_json_isolate): Conditional export now works correctly with Dart 3.5+ ([#1048](https://github.com/supabase/supabase-flutter/issues/1048)). ([6c80a745](https://github.com/supabase/supabase-flutter/commit/6c80a745cd387250995fa3140aac54169466f5bb))

## 2.0.2

 - **FIX**: Upgrade `web_socket_channel` for supporting `web: ^1.0.0` and therefore WASM compilation on web ([#992](https://github.com/supabase/supabase-flutter/issues/992)). ([7da68565](https://github.com/supabase/supabase-flutter/commit/7da68565a7aa578305b099d7af755a7b0bcaca46))

## 2.0.1

 - **FIX**: Make sure the package can be built on Flutter web ([#990](https://github.com/supabase/supabase-flutter/issues/990)). ([742b761c](https://github.com/supabase/supabase-flutter/commit/742b761c2c84a8b3d75e7966444f57a0dd5e692e))

## 2.0.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 2.0.0-dev.0

> Note: This release has breaking changes.

 - **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))

## 1.1.1

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

## 1.1.0

 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

## 1.0.4

 - chore: move the repo into supabase-flutter monorepo

## 1.0.3

- fix: correctly check for web platform

## 1.0.2

- fix: lower async package version

## 1.0.1

- fix: rename `init` to `initialize` on web

## 1.0.0

- Initial version.
