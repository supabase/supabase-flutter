# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2024-07-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`functions_client` - `v2.3.0`](#functions_client---v230)
 - [`supabase` - `v2.2.6`](#supabase---v226)
 - [`supabase_flutter` - `v2.5.10`](#supabase_flutter---v2510)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.2.6`
 - `supabase_flutter` - `v2.5.10`

---

#### `functions_client` - `v2.3.0`

 - **FIX**(functions_client): Add `toString` to `FunctionException` ([#985](https://github.com/supabase/supabase-flutter/issues/985)). ([e072ff74](https://github.com/supabase/supabase-flutter/commit/e072ff74c71858ea3c9ede3361d2cdf710b22388))
 - **FEAT**: Support MultipartRequest in functions invoke ([#977](https://github.com/supabase/supabase-flutter/issues/977)). ([09698edf](https://github.com/supabase/supabase-flutter/commit/09698edfba348794aee52e28d55903941cc49bcf))


## 2024-07-21

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`supabase` - `v2.2.5`](#supabase---v225)
 - [`supabase_flutter` - `v2.5.9`](#supabase_flutter---v259)

---

#### `supabase` - `v2.2.5`

 - **FIX**: Add error messages for when the session or expiresAt was missing while making API requests.  ([#976](https://github.com/supabase/supabase-flutter/issues/976)). ([a25993cb](https://github.com/supabase/supabase-flutter/commit/a25993cbe5270c862023c23741fa0be048bb4731))

#### `supabase_flutter` - `v2.5.9`

 - **FIX**(gotrue): Ensure a single `initialSession` is emitted. ([#975](https://github.com/supabase/supabase-flutter/issues/975)). ([6323f9fd](https://github.com/supabase/supabase-flutter/commit/6323f9fd40564b36027a1fc48004822baa063e19))


## 2024-07-12

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v2.8.3`](#gotrue---v283)
 - [`realtime_client` - `v2.2.0`](#realtime_client---v220)
 - [`supabase_flutter` - `v2.5.8`](#supabase_flutter---v258)
 - [`supabase` - `v2.2.4`](#supabase---v224)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.2.4`

---

#### `gotrue` - `v2.8.3`

 - **FIX**: Add error_code from url to AuthException ([#968](https://github.com/supabase/supabase-flutter/issues/968)). ([c741fe9d](https://github.com/supabase/supabase-flutter/commit/c741fe9d7458e7aaadf779a8d8f14636b4aeb136))
 - **FIX**: Add magiclink as authenticaiton method in mfa ([#967](https://github.com/supabase/supabase-flutter/issues/967)). ([4a871773](https://github.com/supabase/supabase-flutter/commit/4a87177389ad834febee20e9159e1ae1eb8be890))

#### `realtime_client` - `v2.2.0`

 - **FEAT**(realtime_client): Add support for authorized realtime channels with broadcast and presence. ([#970](https://github.com/supabase/supabase-flutter/issues/970)). ([8305fef6](https://github.com/supabase/supabase-flutter/commit/8305fef65eecbcca5d7d39ad7fc684d4134a578d))

#### `supabase_flutter` - `v2.5.8`

 - **FIX**: Fix duplicate initial deeplink handling when using AppLinks >= 6.0.0 ([#965](https://github.com/supabase/supabase-flutter/issues/965)). ([74747f0d](https://github.com/supabase/supabase-flutter/commit/74747f0de13187ddb2ebfba06a75d902dd1d98a5))


## 2024-07-02

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v2.8.2`](#gotrue---v282)
 - [`supabase` - `v2.2.3`](#supabase---v223)
 - [`supabase_flutter` - `v2.5.7`](#supabase_flutter---v257)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.2.3`
 - `supabase_flutter` - `v2.5.7`

---

#### `gotrue` - `v2.8.2`

 - **FIX**: Store actual error in AuthException ([#959](https://github.com/supabase/supabase-flutter/issues/959)). ([aa6c2183](https://github.com/supabase/supabase-flutter/commit/aa6c2183891118f775a013227790fc92e4de8a73))


## 2024-06-17

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v2.8.1`](#gotrue---v281)
 - [`supabase` - `v2.2.2`](#supabase---v222)
 - [`supabase_flutter` - `v2.5.6`](#supabase_flutter---v256)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.2.2`
 - `supabase_flutter` - `v2.5.6`

---

#### `gotrue` - `v2.8.1`

 - **FIX**: Make token in verifyOtp nullable ([#950](https://github.com/supabase/supabase-flutter/issues/950)). ([0e69c58f](https://github.com/supabase/supabase-flutter/commit/0e69c58fab161c52c6f7a0127b3fb3f73f1995e4))


## 2024-06-11

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v2.8.0`](#gotrue---v280)
 - [`supabase` - `v2.2.1`](#supabase---v221)
 - [`supabase_flutter` - `v2.5.5`](#supabase_flutter---v255)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.2.1`
 - `supabase_flutter` - `v2.5.5`

---

#### `gotrue` - `v2.8.0`

 - **FIX**(gotrue): Signing in does not remove the session unless the operation succeeds. ([#945](https://github.com/supabase/supabase-flutter/issues/945)). ([b2854c56](https://github.com/supabase/supabase-flutter/commit/b2854c564f0f5e7844302a2f7e63394fa4c6fc34))
 - **FEAT**: Add zoom as a OAuth provider ([#944](https://github.com/supabase/supabase-flutter/issues/944)). ([98718b13](https://github.com/supabase/supabase-flutter/commit/98718b13172b4008547a2e2c6304b04ffb932bdf))


## 2024-05-28

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`storage_client` - `v2.0.2`](#storage_client---v202)
 - [`realtime_client` - `v2.1.0`](#realtime_client---v210)
 - [`supabase` - `v2.2.0`](#supabase---v220)
 - [`supabase_flutter` - `v2.5.4`](#supabase_flutter---v254)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase_flutter` - `v2.5.4`

---

#### `storage_client` - `v2.0.2`

 - **CHORE**: Add some comments on storage symbols ([#938](https://github.com/supabase/supabase-flutter/issues/938)).

#### `realtime_client` - `v2.1.0`

 - **FEAT**: Allow setting `timeout` of `RealtimeClient`. ([#932](https://github.com/supabase/supabase-flutter/issues/932)). ([dba8bae0](https://github.com/supabase/supabase-flutter/commit/dba8bae0c87209c8f900d753a1e15be7557a07dc))

#### `supabase` - `v2.2.0`

 - **FEAT**: Allow setting `timeout` of `RealtimeClient`. ([#932](https://github.com/supabase/supabase-flutter/issues/932)). ([dba8bae0](https://github.com/supabase/supabase-flutter/commit/dba8bae0c87209c8f900d753a1e15be7557a07dc))


## 2024-05-13

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`functions_client` - `v2.2.0`](#functions_client---v220)
 - [`gotrue` - `v2.7.0`](#gotrue---v270)
 - [`postgrest` - `v2.1.2`](#postgrest---v212)
 - [`supabase_flutter` - `v2.5.3`](#supabase_flutter---v253)
 - [`supabase` - `v2.1.3`](#supabase---v213)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.1.3`

---

#### `functions_client` - `v2.2.0`

 - **FEAT**(functions): Invoke function with custom query params ([#926](https://github.com/supabase/supabase-flutter/issues/926)). ([7ded898d](https://github.com/supabase/supabase-flutter/commit/7ded898dee07004cbb20e4d7c209f94a507fad3b))

#### `gotrue` - `v2.7.0`

 - **FEAT**(goture): Allow OAuthProvider.kakao for signInWithIdToken ([#922](https://github.com/supabase/supabase-flutter/issues/922)). ([e21db454](https://github.com/supabase/supabase-flutter/commit/e21db454003bbd960af634a01b9642c46284715e))

#### `postgrest` - `v2.1.2`

 - **FIX**(postgrest): Update parameter type of `isFilter()` to only allow boolean or null ([#920](https://github.com/supabase/supabase-flutter/issues/920)). ([0a3b73e0](https://github.com/supabase/supabase-flutter/commit/0a3b73e02f90ad8d05cf96bf91336a951982b800))
 - **FIX**(postgrest): Update parameter type of `match()` filter so that null values cannot be passed.  ([#919](https://github.com/supabase/supabase-flutter/issues/919)). ([0902124f](https://github.com/supabase/supabase-flutter/commit/0902124f7fa4b0fab07cc4b43a895914514fd04a))

#### `supabase_flutter` - `v2.5.3`

 - **FIX**: Keep compatible with app_links 6.0.0 and 5.0.0 ([#918](https://github.com/supabase/supabase-flutter/issues/918)). ([04a59dca](https://github.com/supabase/supabase-flutter/commit/04a59dcae738cf41e3a7daa293751db444f80f4c))


## 2024-04-29

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`functions_client` - `v2.1.0`](#functions_client---v210)
 - [`gotrue` - `v2.6.1`](#gotrue---v261)
 - [`supabase_flutter` - `v2.5.2`](#supabase_flutter---v252)
 - [`supabase` - `v2.1.2`](#supabase---v212)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.1.2`

---

#### `functions_client` - `v2.1.0`

 - **FEAT**(functions_client): Add SSE support to invoke method ([#905](https://github.com/supabase/supabase-flutter/issues/905)). ([2e052440](https://github.com/supabase/supabase-flutter/commit/2e052440e3889e52cb97cb44a70048713e0b583e))

#### `gotrue` - `v2.6.1`

 - **FIX**: Add newEmail to admin generateLink method ([#904](https://github.com/supabase/supabase-flutter/issues/904)). ([5697e206](https://github.com/supabase/supabase-flutter/commit/5697e2060de1596626026a0f9ffd846435a6967a))
 - **FIX**: Weak password throws `AuthWeakPasswordException`. ([#897](https://github.com/supabase/supabase-flutter/issues/897)). ([4f5b853c](https://github.com/supabase/supabase-flutter/commit/4f5b853cfb72f92bdceb8446397057ec434f1da3))

#### `supabase_flutter` - `v2.5.2`

 - **FIX**: Update app_links dependency to accept v5.0.0 ([#908](https://github.com/supabase/supabase-flutter/issues/908)). ([7e9b9054](https://github.com/supabase/supabase-flutter/commit/7e9b905475c58d77078655e7cd944236f00a07a9))


## 2024-04-15

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`realtime_client` - `v2.0.4`](#realtime_client---v204)
 - [`supabase` - `v2.1.1`](#supabase---v211)
 - [`supabase_flutter` - `v2.5.1`](#supabase_flutter---v251)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.1.1`
 - `supabase_flutter` - `v2.5.1`

---

#### `realtime_client` - `v2.0.4`

 - **FIX**(realtime_client): Accept an error on track when the server returns an error ([#888](https://github.com/supabase/supabase-flutter/issues/888)). ([f829be58](https://github.com/supabase/supabase-flutter/commit/f829be584bab5af51256bbc8c176e95d52008ebe))


## 2024-04-09

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v2.6.0`](#gotrue---v260)
 - [`realtime_client` - `v2.0.3`](#realtime_client---v203)
 - [`supabase` - `v2.1.0`](#supabase---v210)
 - [`supabase_flutter` - `v2.5.0`](#supabase_flutter---v250)

---

#### `gotrue` - `v2.6.0`

 - **FIX**: Typos in gotrue_client.dart ([#882](https://github.com/supabase/supabase-flutter/issues/882)). ([54a0b979](https://github.com/supabase/supabase-flutter/commit/54a0b979f61a0a161b805c23329964ca626000ce))
 - **FEAT**(gotrue): Add `signInAnonymously()` method ([#883](https://github.com/supabase/supabase-flutter/issues/883)). ([2e636131](https://github.com/supabase/supabase-flutter/commit/2e636131667e6375a24fd08342c62f20eb5ea143))
 - **FEAT**(gotrue,supabase_flutter): New auth token refresh algorithm ([#879](https://github.com/supabase/supabase-flutter/issues/879)). ([99931681](https://github.com/supabase/supabase-flutter/commit/9993168137f2e48279840c6c1b311ac7ac6138a6))

#### `realtime_client` - `v2.0.3`

 - **FIX**: Don't send access token  in rest broadcast ([#881](https://github.com/supabase/supabase-flutter/issues/881)). ([01a10c97](https://github.com/supabase/supabase-flutter/commit/01a10c9708f6a9d4d2d2b0756009aa895c7238f6))

#### `supabase` - `v2.1.0`

 - **FIX**: Don't send access token  in rest broadcast ([#881](https://github.com/supabase/supabase-flutter/issues/881)). ([01a10c97](https://github.com/supabase/supabase-flutter/commit/01a10c9708f6a9d4d2d2b0756009aa895c7238f6))
 - **FEAT**(gotrue,supabase_flutter): New auth token refresh algorithm ([#879](https://github.com/supabase/supabase-flutter/issues/879)). ([99931681](https://github.com/supabase/supabase-flutter/commit/9993168137f2e48279840c6c1b311ac7ac6138a6))

#### `supabase_flutter` - `v2.5.0`

 - **FEAT**(gotrue,supabase_flutter): New auth token refresh algorithm ([#879](https://github.com/supabase/supabase-flutter/issues/879)). ([99931681](https://github.com/supabase/supabase-flutter/commit/9993168137f2e48279840c6c1b311ac7ac6138a6))


## 2024-04-02

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`realtime_client` - `v2.0.2`](#realtime_client---v202)
 - [`supabase_flutter` - `v2.4.0`](#supabase_flutter---v240)
 - [`supabase` - `v2.0.9`](#supabase---v209)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.0.9`

---

#### `realtime_client` - `v2.0.2`

 - **FIX**(realtime_client): Fix issue where `null` `timestamp` type column becomes `"null"` string on realtime ([#855](https://github.com/supabase/supabase-flutter/issues/855)). ([c59bdbbf](https://github.com/supabase/supabase-flutter/commit/c59bdbbf2b098f83d81d189cb36fd822787a880a))

#### `supabase_flutter` - `v2.4.0`

 - **FEAT**: Add `detectSessionInUri` option to optionally disable deep link observer.  ([#848](https://github.com/supabase/supabase-flutter/issues/848)). ([cb9aed80](https://github.com/supabase/supabase-flutter/commit/cb9aed8056a9725f8a3413958530474faef1d5d1))
 - **DOCS**: Fixed imprecision in Custom Local Storage README.md ([#853](https://github.com/supabase/supabase-flutter/issues/853)). ([6655e576](https://github.com/supabase/supabase-flutter/commit/6655e576b96550e91a24eccce3a79c948adf2922))


## 2024-02-19

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v2.5.1`](#gotrue---v251)
 - [`postgrest` - `v2.1.1`](#postgrest---v211)
 - [`realtime_client` - `v2.0.1`](#realtime_client---v201)
 - [`supabase` - `v2.0.8`](#supabase---v208)
 - [`supabase_flutter` - `v2.3.4`](#supabase_flutter---v234)

---

#### `gotrue` - `v2.5.1`

 - **FIX**: Correct the id value passed to `.unlinkIdentity()` method ([#841](https://github.com/supabase/supabase-flutter/issues/841)). ([0585cdde](https://github.com/supabase/supabase-flutter/commit/0585cdde4eefa61eda4c67e41b8f6f266b891fca))
 - **FIX**(gotrue,supabase_flutter): Throw error when parsing auth URL that contains an error description. ([#839](https://github.com/supabase/supabase-flutter/issues/839)). ([afc4ce51](https://github.com/supabase/supabase-flutter/commit/afc4ce51c14798c2319a0ebebe231895c6ddd8ae))

#### `postgrest` - `v2.1.1`

 - **DOCS**(postgrest): Expand documentation for `contains` and `containedBy` methods ([#824](https://github.com/supabase/supabase-flutter/issues/824)). ([e241e766](https://github.com/supabase/supabase-flutter/commit/e241e7668e4e0bafd6612011fef730f9b99874bc))

#### `realtime_client` - `v2.0.1`

 - **REFACTOR**: Deprecate `eventsPerSecond` on Realtime ([#838](https://github.com/supabase/supabase-flutter/issues/838)). ([42383873](https://github.com/supabase/supabase-flutter/commit/42383873a71bbfbecb971e752806241bfdcaa0c2))

#### `supabase` - `v2.0.8`

 - **REFACTOR**: Deprecate `eventsPerSecond` on Realtime ([#838](https://github.com/supabase/supabase-flutter/issues/838)). ([42383873](https://github.com/supabase/supabase-flutter/commit/42383873a71bbfbecb971e752806241bfdcaa0c2))

#### `supabase_flutter` - `v2.3.4`

 - **FIX**(gotrue,supabase_flutter): Throw error when parsing auth URL that contains an error description. ([#839](https://github.com/supabase/supabase-flutter/issues/839)). ([afc4ce51](https://github.com/supabase/supabase-flutter/commit/afc4ce51c14798c2319a0ebebe231895c6ddd8ae))
 - **FIX**: Correct the class name used for custom storage ([#825](https://github.com/supabase/supabase-flutter/issues/825)). ([a7216626](https://github.com/supabase/supabase-flutter/commit/a72166268facd97f07cf9588415a2f3d31f68c22))


## 2024-02-06

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`supabase_flutter` - `v2.3.3`](#supabase_flutter---v233)

---

#### `supabase_flutter` - `v2.3.3`

 - **REFACTOR**: Remove hive dependency and add instructinos to migration from v1 while persisting the auth state ([#823](https://github.com/supabase/supabase-flutter/issues/823)). ([26885c20](https://github.com/supabase/supabase-flutter/commit/26885c20167fd8f689ed0bd532fbff04f0e8006f))


## 2024-01-31

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v2.5.0`](#gotrue---v250)
 - [`storage_client` - `v2.0.1`](#storage_client---v201)
 - [`supabase_flutter` - `v2.3.2`](#supabase_flutter---v232)
 - [`supabase` - `v2.0.7`](#supabase---v207)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.0.7`

---

#### `gotrue` - `v2.5.0`

 - **FEAT**: Add token hash to verifyOtp ([#813](https://github.com/supabase/supabase-flutter/issues/813)). ([a789d795](https://github.com/supabase/supabase-flutter/commit/a789d7954f8a66e0e8eaa271b82cd2daf274e6de))

#### `storage_client` - `v2.0.1`

 - **FIX**: Use per client fetch instance ([#818](https://github.com/supabase/supabase-flutter/issues/818)). ([0f3182c4](https://github.com/supabase/supabase-flutter/commit/0f3182c4f34ca5096b6dd747edf6ade0d1ec1c9e))

#### `supabase_flutter` - `v2.3.2`

 - **FIX**: Remove platform check to start deep link observer on every platform including Linux ([#815](https://github.com/supabase/supabase-flutter/issues/815)). ([9b05eeac](https://github.com/supabase/supabase-flutter/commit/9b05eeac559a1f2da6289e1d70b3fa89e262fa3c))


## 2024-01-23

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v2.4.1`](#gotrue---v241)
 - [`supabase` - `v2.0.6`](#supabase---v206)
 - [`supabase_flutter` - `v2.3.1`](#supabase_flutter---v231)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.0.6`
 - `supabase_flutter` - `v2.3.1`

---

#### `gotrue` - `v2.4.1`

 - **FIX**(gotrue): Set _currentUser when setting initial session ([#806](https://github.com/supabase/supabase-flutter/issues/806)). ([042f3c6d](https://github.com/supabase/supabase-flutter/commit/042f3c6dde7db6f479088ad788a4bbcbba640808))


## 2024-01-19

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v2.4.0`](#gotrue---v240)
 - [`supabase_flutter` - `v2.3.0`](#supabase_flutter---v230)
 - [`supabase` - `v2.0.5`](#supabase---v205)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.0.5`

---

#### `gotrue` - `v2.4.0`

 - **FEAT**(gotrue,supabase_flutter): Add `signInWithSSO` method ([#798](https://github.com/supabase/supabase-flutter/issues/798)). ([87c16327](https://github.com/supabase/supabase-flutter/commit/87c163279866ac9d44756fd7d5faf01d48860fb0))

#### `supabase_flutter` - `v2.3.0`

 - **FIX**(supabase_flutter): Add timeout to Hive.openBox to fix hanging issue ([#799](https://github.com/supabase/supabase-flutter/issues/799)). ([7fc3ed0b](https://github.com/supabase/supabase-flutter/commit/7fc3ed0bfc14335e3a87b60edc25ba6edbfce6ab))
 - **FEAT**(gotrue,supabase_flutter): Add `signInWithSSO` method ([#798](https://github.com/supabase/supabase-flutter/issues/798)). ([87c16327](https://github.com/supabase/supabase-flutter/commit/87c163279866ac9d44756fd7d5faf01d48860fb0))


## 2024-01-09

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v2.3.0`](#gotrue---v230)
 - [`supabase_flutter` - `v2.2.0`](#supabase_flutter---v220)
 - [`supabase` - `v2.0.4`](#supabase---v204)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.0.4`

---

#### `gotrue` - `v2.3.0`

 - **FEAT**: Add linkedin_oidc OAuthProvider ([#791](https://github.com/supabase/supabase-flutter/issues/791)). ([09664281](https://github.com/supabase/supabase-flutter/commit/0966428189817d3f4ff3a9101ed2402a4fe2f001))

#### `supabase_flutter` - `v2.2.0`

 - **FEAT**(supabase_flutter): Update app_link to v3.5.0, to add Linux support for deep links ([#792](https://github.com/supabase/supabase-flutter/issues/792)). ([5ad7a674](https://github.com/supabase/supabase-flutter/commit/5ad7a674a22033ac0f792fba8ba3e7fed721190e))


## 2024-01-03

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v2.2.0`](#gotrue---v220)
 - [`postgrest` - `v2.1.0`](#postgrest---v210)
 - [`supabase_flutter` - `v2.1.0`](#supabase_flutter---v210)
 - [`supabase` - `v2.0.3`](#supabase---v203)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.0.3`

---

#### `gotrue` - `v2.2.0`

 - **FIX**(gotrue): Fix the issue where `verfiyOTP` emits `signIn` instead of `passwordRecovery` auth event. ([#774](https://github.com/supabase/supabase-flutter/issues/774)). ([fc426134](https://github.com/supabase/supabase-flutter/commit/fc426134fff8cb6ab34ea7e7633e29c90cafaa43))
 - **FEAT**(gotrue,supabase_flutter): Add identity linking and unlinking methods. ([#760](https://github.com/supabase/supabase-flutter/issues/760)). ([6c0c922d](https://github.com/supabase/supabase-flutter/commit/6c0c922df6097a6ef5a43b801fbd45900118bd7a))

#### `postgrest` - `v2.1.0`

 - **FIX**: Passing `null` to `not()` filter is now allowed ([#775](https://github.com/supabase/supabase-flutter/issues/775)). ([13f02286](https://github.com/supabase/supabase-flutter/commit/13f02286dc2d6fd1c1a30099bf540c436951f9a4))
 - **FEAT**(postgrest): Add `toJson()` method to `PostgrestException` to allow serialization ([#783](https://github.com/supabase/supabase-flutter/issues/783)). ([28c9819a](https://github.com/supabase/supabase-flutter/commit/28c9819a1af715d2711a896d6f9694a19dc24120))

#### `supabase_flutter` - `v2.1.0`

 - **FIX**: Update Provider to OAuthProvider in readme ([#778](https://github.com/supabase/supabase-flutter/issues/778)). ([0585ee96](https://github.com/supabase/supabase-flutter/commit/0585ee960c7dbd1b232fe84a169daf8b3f37170c))
 - **FEAT**(gotrue,supabase_flutter): Add identity linking and unlinking methods. ([#760](https://github.com/supabase/supabase-flutter/issues/760)). ([6c0c922d](https://github.com/supabase/supabase-flutter/commit/6c0c922df6097a6ef5a43b801fbd45900118bd7a))


## 2023-12-19

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`postgrest` - `v2.0.1`](#postgrest---v201)
 - [`supabase` - `v2.0.2`](#supabase---v202)
 - [`supabase_flutter` - `v2.0.2`](#supabase_flutter---v202)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.0.2`
 - `supabase_flutter` - `v2.0.2`

---

#### `postgrest` - `v2.0.1`

 - **FIX**: enable filtering and tranformation on count with head ([#768](https://github.com/supabase/supabase-flutter/issues/768)). ([d66aaab6](https://github.com/supabase/supabase-flutter/commit/d66aaab66e5b0d437da4f49b6cdc2168dacf5582))


## 2023-12-14

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v2.1.0`](#gotrue---v210)
 - [`supabase` - `v2.0.1`](#supabase---v201)
 - [`supabase_flutter` - `v2.0.1`](#supabase_flutter---v201)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.0.1`

---

#### `gotrue` - `v2.1.0`

 - **FEAT**: add getUser() method. ([62dcb8c6](https://github.com/supabase/supabase-flutter/commit/62dcb8c6d818e91559699c70befdfbdc63ad2d2f))

#### `supabase_flutter` - `v2.0.1`

 - **FIX**: fix(supabase_flutter): export signInWithOAuth() and generateRawNonce() ([#763](https://github.com/supabase/supabase-flutter/pull/763))

## 2023-12-13

### Changes

---

Packages with breaking changes:

 - [`functions_client` - `v2.0.0`](#functions_client---v200)
 - [`gotrue` - `v2.0.0`](#gotrue---v200)
 - [`postgrest` - `v2.0.0`](#postgrest---v200)
 - [`realtime_client` - `v2.0.0`](#realtime_client---v200)
 - [`storage_client` - `v2.0.0`](#storage_client---v200)
 - [`supabase` - `v2.0.0`](#supabase---v200)
 - [`supabase_flutter` - `v2.0.0`](#supabase_flutter---v200)
 - [`yet_another_json_isolate` - `v2.0.0`](#yet_another_json_isolate---v200)

Packages with other changes:

 - There are no other changes in this release.

Packages graduated to a stable release (see pre-releases prior to the stable version for changelog entries):

 - `functions_client` - `v2.0.0`
 - `gotrue` - `v2.0.0`
 - `postgrest` - `v2.0.0`
 - `realtime_client` - `v2.0.0`
 - `storage_client` - `v2.0.0`
 - `supabase` - `v2.0.0`
 - `supabase_flutter` - `v2.0.0`
 - `yet_another_json_isolate` - `v2.0.0`

---

#### `functions_client` - `v2.0.0`

#### `gotrue` - `v2.0.0`

#### `postgrest` - `v2.0.0`

#### `realtime_client` - `v2.0.0`

#### `storage_client` - `v2.0.0`

#### `supabase` - `v2.0.0`

#### `supabase_flutter` - `v2.0.0`

#### `yet_another_json_isolate` - `v2.0.0`


## 2023-12-05

### Changes

---

Packages with breaking changes:

 - [`realtime_client` - `v2.0.0-dev.3`](#realtime_client---v200-dev3)
 - [`postgrest` - `v2.0.0-dev.2`](#postgrest---v200-dev2)
 - [`supabase` - `v2.0.0-dev.4`](#supabase---v200-dev4)

Packages with other changes:

 - [`gotrue` - `v2.0.0-dev.2`](#gotrue---v200-dev2)
 - [`supabase_flutter` - `v2.0.0-dev.4`](#supabase_flutter---v200-dev4)

---

#### `gotrue` - `v2.0.0-dev.2`

 - **FIX**: PKCE flow not emitting password recovery event ([#744](https://github.com/supabase/supabase-flutter/issues/744)). ([65859bd2](https://github.com/supabase/supabase-flutter/commit/65859bd2676873c685397b4b37d2685bed18b5a1))
 - **FIX**: sign out on already used refresh token ([#740](https://github.com/supabase/supabase-flutter/issues/740)). ([72ffb9ee](https://github.com/supabase/supabase-flutter/commit/72ffb9ee1a1386fb7ab8085b68cd9bc6f6d72c78))
 - **FIX**(gotrue): signing in with pkce flow fires two `signedIn` auth event ([#734](https://github.com/supabase/supabase-flutter/issues/734)). ([6dee1660](https://github.com/supabase/supabase-flutter/commit/6dee1660024afcb926853ec77cd7da685dfa479b))
 - **FEAT**(gotrue): add Figma to  OAuth provider. ([#743](https://github.com/supabase/supabase-flutter/issues/743)). ([f5b72d47](https://github.com/supabase/supabase-flutter/commit/f5b72d47e7af4b62aa99f3e380557ef039b1e2d9))

#### `realtime_client` - `v2.0.0-dev.3`

- **BREAKING** **FEAT**(realtime_client): Introduce type safe realtime methods ([#725](https://github.com/supabase/supabase-flutter/pull/725)).
- **BREAKING** **FEAT**(realtime_client): Provide better typing for realtime presence. ([#747](https://github.com/supabase/supabase-flutter/pull/747)).

#### `supabase` - `v2.0.0-dev.4`

 - **FIX**: realtime ordering on double ([#741](https://github.com/supabase/supabase-flutter/issues/741)). ([f20faef7](https://github.com/supabase/supabase-flutter/commit/f20faef710e4e730590543ccd0a7bafd072be2ff))

#### `supabase_flutter` - `v2.0.0-dev.4`

 - **FIX**: PKCE flow not emitting password recovery event ([#744](https://github.com/supabase/supabase-flutter/issues/744)). ([65859bd2](https://github.com/supabase/supabase-flutter/commit/65859bd2676873c685397b4b37d2685bed18b5a1))
 - **FIX**: update sign in with Apple instruction on readme ([#746](https://github.com/supabase/supabase-flutter/issues/746)). ([a4897d06](https://github.com/supabase/supabase-flutter/commit/a4897d06684d38bb159721f8f308fcbde836095e))
 - **FIX**: use SharedPreferences on web ([#738](https://github.com/supabase/supabase-flutter/issues/738)). ([d0cc2015](https://github.com/supabase/supabase-flutter/commit/d0cc20153f23004f1ef2f821b0e9c6d9189f6b03))
 - **FIX**(supabase_flutter): session migration from hive to sharedPreferences now works properly ([#731](https://github.com/supabase/supabase-flutter/issues/731)). ([c81cf07f](https://github.com/supabase/supabase-flutter/commit/c81cf07f75be13916b8b90ccc1ded20f1ad4aec9))


## 2023-11-23

### Changes

---

Packages with breaking changes:

 - [`realtime_client` - `v2.0.0-dev.2`](#realtime_client---v200-dev2)

Packages with other changes:

 - [`postgrest` - `v2.0.0-dev.1`](#postgrest---v200-dev1)
 - [`supabase` - `v2.0.0-dev.3`](#supabase---v200-dev3)
 - [`supabase_flutter` - `v2.0.0-dev.3`](#supabase_flutter---v200-dev3)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `supabase` - `v2.0.0-dev.3`
 - `supabase_flutter` - `v2.0.0-dev.3`

---

#### `postgrest` - `v2.0.0-dev.1`

 - **FIX**: issue where `.range()` not respecting the offset given. ([#722](https://github.com/supabase/supabase-flutter/issues/722)). ([e3541a46](https://github.com/supabase/supabase-flutter/commit/e3541a46d026e069122634b7a6e84be5b9f1deaf))
 - **FEAT**: adds geojson support for working with the PostGIS extension ([#721](https://github.com/supabase/supabase-flutter/issues/721)). ([60a25153](https://github.com/supabase/supabase-flutter/commit/60a2515391ab0c5abb205888dfa25a1ed744814e))
 - **FEAT**: adds `.explain()` for debugging performance issues on Supabase client generated queries.  ([#719](https://github.com/supabase/supabase-flutter/issues/719)). ([f6e41578](https://github.com/supabase/supabase-flutter/commit/f6e41578895ce31542120bd6c937014e17c4e72d))

#### `realtime_client` - `v2.0.0-dev.2`

- **BREAKING** **REFACTOR**(realtime_client): make channel methods private and add @internal label ([#724](https://github.com/supabase/supabase-flutter/pull/724)).


## 2023-11-13

### Changes

---

- There are no breaking changes in this release.

Packages with other changes:

 - [`gotrue` - `v2.0.0-dev.1`](#gotrue---v200-dev1)
 - [`supabase_flutter` - `v2.0.0-dev.2`](#supabase_flutter---v200-dev2)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v2.0.0-dev.2`

---

#### `gotrue` - `v2.0.0-dev.1`

 - **FIX**(gotrue): allow empty session response for verifyOtp method ([#680](https://github.com/supabase/supabase-flutter/issues/680)). ([dc6146dc](https://github.com/supabase/supabase-flutter/commit/dc6146dc81e7daa80daacc7e4c4562b033a1b5e8))

#### `supabase_flutter` - `v2.0.0-dev.2`

 - **FIX**(supabase_flutter): The session is not restored when the application is started. ([#702](https://github.com/supabase/supabase-flutter/issues/702)). ([e1cc576c](https://github.com/supabase/supabase-flutter/commit/e1cc576c53d4f7f84f866e98a03222c1e85c5376))

## 2023-11-08

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`supabase_flutter` - `v1.10.25`](#supabase_flutter---v11025)

---

#### `supabase_flutter` - `v1.10.25`

 - Update native Google sign-in instructions on README

## 2023-10-30

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.12.6`](#gotrue---v1126)
- [`supabase` - `v1.11.11`](#supabase---v11111)
- [`supabase_flutter` - `v1.10.24`](#supabase_flutter---v11024)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v1.11.11`
- `supabase_flutter` - `v1.10.24`

---

#### `gotrue` - `v1.12.6`

- **FIX**(gotrue): allow empty session response for verifyOtp method ([#680](https://github.com/supabase/supabase-flutter/issues/680)). ([dc6146dc](https://github.com/supabase/supabase-flutter/commit/dc6146dc81e7daa80daacc7e4c4562b033a1b5e8))

## 2023-10-23

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`realtime_client` - `v2.0.0-dev.1`](#realtime_client---v200-dev1)
- [`supabase` - `v2.0.0-dev.1`](#supabase---v200-dev1)
- [`supabase_flutter` - `v2.0.0-dev.1`](#supabase_flutter---v200-dev1)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v2.0.0-dev.1`
- `supabase_flutter` - `v2.0.0-dev.1`

---

#### `realtime_client` - `v2.0.0-dev.1`

- fix: a bug that prevents SupabaseClient to be used in Dart Edge

## 2023-10-23

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.12.5`](#gotrue---v1125)
- [`postgrest` - `v1.5.2`](#postgrest---v152)
- [`realtime_client` - `v1.4.0`](#realtime_client---v140)
- [`storage_client` - `v1.5.4`](#storage_client---v154)
- [`supabase` - `v1.11.10`](#supabase---v11110)
- [`supabase_flutter` - `v1.10.23`](#supabase_flutter---v11023)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase_flutter` - `v1.10.23`

---

#### `gotrue` - `v1.12.5`

- **FIX**(gotrue): remove import of dart:io from gotrue_client.dart ([#659](https://github.com/supabase/supabase-flutter/issues/659)). ([7280b490](https://github.com/supabase/supabase-flutter/commit/7280b490f10a8de5c69509c5242aff98e348c162))
- **FIX**: compile with webdev ([#653](https://github.com/supabase/supabase-flutter/issues/653)). ([23242287](https://github.com/supabase/supabase-flutter/commit/232422874df7f09fcf76ab5879822741a7272245))
- **FIX**(gotrue,supabase): allow refreshSession after exception ([#633](https://github.com/supabase/supabase-flutter/issues/633)). ([8853155f](https://github.com/supabase/supabase-flutter/commit/8853155fdaaec984818323b35718cb1c4c3ede4c))

#### `postgrest` - `v1.5.2`

- **FIX**: don't try to decode an empty body ([#631](https://github.com/supabase/supabase-flutter/issues/631)). ([ec13c88f](https://github.com/supabase/supabase-flutter/commit/ec13c88f78f116d41c06a8f97e49a13d78b90172))

#### `realtime_client` - `v1.4.0`

- **FIX**: make Supabase client work in Dart Edge again ([#675](https://github.com/supabase/supabase-flutter/issues/675)). ([53530f22](https://github.com/supabase/supabase-flutter/commit/53530f222b1430debf40d0beb95f75f279d1830f))
- **FIX**: Remove error parameter on `_triggerChanError` ([#637](https://github.com/supabase/supabase-flutter/issues/637)). ([c4291c97](https://github.com/supabase/supabase-flutter/commit/c4291c97c87342cbd84795297c046b7ababef5ac))
- **FEAT**: send messages via broadcast endpoint ([#654](https://github.com/supabase/supabase-flutter/issues/654)). ([2ff950d7](https://github.com/supabase/supabase-flutter/commit/2ff950d7b228fd377ba0da2c45f4803d90b3368d))

#### `storage_client` - `v1.5.4`

- **FIX**: compile with webdev ([#653](https://github.com/supabase/supabase-flutter/issues/653)). ([23242287](https://github.com/supabase/supabase-flutter/commit/232422874df7f09fcf76ab5879822741a7272245))

#### `supabase` - `v1.11.10`

- **FIX**: make Supabase client work in Dart Edge again ([#675](https://github.com/supabase/supabase-flutter/issues/675)). ([53530f22](https://github.com/supabase/supabase-flutter/commit/53530f222b1430debf40d0beb95f75f279d1830f))
- **FIX**(gotrue,supabase): allow refreshSession after exception ([#633](https://github.com/supabase/supabase-flutter/issues/633)). ([8853155f](https://github.com/supabase/supabase-flutter/commit/8853155fdaaec984818323b35718cb1c4c3ede4c))

## 2023-10-18

### Changes

---

Packages with breaking changes:

- [`functions_client` - `v2.0.0-dev.0`](#functions_client---v200-dev0)
- [`gotrue` - `v2.0.0-dev.0`](#gotrue---v200-dev0)
- [`postgrest` - `v2.0.0-dev.0`](#postgrest---v200-dev0)
- [`realtime_client` - `v2.0.0-dev.0`](#realtime_client---v200-dev0)
- [`storage_client` - `v2.0.0-dev.0`](#storage_client---v200-dev0)
- [`supabase` - `v2.0.0-dev.0`](#supabase---v200-dev0)
- [`supabase_flutter` - `v2.0.0-dev.0`](#supabase_flutter---v200-dev0)
- [`yet_another_json_isolate` - `v2.0.0-dev.0`](#yet_another_json_isolate---v200-dev0)

Packages with other changes:

- There are no other changes in this release.

---

#### `functions_client` - `v2.0.0-dev.0`

- **FIX**(functions_client): use header for response parsing ([#616](https://github.com/supabase/supabase-flutter/issues/616)). ([e413acbb](https://github.com/supabase/supabase-flutter/commit/e413acbb6fc424ae419c569a47a023c41aa34b45))
- **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))
- **BREAKING** **FIX**: throw exception on non 2xx status ([#629](https://github.com/supabase/supabase-flutter/issues/629)). ([db5ec824](https://github.com/supabase/supabase-flutter/commit/db5ec824c625f7ba24bceccdb5b0de452ce45dca))
- **BREAKING** **FEAT**: use Object? instead of dynamic ([#606](https://github.com/supabase/supabase-flutter/issues/606)). ([0c6caa00](https://github.com/supabase/supabase-flutter/commit/0c6caa00912bc73fc220110bdd9f3d69aaecb3ac))

#### `gotrue` - `v2.0.0-dev.0`

- **FIX**: token refresh doesn't block on ClientException ([#660](https://github.com/supabase/supabase-flutter/issues/660)). ([a5ef8b71](https://github.com/supabase/supabase-flutter/commit/a5ef8b718edcb2e5e19ba8f99d899a17adaa368b))
- **FIX**(gotrue,supabase): allow refreshSession after exception ([#633](https://github.com/supabase/supabase-flutter/issues/633)). ([8853155f](https://github.com/supabase/supabase-flutter/commit/8853155fdaaec984818323b35718cb1c4c3ede4c))
- **FEAT**(supabase_flutter): use SharedPreferences for access token ([#608](https://github.com/supabase/supabase-flutter/issues/608)). ([9d72a59d](https://github.com/supabase/supabase-flutter/commit/9d72a59d90434fa30dd3fe1b5f2cea42701eef2d))
- **BREAKING** **REFACTOR**: many auth breaking changes ([#636](https://github.com/supabase/supabase-flutter/issues/636)). ([7782a587](https://github.com/supabase/supabase-flutter/commit/7782a58768e2e05b15510566dd171eac75331ac1))
- **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))

#### `postgrest` - `v2.0.0-dev.0`

- **FIX**: don't try to decode an empty body ([#631](https://github.com/supabase/supabase-flutter/issues/631)). ([ec13c88f](https://github.com/supabase/supabase-flutter/commit/ec13c88f78f116d41c06a8f97e49a13d78b90172))
- **FEAT**(postgrest): immutability ([#600](https://github.com/supabase/supabase-flutter/issues/600)). ([95256697](https://github.com/supabase/supabase-flutter/commit/952566979dfae1e76ff9bac08354a729c0bd9514))
- **DOCS**: update readme to v2 ([#647](https://github.com/supabase/supabase-flutter/issues/647)). ([514cefb4](https://github.com/supabase/supabase-flutter/commit/514cefb40afe65da17de6f54d7884e1a897aa22b))
- **BREAKING** **REFACTOR**: rename is* and in* to isFilter and inFilter ([#646](https://github.com/supabase/supabase-flutter/issues/646)). ([1227394e](https://github.com/supabase/supabase-flutter/commit/1227394ed41913907d10bcafe59e3dbcea62e9e4))
- **BREAKING** **REFACTOR**: many auth breaking changes ([#636](https://github.com/supabase/supabase-flutter/issues/636)). ([7782a587](https://github.com/supabase/supabase-flutter/commit/7782a58768e2e05b15510566dd171eac75331ac1))
- **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))
- **BREAKING** **FEAT**(postgrest): stronger type system for query building ([#624](https://github.com/supabase/supabase-flutter/issues/624)). ([951ce89e](https://github.com/supabase/supabase-flutter/commit/951ce89eced66afe88b6c406226823e1f7ced58e))
- **BREAKING** **FEAT**: use Object? instead of dynamic ([#606](https://github.com/supabase/supabase-flutter/issues/606)). ([0c6caa00](https://github.com/supabase/supabase-flutter/commit/0c6caa00912bc73fc220110bdd9f3d69aaecb3ac))

#### `realtime_client` - `v2.0.0-dev.0`

- **FIX**: Remove error parameter on `_triggerChanError` ([#637](https://github.com/supabase/supabase-flutter/issues/637)). ([c4291c97](https://github.com/supabase/supabase-flutter/commit/c4291c97c87342cbd84795297c046b7ababef5ac))
- **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))

#### `storage_client` - `v2.0.0-dev.0`

- **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))

#### `supabase` - `v2.0.0-dev.0`

- **FIX**: stream with a different schema ([#661](https://github.com/supabase/supabase-flutter/issues/661)). ([c8fc2482](https://github.com/supabase/supabase-flutter/commit/c8fc24828d4f36fed64453a53d1bb5b4ff918d32))
- **FIX**(gotrue,supabase): allow refreshSession after exception ([#633](https://github.com/supabase/supabase-flutter/issues/633)). ([8853155f](https://github.com/supabase/supabase-flutter/commit/8853155fdaaec984818323b35718cb1c4c3ede4c))
- **FEAT**(supabase_flutter): use SharedPreferences for access token ([#608](https://github.com/supabase/supabase-flutter/issues/608)). ([9d72a59d](https://github.com/supabase/supabase-flutter/commit/9d72a59d90434fa30dd3fe1b5f2cea42701eef2d))
- **FEAT**(postgrest): immutability ([#600](https://github.com/supabase/supabase-flutter/issues/600)). ([95256697](https://github.com/supabase/supabase-flutter/commit/952566979dfae1e76ff9bac08354a729c0bd9514))
- **DOCS**: update readme to v2 ([#647](https://github.com/supabase/supabase-flutter/issues/647)). ([514cefb4](https://github.com/supabase/supabase-flutter/commit/514cefb40afe65da17de6f54d7884e1a897aa22b))
- **BREAKING** **REFACTOR**: rename is* and in* to isFilter and inFilter ([#646](https://github.com/supabase/supabase-flutter/issues/646)). ([1227394e](https://github.com/supabase/supabase-flutter/commit/1227394ed41913907d10bcafe59e3dbcea62e9e4))
- **BREAKING** **REFACTOR**: create package specific configs ([#640](https://github.com/supabase/supabase-flutter/issues/640)). ([53cd3e09](https://github.com/supabase/supabase-flutter/commit/53cd3e0994d09c9818ab1aeac165522e5d80f04b))
- **BREAKING** **REFACTOR**: many auth breaking changes ([#636](https://github.com/supabase/supabase-flutter/issues/636)). ([7782a587](https://github.com/supabase/supabase-flutter/commit/7782a58768e2e05b15510566dd171eac75331ac1))
- **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))
- **BREAKING** **FIX**(supabase): make Supabase credentials private in `SupabaseClient` ([#649](https://github.com/supabase/supabase-flutter/issues/649)). ([fa341bfe](https://github.com/supabase/supabase-flutter/commit/fa341bfee883526a994bd61893aaba19bd521496))
- **BREAKING** **FEAT**(postgrest): stronger type system for query building ([#624](https://github.com/supabase/supabase-flutter/issues/624)). ([951ce89e](https://github.com/supabase/supabase-flutter/commit/951ce89eced66afe88b6c406226823e1f7ced58e))
- **BREAKING** **FEAT**: use Object? instead of dynamic ([#606](https://github.com/supabase/supabase-flutter/issues/606)). ([0c6caa00](https://github.com/supabase/supabase-flutter/commit/0c6caa00912bc73fc220110bdd9f3d69aaecb3ac))

#### `supabase_flutter` - `v2.0.0-dev.0`

- **FEAT**(supabase_flutter): use SharedPreferences for access token ([#608](https://github.com/supabase/supabase-flutter/issues/608)). ([9d72a59d](https://github.com/supabase/supabase-flutter/commit/9d72a59d90434fa30dd3fe1b5f2cea42701eef2d))
- **DOCS**: update readme to v2 ([#647](https://github.com/supabase/supabase-flutter/issues/647)). ([514cefb4](https://github.com/supabase/supabase-flutter/commit/514cefb40afe65da17de6f54d7884e1a897aa22b))
- **BREAKING** **REFACTOR**: remove `signInWithApple` method and make `generateRawNonce` public ([#650](https://github.com/supabase/supabase-flutter/issues/650)). ([2f9fe41f](https://github.com/supabase/supabase-flutter/commit/2f9fe41fd71464e6345470097ac4e61cd367fa83))
- **BREAKING** **REFACTOR**: create package specific configs ([#640](https://github.com/supabase/supabase-flutter/issues/640)). ([53cd3e09](https://github.com/supabase/supabase-flutter/commit/53cd3e0994d09c9818ab1aeac165522e5d80f04b))
- **BREAKING** **REFACTOR**: many auth breaking changes ([#636](https://github.com/supabase/supabase-flutter/issues/636)). ([7782a587](https://github.com/supabase/supabase-flutter/commit/7782a58768e2e05b15510566dd171eac75331ac1))
- **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))

#### `yet_another_json_isolate` - `v2.0.0-dev.0`

- **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))

## 2023-10-09

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.12.4`](#gotrue---v1124)
- [`supabase` - `v1.11.9`](#supabase---v1119)
- [`supabase_flutter` - `v1.10.22`](#supabase_flutter---v11022)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v1.11.9`
- `supabase_flutter` - `v1.10.22`

---

#### `gotrue` - `v1.12.4`

- **FIX**(gotrue): remove import of dart:io from gotrue_client.dart ([#659](https://github.com/supabase/supabase-flutter/issues/659)). ([7280b490](https://github.com/supabase/supabase-flutter/commit/7280b490f10a8de5c69509c5242aff98e348c162))

## 2023-10-05

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.12.3`](#gotrue---v1123)
- [`storage_client` - `v1.5.3`](#storage_client---v153)
- [`supabase` - `v1.11.8`](#supabase---v1118)
- [`supabase_flutter` - `v1.10.21`](#supabase_flutter---v11021)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v1.11.8`
- `supabase_flutter` - `v1.10.21`

---

#### `gotrue` - `v1.12.3`

- **FIX**: compile with webdev ([#653](https://github.com/supabase/supabase-flutter/issues/653)). ([23242287](https://github.com/supabase/supabase-flutter/commit/232422874df7f09fcf76ab5879822741a7272245))

#### `storage_client` - `v1.5.3`

- **FIX**: compile with webdev ([#653](https://github.com/supabase/supabase-flutter/issues/653)). ([23242287](https://github.com/supabase/supabase-flutter/commit/232422874df7f09fcf76ab5879822741a7272245))

## 2023-10-05

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`realtime_client` - `v1.3.0`](#realtime_client---v130)
- [`supabase` - `v1.11.7`](#supabase---v1117)
- [`supabase_flutter` - `v1.10.20`](#supabase_flutter---v11020)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v1.11.7`
- `supabase_flutter` - `v1.10.20`

---

#### `realtime_client` - `v1.3.0`

- **FEAT**: send messages via broadcast endpoint ([#654](https://github.com/supabase/supabase-flutter/issues/654)). ([2ff950d7](https://github.com/supabase/supabase-flutter/commit/2ff950d7b228fd377ba0da2c45f4803d90b3368d))

## 2023-09-25

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`realtime_client` - `v1.2.3`](#realtime_client---v123)
- [`supabase` - `v1.11.6`](#supabase---v1116)
- [`supabase_flutter` - `v1.10.19`](#supabase_flutter---v11019)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v1.11.6`
- `supabase_flutter` - `v1.10.19`

---

#### `realtime_client` - `v1.2.3`

- **FIX**: Remove error parameter on `_triggerChanError` ([#637](https://github.com/supabase/supabase-flutter/issues/637)). ([c4291c97](https://github.com/supabase/supabase-flutter/commit/c4291c97c87342cbd84795297c046b7ababef5ac))

## 2023-09-19

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.12.2`](#gotrue---v1122)
- [`postgrest` - `v1.5.1`](#postgrest---v151)
- [`supabase` - `v1.11.5`](#supabase---v1115)
- [`supabase_flutter` - `v1.10.18`](#supabase_flutter---v11018)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase_flutter` - `v1.10.18`

---

#### `gotrue` - `v1.12.2`

- **FIX**(gotrue,supabase): allow refreshSession after exception ([#633](https://github.com/supabase/supabase-flutter/issues/633)). ([8853155f](https://github.com/supabase/supabase-flutter/commit/8853155fdaaec984818323b35718cb1c4c3ede4c))

#### `postgrest` - `v1.5.1`

- **FIX**: don't try to decode an empty body ([#631](https://github.com/supabase/supabase-flutter/issues/631)). ([ec13c88f](https://github.com/supabase/supabase-flutter/commit/ec13c88f78f116d41c06a8f97e49a13d78b90172))

#### `supabase` - `v1.11.5`

- **FIX**(gotrue,supabase): allow refreshSession after exception ([#633](https://github.com/supabase/supabase-flutter/issues/633)). ([8853155f](https://github.com/supabase/supabase-flutter/commit/8853155fdaaec984818323b35718cb1c4c3ede4c))

## 2023-09-10

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`realtime_client` - `v1.2.2`](#realtime_client---v122)
- [`supabase` - `v1.11.4`](#supabase---v1114)
- [`supabase_flutter` - `v1.10.17`](#supabase_flutter---v11017)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v1.11.4`
- `supabase_flutter` - `v1.10.17`

---

#### `realtime_client` - `v1.2.2`

- **FIX**(realtime_client): No exception is thrown when connection is closed. ([#620](https://github.com/supabase/supabase-flutter/issues/620)). ([64b8b968](https://github.com/supabase/supabase-flutter/commit/64b8b9689d089c056e1f1665df749aa21b893aad))

## 2023-09-05

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.12.1`](#gotrue---v1121)
- [`supabase` - `v1.11.3`](#supabase---v1113)
- [`supabase_flutter` - `v1.10.16`](#supabase_flutter---v11016)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v1.11.3`
- `supabase_flutter` - `v1.10.16`

---

#### `gotrue` - `v1.12.1`

- **FIX**(gotrue): export everything in constants.dart and hide what we want to hide instead of using show ([#617](https://github.com/supabase/supabase-flutter/issues/617)). ([24df174f](https://github.com/supabase/supabase-flutter/commit/24df174fb952a824692f33cb714e4f913c5866f5))

## 2023-09-04

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.12.0`](#gotrue---v1120)
- [`storage_client` - `v1.5.2`](#storage_client---v152)
- [`supabase` - `v1.11.2`](#supabase---v1112)
- [`supabase_flutter` - `v1.10.15`](#supabase_flutter---v11015)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v1.11.2`
- `supabase_flutter` - `v1.10.15`

---

#### `gotrue` - `v1.12.0`

- **FEAT**(gotrue): add WhatsApp support for OTP login ([#613](https://github.com/supabase/supabase-flutter/issues/613)). ([40da5be2](https://github.com/supabase/supabase-flutter/commit/40da5be2d8c883f591b71493749367c1e9de4d43))

#### `storage_client` - `v1.5.2`

- **FIX**(storage_client): prevent the SDK from throwing when null path was returned from calling `createSignedUrls()` ([#599](https://github.com/supabase/supabase-flutter/issues/599)). ([e25a70d6](https://github.com/supabase/supabase-flutter/commit/e25a70d67aeaa8844a0a8dca8385a3637b4ffd42))

## 2023-08-22

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`realtime_client` - `v1.2.1`](#realtime_client---v121)
- [`supabase` - `v1.11.1`](#supabase---v1111)
- [`supabase_flutter` - `v1.10.14`](#supabase_flutter---v11014)

---

#### `realtime_client` - `v1.2.1`

- **FIX**(realtime_client,supabase): pass apikey as the initial access token for realtime client ([#596](https://github.com/supabase/supabase-flutter/issues/596)). ([af8e368b](https://github.com/supabase/supabase-flutter/commit/af8e368bdb0b2a07f9cf9806c854456f8e9d198e))

#### `supabase` - `v1.11.1`

- **FIX**(realtime_client,supabase): pass apikey as the initial access token for realtime client ([#596](https://github.com/supabase/supabase-flutter/issues/596)). ([af8e368b](https://github.com/supabase/supabase-flutter/commit/af8e368bdb0b2a07f9cf9806c854456f8e9d198e))

#### `supabase_flutter` - `v1.10.14`

- **FIX**(realtime_client,supabase): pass apikey as the initial access token for realtime client ([#596](https://github.com/supabase/supabase-flutter/issues/596)). ([af8e368b](https://github.com/supabase/supabase-flutter/commit/af8e368bdb0b2a07f9cf9806c854456f8e9d198e))

## 2023-08-15

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`realtime_client` - `v1.2.0`](#realtime_client---v120)
- [`supabase` - `v1.11.0`](#supabase---v1110)
- [`supabase_flutter` - `v1.10.13`](#supabase_flutter---v11013)

---

#### `realtime_client` - `v1.2.0`

- **FEAT**: add `logLevel` parameter to `RealtimeClientOptions` ([#592](https://github.com/supabase/supabase-flutter/issues/592)). ([76e9fc20](https://github.com/supabase/supabase-flutter/commit/76e9fc2067cc36e67c7bbaaed1fcad6281426f82))

#### `supabase` - `v1.11.0`

- **FEAT**: add `logLevel` parameter to `RealtimeClientOptions` ([#592](https://github.com/supabase/supabase-flutter/issues/592)). ([76e9fc20](https://github.com/supabase/supabase-flutter/commit/76e9fc2067cc36e67c7bbaaed1fcad6281426f82))

#### `supabase_flutter` - `v1.10.13`

- **FIX**(supabase_flutter): update readme.md on the notes about broadcast ([#589](https://github.com/supabase/supabase-flutter/issues/589)). ([d0f4e2dd](https://github.com/supabase/supabase-flutter/commit/d0f4e2dd8e6b6eeb550c164cf19cb2c8a6cb50ba))

## 2023-08-09

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`postgrest` - `v1.5.0`](#postgrest---v150)
- [`supabase` - `v1.10.0`](#supabase---v1100)
- [`supabase_flutter` - `v1.10.12`](#supabase_flutter---v11012)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase_flutter` - `v1.10.12`

---

#### `postgrest` - `v1.5.0`

- **FEAT**(postgrest,supabase): add `useSchema()` method for making rest API calls on custom schema. ([#525](https://github.com/supabase/supabase-flutter/issues/525)). ([40a0f090](https://github.com/supabase/supabase-flutter/commit/40a0f09078bface9cb51cb0f7fe7bd6e1032b99b))

#### `supabase` - `v1.10.0`

- **FEAT**(postgrest,supabase): add `useSchema()` method for making rest API calls on custom schema. ([#525](https://github.com/supabase/supabase-flutter/issues/525)). ([40a0f090](https://github.com/supabase/supabase-flutter/commit/40a0f09078bface9cb51cb0f7fe7bd6e1032b99b))

## 2023-08-01

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.11.2`](#gotrue---v1112)
- [`realtime_client` - `v1.1.3`](#realtime_client---v113)
- [`supabase` - `v1.9.9`](#supabase---v199)
- [`supabase_flutter` - `v1.10.11`](#supabase_flutter---v11011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v1.9.9`
- `supabase_flutter` - `v1.10.11`

---

#### `gotrue` - `v1.11.2`

- **FIX**(gotrue): export SignOutScope ([#576](https://github.com/supabase/supabase-flutter/issues/576)). ([2bd6e459](https://github.com/supabase/supabase-flutter/commit/2bd6e4599dc3ebb11ffb0deaef19095574d4b93d))

#### `realtime_client` - `v1.1.3`

- **FIX**: Add join_ref, comment docs and @internal annotations. ([#570](https://github.com/supabase/supabase-flutter/issues/570)). ([a28de337](https://github.com/supabase/supabase-flutter/commit/a28de3377cd5dcd1e176ffbe7de68bf23cd50cfd))

## 2023-07-25

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.11.1`](#gotrue---v1111)
- [`postgrest` - `v1.4.0`](#postgrest---v140)
- [`realtime_client` - `v1.1.2`](#realtime_client---v112)
- [`supabase` - `v1.9.8`](#supabase---v198)
- [`supabase_flutter` - `v1.10.10`](#supabase_flutter---v11010)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase_flutter` - `v1.10.10`

---

#### `gotrue` - `v1.11.1`

- **FIX**(supabase): get jwt on http call ([#540](https://github.com/supabase/supabase-flutter/issues/540)). ([e044d3ca](https://github.com/supabase/supabase-flutter/commit/e044d3caa2a0085804b7b4f39b050d25ab949083))
- **FIX**(gotrue): remove OtpType deprecation and add assertion to check type for resend method ([#567](https://github.com/supabase/supabase-flutter/issues/567)). ([d4509de3](https://github.com/supabase/supabase-flutter/commit/d4509de3065c611920b1b2a59d83b04b1727416d))

#### `postgrest` - `v1.4.0`

- **FIX**: `maybeSingle` no longer logs error on Postgrest API ([#564](https://github.com/supabase/supabase-flutter/issues/564)). ([f6854e1d](https://github.com/supabase/supabase-flutter/commit/f6854e1d73cee7d0352f8c05697dde8ad94441f3))
- **FEAT**(postgrest): updates for postgREST 11 ([#550](https://github.com/supabase/supabase-flutter/issues/550)). ([64d8eb59](https://github.com/supabase/supabase-flutter/commit/64d8eb592578fe5e62840dd01396459a7d5096c6))

#### `realtime_client` - `v1.1.2`

- **FIX**(realtime_client): correct channel error data ([#566](https://github.com/supabase/supabase-flutter/issues/566)). ([7fbd94c6](https://github.com/supabase/supabase-flutter/commit/7fbd94c6282bdae50f28b8277d56db23ec49aa58))
- **FIX**(realtime): use access token from headers ([#558](https://github.com/supabase/supabase-flutter/issues/558)). ([b46bf0f0](https://github.com/supabase/supabase-flutter/commit/b46bf0f0254176ded35345f7144641c7ba327b9e))

#### `supabase` - `v1.9.8`

- **FIX**(supabase): get jwt on http call ([#540](https://github.com/supabase/supabase-flutter/issues/540)). ([e044d3ca](https://github.com/supabase/supabase-flutter/commit/e044d3caa2a0085804b7b4f39b050d25ab949083))

## 2023-07-13

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`supabase_flutter` - `v1.10.9`](#supabase_flutter---v1109)

---

#### `supabase_flutter` - `v1.10.9`

- **FIX**(supabase_flutter): update sign_in_with_apple version constraints to allow v5.0.0 ([#548](https://github.com/supabase/supabase-flutter/issues/548)). ([bc977431](https://github.com/supabase/supabase-flutter/commit/bc9774319a578c96d43eea121b7dca319d63a749))

## 2023-07-12

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.11.0`](#gotrue---v1110)
- [`postgrest` - `v1.3.3`](#postgrest---v133)
- [`supabase_flutter` - `v1.10.8`](#supabase_flutter---v1108)
- [`supabase` - `v1.9.7`](#supabase---v197)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v1.9.7`

---

#### `gotrue` - `v1.11.0`

- **FEAT**(gotrue): add reauthenticate and resend method ([#517](https://github.com/supabase/supabase-flutter/issues/517)). ([35a924b9](https://github.com/supabase/supabase-flutter/commit/35a924b9d131230102f105247ec6d4aa2aff2ddc))

#### `postgrest` - `v1.3.3`

- **FIX**(postgrest): update docs to mention views ([#543](https://github.com/supabase/supabase-flutter/issues/543)). ([22eb68f2](https://github.com/supabase/supabase-flutter/commit/22eb68f2b0b1b59ea955bd7394cd63de95cee1c6))

#### `supabase_flutter` - `v1.10.8`

- **FIX**: update the google auth setup instruction to use reversed client ID ([#542](https://github.com/supabase/supabase-flutter/issues/542)). ([fa52378a](https://github.com/supabase/supabase-flutter/commit/fa52378aadc7ad23c422b1c5b515743b814bea7d))

## 2023-07-05

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.10.0`](#gotrue---v1100)
- [`supabase_flutter` - `v1.10.7`](#supabase_flutter---v1107)
- [`supabase` - `v1.9.6`](#supabase---v196)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v1.9.6`

---

#### `gotrue` - `v1.10.0`

- **REFACTOR**(gotrue): add email otptype ([#534](https://github.com/supabase/supabase-flutter/issues/534)). ([b5fe3d32](https://github.com/supabase/supabase-flutter/commit/b5fe3d326d692b9ee4a8fd43fd21e1f25ef32505))
- **FIX**(gotrue): add pkce to signup ([#533](https://github.com/supabase/supabase-flutter/issues/533)). ([5b3308a4](https://github.com/supabase/supabase-flutter/commit/5b3308a45fefd24f5a8181e45cd6cc948dca32db))
- **FEAT**(gotrue): add scope to signOut ([#530](https://github.com/supabase/supabase-flutter/issues/530)). ([94a1cceb](https://github.com/supabase/supabase-flutter/commit/94a1cceb99614cfe84fd3cb8d921ff470e18f43d))

#### `supabase_flutter` - `v1.10.7`

- **FIX**(supabase_flutter): update README.md with additional imports and code to enable Google sign in ([#531](https://github.com/supabase/supabase-flutter/issues/531)). ([de2628fa](https://github.com/supabase/supabase-flutter/commit/de2628fa9d6b6e99871a9dcc7dfc4d4a08182dcb))

## 2023-06-28

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`supabase_flutter` - `v1.10.6`](#supabase_flutter---v1106)

---

#### `supabase_flutter` - `v1.10.6`

- update README.md to include native auth instructions

## 2023-06-27

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.9.0`](#gotrue---v190)
- [`supabase` - `v1.9.5`](#supabase---v195)
- [`supabase_flutter` - `v1.10.5`](#supabase_flutter---v1105)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v1.9.5`
- `supabase_flutter` - `v1.10.5`

---

#### `gotrue` - `v1.9.0`

- **FEAT**(gotrue): add accessToken to `signInWithIdToken` method ([#520](https://github.com/supabase/supabase-flutter/issues/520)). ([4dcd5968](https://github.com/supabase/supabase-flutter/commit/4dcd5968bc57e711d6296377fe3374aea27bf3fc))

## 2023-06-19

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.8.4`](#gotrue---v184)
- [`supabase` - `v1.9.4`](#supabase---v194)
- [`supabase_flutter` - `v1.10.4`](#supabase_flutter---v1104)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase` - `v1.9.4`
- `supabase_flutter` - `v1.10.4`

---

#### `gotrue` - `v1.8.4`

- **FIX**(gotrue): Add missing members on `User` json serialization ([#512](https://github.com/supabase/supabase-flutter/issues/512)). ([70cc835b](https://github.com/supabase/supabase-flutter/commit/70cc835ba5851d8df0cc92312c70869d520aa851))
- **FIX**(gotrue): only remove session in otp verification if it's not email change or phone change ([#514](https://github.com/supabase/supabase-flutter/issues/514)). ([23bed82c](https://github.com/supabase/supabase-flutter/commit/23bed82cf2616488f96956ca764ffbc5cbebadd0))

## 2023-06-12

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`functions_client` - `v1.3.2`](#functions_client---v132)
- [`gotrue` - `v1.8.3`](#gotrue---v183)
- [`postgrest` - `v1.3.2`](#postgrest---v132)
- [`realtime_client` - `v1.1.1`](#realtime_client---v111)
- [`storage_client` - `v1.5.1`](#storage_client---v151)
- [`supabase` - `v1.9.3`](#supabase---v193)
- [`yet_another_json_isolate` - `v1.1.1`](#yet_another_json_isolate---v111)
- [`supabase_flutter` - `v1.10.3`](#supabase_flutter---v1103)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase_flutter` - `v1.10.3`

---

#### `functions_client` - `v1.3.2`

- **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

#### `gotrue` - `v1.8.3`

- **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

#### `postgrest` - `v1.3.2`

- **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

#### `realtime_client` - `v1.1.1`

- **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))
- **REFACTOR**(realtime_client): Add docs on `.subscribe()` and give callback parameters names ([#507](https://github.com/supabase/supabase-flutter/issues/507)). ([7f9b310e](https://github.com/supabase/supabase-flutter/commit/7f9b310ea1ad643faf81dcb33add806dc21ba031))

#### `storage_client` - `v1.5.1`

- **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

#### `supabase` - `v1.9.3`

- **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))
- **FIX**(supabase): add stackTrace on stream exception ([#509](https://github.com/supabase/supabase-flutter/issues/509)). ([c8c3ace2](https://github.com/supabase/supabase-flutter/commit/c8c3ace2b70a2a789eb87dd2ca3437f5d98fd0f3))
- **FIX**: Add errors from `.subscribe()` to `.stream()` streamController ([#506](https://github.com/supabase/supabase-flutter/issues/506)). ([a4cb4c53](https://github.com/supabase/supabase-flutter/commit/a4cb4c530330bf03aa37ae2521e6b6d2f3b96fbf))

#### `yet_another_json_isolate` - `v1.1.1`

- **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

## 2023-06-07

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`gotrue` - `v1.8.2`](#gotrue---v182)
- [`storage_client` - `v1.5.0`](#storage_client---v150)
- [`supabase` - `v1.9.2`](#supabase---v192)
- [`supabase_flutter` - `v1.10.2`](#supabase_flutter---v1102)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `supabase_flutter` - `v1.10.2`

---

#### `gotrue` - `v1.8.2`

- **FIX**(gotrue): catch some errors in signOut ([#501](https://github.com/supabase/supabase-flutter/issues/501)). ([03fa8be7](https://github.com/supabase/supabase-flutter/commit/03fa8be711b36274765bded9c44937da73684b71))

#### `storage_client` - `v1.5.0`

- **FEAT**(storage_client): upload signed URL ([#495](https://github.com/supabase/supabase-flutter/issues/495)). ([f330d19b](https://github.com/supabase/supabase-flutter/commit/f330d19b6c15aeb2748952164619e4486f2012ac))

#### `supabase` - `v1.9.2`

- **REFACTOR**(supabase): simplify functions url ([#496](https://github.com/supabase/supabase-flutter/issues/496)). ([21e9fc1b](https://github.com/supabase/supabase-flutter/commit/21e9fc1be2cd09f1626bc23de5b21f9a4b9609fe))

## 2023-05-29

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`functions_client` - `v1.3.1`](#functions_client---v131)
- [`gotrue` - `v1.8.1`](#gotrue---v181)
- [`postgrest` - `v1.3.1`](#postgrest---v131)
- [`storage_client` - `v1.4.1`](#storage_client---v141)
- [`supabase` - `v1.9.1`](#supabase---v191)
- [`supabase_flutter` - `v1.10.1`](#supabase_flutter---v1101)

---

#### `functions_client` - `v1.3.1`

- **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

#### `gotrue` - `v1.8.1`

- **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

#### `postgrest` - `v1.3.1`

- **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

#### `storage_client` - `v1.4.1`

- **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

#### `supabase` - `v1.9.1`

- **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))
- **DOCS**(supabase): update comment docs on stream ([#482](https://github.com/supabase/supabase-flutter/issues/482)). ([5de84c24](https://github.com/supabase/supabase-flutter/commit/5de84c246740ba94ec2b91688ed5a108df9c0c7f))

#### `supabase_flutter` - `v1.10.1`

- **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

## 2023-05-22

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`functions_client` - `v1.3.0`](#functions_client---v130)
- [`gotrue` - `v1.8.0`](#gotrue---v180)
- [`postgrest` - `v1.3.0`](#postgrest---v130)
- [`realtime_client` - `v1.1.0`](#realtime_client---v110)
- [`storage_client` - `v1.4.0`](#storage_client---v140)
- [`supabase` - `v1.9.0`](#supabase---v190)
- [`supabase_flutter` - `v1.10.0`](#supabase_flutter---v1100)
- [`yet_another_json_isolate` - `v1.1.0`](#yet_another_json_isolate---v110)

---

#### `functions_client` - `v1.3.0`

- **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

#### `gotrue` - `v1.8.0`

- **FIX**: reformat Provider type to be ordered alphabetically ([#471](https://github.com/supabase/supabase-flutter/issues/471)). ([c3a1dbb3](https://github.com/supabase/supabase-flutter/commit/c3a1dbb3974bcb7d95160d6412810c69122f2755))
- **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))
- **FEAT**: Add kakao provider enum type ([#470](https://github.com/supabase/supabase-flutter/issues/470)). ([9a1bb334](https://github.com/supabase/supabase-flutter/commit/9a1bb33453a08f3f74838b9624d4e7a709e60859))

#### `postgrest` - `v1.3.0`

- **FIX**(postgrest): Remove qoutations on foreign table transforms on 'or' ([#477](https://github.com/supabase/supabase-flutter/issues/477)). ([c2c6982a](https://github.com/supabase/supabase-flutter/commit/c2c6982a5f3343368c8721b0e80cb656dee10d60))
- **FIX**: Format the files to adjust to Flutter 3.10.1 ([#475](https://github.com/supabase/supabase-flutter/issues/475)). ([eb0bcd95](https://github.com/supabase/supabase-flutter/commit/eb0bcd954d1691a28a659dc367c4562c7f16b301))
- **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

#### `realtime_client` - `v1.1.0`

- **FIX**: Format the files to adjust to Flutter 3.10.1 ([#475](https://github.com/supabase/supabase-flutter/issues/475)). ([eb0bcd95](https://github.com/supabase/supabase-flutter/commit/eb0bcd954d1691a28a659dc367c4562c7f16b301))
- **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

#### `storage_client` - `v1.4.0`

- **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

#### `supabase` - `v1.9.0`

- **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

#### `supabase_flutter` - `v1.10.0`

- **FIX**: Format the files to adjust to Flutter 3.10.1 ([#475](https://github.com/supabase/supabase-flutter/issues/475)). ([eb0bcd95](https://github.com/supabase/supabase-flutter/commit/eb0bcd954d1691a28a659dc367c4562c7f16b301))
- **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

#### `yet_another_json_isolate` - `v1.1.0`

- **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

## 2023-05-16

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`supabase_flutter` - `v1.9.2`](#supabase_flutter---v192)

---

#### `supabase_flutter` - `v1.9.2`

- **FIX**(supabase_flutter): prevent Platform.environment use on web ([#468](https://github.com/supabase/supabase-flutter/issues/468)). ([de5a6300](https://github.com/supabase/supabase-flutter/commit/de5a6300d75f8951f1b75b73d8e6db5f31f581a1))

## 2023-05-11

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`functions_client` - `v1.2.1`](#functions_client---v121)
- [`gotrue` - `v1.7.1`](#gotrue---v171)
- [`postgrest` - `v1.2.4`](#postgrest---v124)
- [`realtime_client` - `v1.0.4`](#realtime_client---v104)
- [`storage_client` - `v1.3.1`](#storage_client---v131)
- [`supabase` - `v1.8.1`](#supabase---v181)
- [`supabase_flutter` - `v1.9.1`](#supabase_flutter---v191)
- [`yet_another_json_isolate` - `v1.0.4`](#yet_another_json_isolate---v104)

---

#### `functions_client` - `v1.2.1`

- chore: move the repo into supabase-flutter monorepo

#### `gotrue` - `v1.7.1`

- chore: move the repo into supabase-flutter monorepo

#### `postgrest` - `v1.2.4`

- chore: move the repo into supabase-flutter monorepo

#### `realtime_client` - `v1.0.4`

- chore: move the repo into supabase-flutter monorepo

#### `storage_client` - `v1.3.1`

- chore: move the repo into supabase-flutter monorepo

#### `supabase` - `v1.8.1`

- chore: move the repo into supabase-flutter monorepo

#### `supabase_flutter` - `v1.9.1`

- chore: update the repo to be a monorepo for all sub-libraries

#### `yet_another_json_isolate` - `v1.0.4`

- chore: move the repo into supabase-flutter monorepo
