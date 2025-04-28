## 2.4.2

 - **FIX**: FunctionException implements Exception ([#1134](https://github.com/supabase/supabase-flutter/issues/1134)). ([79edb81c](https://github.com/supabase/supabase-flutter/commit/79edb81c478ade80baab32c70740e988a692c85d))

## 2.4.1

 - **DOCS**: Fix typos ([#1108](https://github.com/supabase/supabase-flutter/issues/1108)). ([46b483f8](https://github.com/supabase/supabase-flutter/commit/46b483f83a70fb7785ef3bccca6849fa6b07852c))

## 2.4.0

 - **FEAT**: Add logging ([#1042](https://github.com/supabase/supabase-flutter/issues/1042)). ([d1ecabd7](https://github.com/supabase/supabase-flutter/commit/d1ecabd77881a0488d2d4b41ea5ee5abda6c5c35))

## 2.3.3

 - Update a dependency to the latest release.

## 2.3.2

 - **FIX**: Upgrade `web_socket_channel` for supporting `web: ^1.0.0` and therefore WASM compilation on web ([#992](https://github.com/supabase/supabase-flutter/issues/992)). ([7da68565](https://github.com/supabase/supabase-flutter/commit/7da68565a7aa578305b099d7af755a7b0bcaca46))

## 2.3.1

 - Update a dependency to the latest release.

## 2.3.0

 - **FIX**(functions_client): Add `toString` to `FunctionException` ([#985](https://github.com/supabase/supabase-flutter/issues/985)). ([e072ff74](https://github.com/supabase/supabase-flutter/commit/e072ff74c71858ea3c9ede3361d2cdf710b22388))
 - **FEAT**: Support MultipartRequest in functions invoke ([#977](https://github.com/supabase/supabase-flutter/issues/977)). ([09698edf](https://github.com/supabase/supabase-flutter/commit/09698edfba348794aee52e28d55903941cc49bcf))

## 2.2.0

 - **FEAT**(functions): Invoke function with custom query params ([#926](https://github.com/supabase/supabase-flutter/issues/926)). ([7ded898d](https://github.com/supabase/supabase-flutter/commit/7ded898dee07004cbb20e4d7c209f94a507fad3b))

## 2.1.0

 - **FEAT**(functions_client): Add SSE support to invoke method ([#905](https://github.com/supabase/supabase-flutter/issues/905)). ([2e052440](https://github.com/supabase/supabase-flutter/commit/2e052440e3889e52cb97cb44a70048713e0b583e))

## 2.0.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 2.0.0-dev.0

> Note: This release has breaking changes.

 - **FIX**(functions_client): use header for response parsing ([#616](https://github.com/supabase/supabase-flutter/issues/616)). ([e413acbb](https://github.com/supabase/supabase-flutter/commit/e413acbb6fc424ae419c569a47a023c41aa34b45))
 - **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))
 - **BREAKING** **FIX**: throw exception on non 2xx status ([#629](https://github.com/supabase/supabase-flutter/issues/629)). ([db5ec824](https://github.com/supabase/supabase-flutter/commit/db5ec824c625f7ba24bceccdb5b0de452ce45dca))
 - **BREAKING** **FEAT**: use Object? instead of dynamic ([#606](https://github.com/supabase/supabase-flutter/issues/606)). ([0c6caa00](https://github.com/supabase/supabase-flutter/commit/0c6caa00912bc73fc220110bdd9f3d69aaecb3ac))

## 1.3.2

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

## 1.3.1

 - **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

## 1.3.0

 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

## 1.2.1

 - chore: move the repo into supabase-flutter monorepo

## [1.2.0]

- feat: expose `headers` getter

## [1.1.1]

- fix: use utf8 encoding for text response

## [1.1.0]

- feat: add `method` parameter to `invoke()` to support all GET, POST, PUT, PATCH, DELETE methods

## [1.0.2]

- fix: add `await functions.dispose()` method to dispose yet_another_json_isolate instance

## [1.0.1]

- fix: use yet_another_json_isolate for json encoding/decoding

## [1.0.0]

- chore: v1.0.0 release 🚀
- BREAKING: set minimum SDK version to 2.15.0

## [1.0.0-dev.4]

- fix: Support null body when invoking functions

## [1.0.0-dev.3]

- BREAKING: `error` is now thrown instead of being returned within a response
```dart
try {
  final res = await functions.invoke('myFunction');
  print(res.data);
} catch (error, stacktrace) {
  print('$error \n $stracktrace');
}
```

## [1.0.0-dev.2]

- feat: use isolates for json encoding/decoding

## [1.0.0-dev.1]

- chore: Update lints to v2.0.0

## [0.0.1-dev.5]

- fix: Change the minimul SDK version to 2.12.0

## [0.0.1-dev.4]

- fix: Fix a bug where json is not properly encoded.
- fix: Set default headers with X-Client-Info.

## [0.0.1-dev.3]

- BREAKIMG: 'body', 'headers', and `responseType` are now named parameters of `invoke()`.

## [0.0.1-dev.2]

- BREAKIMG: `functionsUrl` and `headers` are now positional arguments.

## [0.0.1-dev.1]

- Initial pre-release.
