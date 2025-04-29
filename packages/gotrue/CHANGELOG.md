## 2.12.0

 - Require Dart >=3.3.0
 - **FIX**: Dispose supabase client after flutter web hot-restart ([#1142](https://github.com/supabase/supabase-flutter/issues/1142)). ([ce582e3e](https://github.com/supabase/supabase-flutter/commit/ce582e3ee7e5d9922d5e38554dfe36a97a47d988))
 - **FIX**(gotrue): AuthException .toString method ([#1148](https://github.com/supabase/supabase-flutter/issues/1148)). ([42fdc910](https://github.com/supabase/supabase-flutter/commit/42fdc910e4e71904f99ecaa9b68778c1d8b50a62))
 - **FIX**(gotrue): Handle empty error response ([#1143](https://github.com/supabase/supabase-flutter/issues/1143)). ([591bb82f](https://github.com/supabase/supabase-flutter/commit/591bb82f3fe114b071be82832984c68551c1920d))
 - **FEAT**(gotrue,supabase,supabase_flutter,realtime_client): Use web package to access web APIs ([#1135](https://github.com/supabase/supabase-flutter/issues/1135)). ([dfa71c9a](https://github.com/supabase/supabase-flutter/commit/dfa71c9a308b9c51f037f379196ed6f6a9e78f18))

## 2.11.1

 - **FIX**: Ignore email and phone assertions when token hash is being verified ([#1097](https://github.com/supabase/supabase-flutter/issues/1097)). ([c9717861](https://github.com/supabase/supabase-flutter/commit/c97178610e8cd7a65a2f6a926ab559987e786d75))

## 2.11.0

 - **FIX**: Add equality to user attributes classes ([#1070](https://github.com/supabase/supabase-flutter/issues/1070)). ([7e7bc0ca](https://github.com/supabase/supabase-flutter/commit/7e7bc0cac722c0f3404b3f9320c536454bc51cea))
 - **FIX**: Updated gotrue types.dart to include slackOidc ([#1066](https://github.com/supabase/supabase-flutter/issues/1066)). ([12007b32](https://github.com/supabase/supabase-flutter/commit/12007b3206c15a87c373af46bc5f4a17aa646f62))
 - **FIX**: Send metadata inviteUserByEmail() ([#1061](https://github.com/supabase/supabase-flutter/issues/1061)). ([598540d2](https://github.com/supabase/supabase-flutter/commit/598540d2aac27d64e6be5d4a2e855d928f87fda6))
 - **FEAT**: Add Keycloak Provider on signInWithIdToken ([#1068](https://github.com/supabase/supabase-flutter/issues/1068)). ([be998fda](https://github.com/supabase/supabase-flutter/commit/be998fda6365bcf157dc96e3e4ea7009415045ee))

## 2.10.0

 - **FIX**: Rename logger from gotrue to auth ([#1055](https://github.com/supabase/supabase-flutter/issues/1055)). ([eea1ea6c](https://github.com/supabase/supabase-flutter/commit/eea1ea6c4e200e8ffc52d8343c0684c19670e3ed))
 - **FEAT**: Add logging ([#1042](https://github.com/supabase/supabase-flutter/issues/1042)). ([d1ecabd7](https://github.com/supabase/supabase-flutter/commit/d1ecabd77881a0488d2d4b41ea5ee5abda6c5c35))

## 2.9.0

 - **FIX**: Support all mfa auth methods ([#1030](https://github.com/supabase/supabase-flutter/issues/1030)). ([773b7de7](https://github.com/supabase/supabase-flutter/commit/773b7de74461ca3ea857d11b1abdfdf35fb540d4))
 - **FEAT**: Broadcast auth events to other tabs on web ([#1005](https://github.com/supabase/supabase-flutter/issues/1005)). ([8f473f1a](https://github.com/supabase/supabase-flutter/commit/8f473f1a99e0cbb9d570eb3fff0786ed5084351c))

## 2.8.4

 - **FIX**: Added missing error codes for AuthException ([#995](https://github.com/supabase/supabase-flutter/issues/995)). ([4e0270a0](https://github.com/supabase/supabase-flutter/commit/4e0270a069ecf5aae42031c77200d268519ac99b))
 - **FIX**: Upgrade `web_socket_channel` for supporting `web: ^1.0.0` and therefore WASM compilation on web ([#992](https://github.com/supabase/supabase-flutter/issues/992)). ([7da68565](https://github.com/supabase/supabase-flutter/commit/7da68565a7aa578305b099d7af755a7b0bcaca46))

## 2.8.3

 - **FIX**: Add error_code from url to AuthException ([#968](https://github.com/supabase/supabase-flutter/issues/968)). ([c741fe9d](https://github.com/supabase/supabase-flutter/commit/c741fe9d7458e7aaadf779a8d8f14636b4aeb136))
 - **FIX**: Add magiclink as authenticaiton method in mfa ([#967](https://github.com/supabase/supabase-flutter/issues/967)). ([4a871773](https://github.com/supabase/supabase-flutter/commit/4a87177389ad834febee20e9159e1ae1eb8be890))

## 2.8.2

 - **FIX**: Store actual error in AuthException ([#959](https://github.com/supabase/supabase-flutter/issues/959)). ([aa6c2183](https://github.com/supabase/supabase-flutter/commit/aa6c2183891118f775a013227790fc92e4de8a73))

## 2.8.1

 - **FIX**: Make token in verifyOtp nullable ([#950](https://github.com/supabase/supabase-flutter/issues/950)). ([0e69c58f](https://github.com/supabase/supabase-flutter/commit/0e69c58fab161c52c6f7a0127b3fb3f73f1995e4))

## 2.8.0

 - **FIX**(gotrue): Signing in does not remove the session unless the operation succeeds. ([#945](https://github.com/supabase/supabase-flutter/issues/945)). ([b2854c56](https://github.com/supabase/supabase-flutter/commit/b2854c564f0f5e7844302a2f7e63394fa4c6fc34))
 - **FEAT**: Add zoom as a OAuth provider ([#944](https://github.com/supabase/supabase-flutter/issues/944)). ([98718b13](https://github.com/supabase/supabase-flutter/commit/98718b13172b4008547a2e2c6304b04ffb932bdf))

## 2.7.0

 - **FEAT**(goture): Allow OAuthProvider.kakao for signInWithIdToken ([#922](https://github.com/supabase/supabase-flutter/issues/922)). ([e21db454](https://github.com/supabase/supabase-flutter/commit/e21db454003bbd960af634a01b9642c46284715e))

## 2.6.1

 - **FIX**: Add newEmail to admin generateLink method ([#904](https://github.com/supabase/supabase-flutter/issues/904)). ([5697e206](https://github.com/supabase/supabase-flutter/commit/5697e2060de1596626026a0f9ffd846435a6967a))
 - **FIX**: Weak password throws `AuthWeakPasswordException`. ([#897](https://github.com/supabase/supabase-flutter/issues/897)). ([4f5b853c](https://github.com/supabase/supabase-flutter/commit/4f5b853cfb72f92bdceb8446397057ec434f1da3))

## 2.6.0

 - **FIX**: Typos in gotrue_client.dart ([#882](https://github.com/supabase/supabase-flutter/issues/882)). ([54a0b979](https://github.com/supabase/supabase-flutter/commit/54a0b979f61a0a161b805c23329964ca626000ce))
 - **FEAT**(gotrue): Add `signInAnonymously()` method ([#883](https://github.com/supabase/supabase-flutter/issues/883)). ([2e636131](https://github.com/supabase/supabase-flutter/commit/2e636131667e6375a24fd08342c62f20eb5ea143))
 - **FEAT**(gotrue,supabase_flutter): New auth token refresh algorithm ([#879](https://github.com/supabase/supabase-flutter/issues/879)). ([99931681](https://github.com/supabase/supabase-flutter/commit/9993168137f2e48279840c6c1b311ac7ac6138a6))

## 2.5.1

 - **FIX**: Correct the id value passed to `.unlinkIdentity()` method ([#841](https://github.com/supabase/supabase-flutter/issues/841)). ([0585cdde](https://github.com/supabase/supabase-flutter/commit/0585cdde4eefa61eda4c67e41b8f6f266b891fca))
 - **FIX**(gotrue,supabase_flutter): Throw error when parsing auth URL that contains an error description. ([#839](https://github.com/supabase/supabase-flutter/issues/839)). ([afc4ce51](https://github.com/supabase/supabase-flutter/commit/afc4ce51c14798c2319a0ebebe231895c6ddd8ae))

## 2.5.0

 - **FEAT**: Add token hash to verifyOtp ([#813](https://github.com/supabase/supabase-flutter/issues/813)). ([a789d795](https://github.com/supabase/supabase-flutter/commit/a789d7954f8a66e0e8eaa271b82cd2daf274e6de))

## 2.4.1

 - **FIX**(gotrue): Set _currentUser when setting initial session ([#806](https://github.com/supabase/supabase-flutter/issues/806)). ([042f3c6d](https://github.com/supabase/supabase-flutter/commit/042f3c6dde7db6f479088ad788a4bbcbba640808))

## 2.4.0

 - **FEAT**(gotrue,supabase_flutter): Add `signInWithSSO` method ([#798](https://github.com/supabase/supabase-flutter/issues/798)). ([87c16327](https://github.com/supabase/supabase-flutter/commit/87c163279866ac9d44756fd7d5faf01d48860fb0))

## 2.3.0

 - **FEAT**: Add linkedin_oidc OAuthProvider ([#791](https://github.com/supabase/supabase-flutter/issues/791)). ([09664281](https://github.com/supabase/supabase-flutter/commit/0966428189817d3f4ff3a9101ed2402a4fe2f001))

## 2.2.0

 - **FIX**(gotrue): Fix the issue where `verfiyOTP` emits `signIn` instead of `passwordRecovery` auth event. ([#774](https://github.com/supabase/supabase-flutter/issues/774)). ([fc426134](https://github.com/supabase/supabase-flutter/commit/fc426134fff8cb6ab34ea7e7633e29c90cafaa43))
 - **FEAT**(gotrue,supabase_flutter): Add identity linking and unlinking methods. ([#760](https://github.com/supabase/supabase-flutter/issues/760)). ([6c0c922d](https://github.com/supabase/supabase-flutter/commit/6c0c922df6097a6ef5a43b801fbd45900118bd7a))

## 2.1.0

 - **FEAT**: add getUser() method. ([62dcb8c6](https://github.com/supabase/supabase-flutter/commit/62dcb8c6d818e91559699c70befdfbdc63ad2d2f))

## 2.0.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 2.0.0-dev.2

 - **FIX**: PKCE flow not emitting password recovery event ([#744](https://github.com/supabase/supabase-flutter/issues/744)). ([65859bd2](https://github.com/supabase/supabase-flutter/commit/65859bd2676873c685397b4b37d2685bed18b5a1))
 - **FIX**: sign out on already used refresh token ([#740](https://github.com/supabase/supabase-flutter/issues/740)). ([72ffb9ee](https://github.com/supabase/supabase-flutter/commit/72ffb9ee1a1386fb7ab8085b68cd9bc6f6d72c78))
 - **FIX**(gotrue): signing in with pkce flow fires two `signedIn` auth event ([#734](https://github.com/supabase/supabase-flutter/issues/734)). ([6dee1660](https://github.com/supabase/supabase-flutter/commit/6dee1660024afcb926853ec77cd7da685dfa479b))
 - **FEAT**(gotrue): add Figma to  OAuth provider. ([#743](https://github.com/supabase/supabase-flutter/issues/743)). ([f5b72d47](https://github.com/supabase/supabase-flutter/commit/f5b72d47e7af4b62aa99f3e380557ef039b1e2d9))

## 2.0.0-dev.1

 - **FIX**(gotrue): allow empty session response for verifyOtp method ([#680](https://github.com/supabase/supabase-flutter/issues/680)). ([dc6146dc](https://github.com/supabase/supabase-flutter/commit/dc6146dc81e7daa80daacc7e4c4562b033a1b5e8))

## 2.0.0-dev.0

> Note: This release has breaking changes.

 - **FIX**: token refresh doesn't block on ClientException ([#660](https://github.com/supabase/supabase-flutter/issues/660)). ([a5ef8b71](https://github.com/supabase/supabase-flutter/commit/a5ef8b718edcb2e5e19ba8f99d899a17adaa368b))
 - **FIX**(gotrue,supabase): allow refreshSession after exception ([#633](https://github.com/supabase/supabase-flutter/issues/633)). ([8853155f](https://github.com/supabase/supabase-flutter/commit/8853155fdaaec984818323b35718cb1c4c3ede4c))
 - **FEAT**(supabase_flutter): use SharedPreferences for access token ([#608](https://github.com/supabase/supabase-flutter/issues/608)). ([9d72a59d](https://github.com/supabase/supabase-flutter/commit/9d72a59d90434fa30dd3fe1b5f2cea42701eef2d))
 - **BREAKING** **REFACTOR**: many auth breaking changes ([#636](https://github.com/supabase/supabase-flutter/issues/636)). ([7782a587](https://github.com/supabase/supabase-flutter/commit/7782a58768e2e05b15510566dd171eac75331ac1))
 - **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))
 
## 1.12.6

 - **FIX**(gotrue): allow empty session response for verifyOtp method ([#680](https://github.com/supabase/supabase-flutter/issues/680)). ([dc6146dc](https://github.com/supabase/supabase-flutter/commit/dc6146dc81e7daa80daacc7e4c4562b033a1b5e8))

## 1.12.5

 - **FIX**(gotrue): remove import of dart:io from gotrue_client.dart ([#659](https://github.com/supabase/supabase-flutter/issues/659)). ([7280b490](https://github.com/supabase/supabase-flutter/commit/7280b490f10a8de5c69509c5242aff98e348c162))
 - **FIX**: compile with webdev ([#653](https://github.com/supabase/supabase-flutter/issues/653)). ([23242287](https://github.com/supabase/supabase-flutter/commit/232422874df7f09fcf76ab5879822741a7272245))
 - **FIX**(gotrue,supabase): allow refreshSession after exception ([#633](https://github.com/supabase/supabase-flutter/issues/633)). ([8853155f](https://github.com/supabase/supabase-flutter/commit/8853155fdaaec984818323b35718cb1c4c3ede4c))

## 1.12.4

 - **FIX**(gotrue): remove import of dart:io from gotrue_client.dart ([#659](https://github.com/supabase/supabase-flutter/issues/659)). ([7280b490](https://github.com/supabase/supabase-flutter/commit/7280b490f10a8de5c69509c5242aff98e348c162))

## 1.12.3

 - **FIX**: compile with webdev ([#653](https://github.com/supabase/supabase-flutter/issues/653)). ([23242287](https://github.com/supabase/supabase-flutter/commit/232422874df7f09fcf76ab5879822741a7272245))

## 1.12.2

 - **FIX**(gotrue,supabase): allow refreshSession after exception ([#633](https://github.com/supabase/supabase-flutter/issues/633)). ([8853155f](https://github.com/supabase/supabase-flutter/commit/8853155fdaaec984818323b35718cb1c4c3ede4c))

## 1.12.1

 - **FIX**(gotrue): export everything in constants.dart and hide what we want to hide instead of using show ([#617](https://github.com/supabase/supabase-flutter/issues/617)). ([24df174f](https://github.com/supabase/supabase-flutter/commit/24df174fb952a824692f33cb714e4f913c5866f5))

## 1.12.0

 - **FEAT**(gotrue): add WhatsApp support for OTP login ([#613](https://github.com/supabase/supabase-flutter/issues/613)). ([40da5be2](https://github.com/supabase/supabase-flutter/commit/40da5be2d8c883f591b71493749367c1e9de4d43))

## 1.11.2

 - **FIX**(gotrue): export SignOutScope ([#576](https://github.com/supabase/supabase-flutter/issues/576)). ([2bd6e459](https://github.com/supabase/supabase-flutter/commit/2bd6e4599dc3ebb11ffb0deaef19095574d4b93d))

## 1.11.1

 - **FIX**(supabase): get jwt on http call ([#540](https://github.com/supabase/supabase-flutter/issues/540)). ([e044d3ca](https://github.com/supabase/supabase-flutter/commit/e044d3caa2a0085804b7b4f39b050d25ab949083))
 - **FIX**(gotrue): remove OtpType deprecation and add assertion to check type for resend method ([#567](https://github.com/supabase/supabase-flutter/issues/567)). ([d4509de3](https://github.com/supabase/supabase-flutter/commit/d4509de3065c611920b1b2a59d83b04b1727416d))

## 1.11.0

 - **FEAT**(gotrue): add reauthenticate and resend method ([#517](https://github.com/supabase/supabase-flutter/issues/517)). ([35a924b9](https://github.com/supabase/supabase-flutter/commit/35a924b9d131230102f105247ec6d4aa2aff2ddc))

## 1.10.0

 - **REFACTOR**(gotrue): add email otptype ([#534](https://github.com/supabase/supabase-flutter/issues/534)). ([b5fe3d32](https://github.com/supabase/supabase-flutter/commit/b5fe3d326d692b9ee4a8fd43fd21e1f25ef32505))
 - **FIX**(gotrue): add pkce to signup ([#533](https://github.com/supabase/supabase-flutter/issues/533)). ([5b3308a4](https://github.com/supabase/supabase-flutter/commit/5b3308a45fefd24f5a8181e45cd6cc948dca32db))
 - **FEAT**(gotrue): add scope to signOut ([#530](https://github.com/supabase/supabase-flutter/issues/530)). ([94a1cceb](https://github.com/supabase/supabase-flutter/commit/94a1cceb99614cfe84fd3cb8d921ff470e18f43d))

## 1.9.0

 - **FEAT**(gotrue): add accessToken to `signInWithIdToken` method ([#520](https://github.com/supabase/supabase-flutter/issues/520)). ([4dcd5968](https://github.com/supabase/supabase-flutter/commit/4dcd5968bc57e711d6296377fe3374aea27bf3fc))

## 1.8.4

 - **FIX**(gotrue): Add missing members on `User` json serialization ([#512](https://github.com/supabase/supabase-flutter/issues/512)). ([70cc835b](https://github.com/supabase/supabase-flutter/commit/70cc835ba5851d8df0cc92312c70869d520aa851))
 - **FIX**(gotrue): only remove session in otp verification if it's not email change or phone change ([#514](https://github.com/supabase/supabase-flutter/issues/514)). ([23bed82c](https://github.com/supabase/supabase-flutter/commit/23bed82cf2616488f96956ca764ffbc5cbebadd0))

## 1.8.3

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))

## 1.8.2

 - **FIX**(gotrue): catch some errors in signOut ([#501](https://github.com/supabase/supabase-flutter/issues/501)). ([03fa8be7](https://github.com/supabase/supabase-flutter/commit/03fa8be711b36274765bded9c44937da73684b71))

## 1.8.1

 - **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

## 1.8.0

 - **FIX**: reformat Provider type to be ordered alphabetically ([#471](https://github.com/supabase/supabase-flutter/issues/471)). ([c3a1dbb3](https://github.com/supabase/supabase-flutter/commit/c3a1dbb3974bcb7d95160d6412810c69122f2755))
 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))
 - **FEAT**: Add kakao provider enum type ([#470](https://github.com/supabase/supabase-flutter/issues/470)). ([9a1bb334](https://github.com/supabase/supabase-flutter/commit/9a1bb33453a08f3f74838b9624d4e7a709e60859))

## 1.7.1

 - chore: move the repo into supabase-flutter monorepo

## [1.7.0]

- chore: export mfa types [#140](https://github.com/supabase/gotrue-dart/pull/140)
- feat: add synchronous onAuthStateChange for internal use [#139](https://github.com/supabase/gotrue-dart/pull/139)
- feat: add pkce flow support [#135](https://github.com/supabase/gotrue-dart/pull/135)

## [1.6.0]

- feat: expose `headers` as a getter [#137](https://github.com/supabase/gotrue-dart/pull/137)
- fix: prevent `signedIn` event from firing for passwordRecovery event [#136](https://github.com/supabase/gotrue-dart/pull/136)
- fix: pass missing catchaToken parameter on the request of `signInWithPassword` [#138](https://github.com/supabase/gotrue-dart/pull/138)

## [1.5.7]

- fix: prevent onAuthStateChange emitting null session when signed in [#133](https://github.com/supabase/gotrue-dart/pull/133)

## [1.5.6]

- fix: sign out users silently when refresh token is invalid [#126](https://github.com/supabase/gotrue-dart/pull/126)
- fix: correct expiry margin [#130](https://github.com/supabase/gotrue-dart/pull/130)
- fix: pass recoverSession errors to `onAuthStateChanged` [#131](https://github.com/supabase/gotrue-dart/pull/131)

## [1.5.5]

- fix: less sign in event [#127](https://github.com/supabase/gotrue-dart/pull/127)
- fix: add default value to auth response [#128](https://github.com/supabase/gotrue-dart/pull/128)

## [1.5.4]

- fix: lower the version of `meta` to v1.7.0 to match the requirement for Flutter 2.8.0

## [1.5.3]

- fix: properly reset refresh retry count [#122](https://github.com/supabase/gotrue-dart/pull/122)

## [1.5.2]

- fix: make `Factor.friendlyName` nullable [#121](https://github.com/supabase/gotrue-dart/pull/121)

## [1.5.1]

- fix: downgrade `meta` to support minimum Flutter version.

## [1.5.0]

- feat: add support for `signInWithIdToken`.

## [1.4.2]

- fix: `onAuthStateChanged` now emits the latest `AuthState` [#116](https://github.com/supabase/gotrue-dart/pull/116)

## [1.4.1]

- fix: downgrade minimum `collection` version to support wider range of Flutter SDK versions

## [1.4.0]

- feat: add support for [MFA](https://supabase.com/docs/guides/auth/auth-mfa)
  ```dart
  // Start the enrollment process for a new Multi-Factor Authentication (MFA) factor
  final res = await client.mfa
    .enroll(issuer: 'MyFriend', friendlyName: 'MyFriendName');

  // Prepares a challenge used to verify that a user has access to a MFA factor.
  final res = await client.mfa.challenge(factorId: factorId1);

  // Verifies a code against a challenge.
  final res = await client.mfa
          .verify(factorId: factorId1, challengeId: challengeId, code: getTOTP());
  ```
  Read more about MFA with Supabase [here](https://supabase.com/docs/guides/auth/auth-mfa)

## [1.3.0]

- feat: paginate `admin.listUsers()`
  ```dart
  auth.admin.listUsers(page: 2, perPage: 10);
  ```

## [1.2.1]

- fix: allow nullable `role` and `updatedAt` in `User.fromJson()` [#108](https://github.com/supabase/gotrue-dart/pull/108)

## [1.2.0]

- feat: add `createUser()`, `deleteUser()`, and `listUsers()` to admin methods. [#106](https://github.com/supabase/gotrue-dart/pull/106)

## [1.1.1]

- fix: use correct token for refreshing [#104](https://github.com/supabase-community/gotrue-dart/pull/104)

## [1.1.0]

- fix: redirect_to double URL encoding issue [#102](https://github.com/supabase-community/gotrue-dart/pull/102)
- fix: avoid positive lookbehind in snake case extension ([#100](https://github.com/supabase-community/gotrue-dart/pull/101))
- fix: reset token retry count on session remove [#98](https://github.com/supabase-community/gotrue-dart/pull/98)
- feat: fail to getSessionFromUrl throws error on onAuthStateChange [#99](https://github.com/supabase-community/gotrue-dart/pull/99)
  ```dart
  supabase.onAuthStateChange.listen((data) {
    // handle auth state change here
  }, onError: (error) {
    // handle error here
  });
  ```

## [1.0.2]

- fix: verify otp exception on successful verification ([#95](https://github.com/supabase-community/gotrue-dart/pull/95))
- fix: query parameter format for `redirect_to` when making request ([#96](https://github.com/supabase-community/gotrue-dart/pull/96))
- fix: reset token retry count on session remove ([#98](https://github.com/supabase-community/gotrue-dart/pull/98))

## [1.0.1]

- fix: a bug where emailRedirect does not work properly ([#92](https://github.com/supabase-community/gotrue-dart/pull/92))

## [1.0.0]

- chore: v1.0.0 release 🚀
- BREAKING: update the public API to match JS library ([#90](https://github.com/supabase-community/gotrue-dart/pull/90))
  - `signUp()` now uses named parameters
  ```dart
    // Before
    final res = await supabase.auth.signUp('example@email.com', 'password');
    // After
    final res = await supabase.auth.signUp(email: 'example@email.com', password: 'password');
  ```
  - `signIn()` is split into different methods
  ```dart
    // Magic link signin
    // Before
    final res = await supabase.auth.signIn(email: 'example@email.com');
    // After
    final res = await supabase.auth.signInWithOtp(email: 'example@email.com');

    // Email and password signin
    // Before
    final res = await supabase.auth.signIn(email: 'example@email.com', password: 'password');
    // After
    final res = await supabase.auth.signInWithPassword(email: 'example@email.com', password: 'password');
  ``` 
  - `onAuthStateChange` is now a stream
  ```dart
    // Before
    supabase.auth.onAuthStateChange((event, session) {
      // ...
    });
    // After
    final subscription = supabase.auth.onAuthStateChange().listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
    });
    // Don't forget to cancel the subscription when you're done
    subscription.cancel();
  ```
  - `update()` is renamed to `updateUser()`
  ```dart
    // Before
    final res = await supabase.auth.update(
        UserAttributes(
          email: 'new@email.com',
          data: {
            'username': 'new_username',
          },
        ),
    );
    // After
    final res = await supabase.auth.updateUser(
        UserAttributes(
          email: 'new@email.com',
          data: {
            'username': 'new_username',
          },
        ),
    );
  ```

## [1.0.0-dev.4]

- fix: encoding issue with some languages([#89](https://github.com/supabase-community/gotrue-dart/pull/89))

## [1.0.0-dev.3]

- BREAKING: `data` property of `GotrueSessionResponse` is renamed to `session`([#87](https://github.com/supabase-community/gotrue-dart/pull/87))
- fix: bug where siningup with email verification throwed an exception([#87](https://github.com/supabase-community/gotrue-dart/pull/87))

## [1.0.0-dev.2]

- BREAKING: rename `GotrueError` to `GoTrueException`

## [1.0.0-dev.1]
- chore: Update lints to v2.0.0
- feat: Add `.generateLink()` method([#83](https://github.com/supabase-community/gotrue-dart/pull/83))
- fix: Nullable type error if signInWithEmail is used twice([#84](https://github.com/supabase-community/gotrue-dart/pull/84))

## [0.2.3]
- feat: Able to update phone number with `auth.update` method([#81](https://github.com/supabase-community/gotrue-dart/pull/81))

## [0.2.2+1]
- fix: type casting of phone auth response([#79](https://github.com/supabase-community/gotrue-dart/pull/79))

## [0.2.2]
- fix: `OpenIDConnectCredentials`'s `nonce` parameter optional
- fix: use completer in the retry logic to return value when token refresh is complete([#75](https://github.com/supabase-community/gotrue-dart/pull/75))

## [0.2.1]

- fix: Retry access token refresh when offline ([#63](https://github.com/supabase-community/gotrue-dart/pull/63))
- feat: Can add custom http client([#69](https://github.com/supabase-community/gotrue-dart/pull/69))
- feat: Show statuscode in GotrueResponse([#69](https://github.com/supabase-community/gotrue-dart/pull/69))

## [0.2.0]

- BREAKING: `user` will be returned when signing up with auto confirm off ([#63](https://github.com/supabase-community/gotrue-dart/pull/63))
- feat: Slack and Shopify as login providers([43](https://github.com/supabase-community/gotrue-dart/pull/43))
- fix: Adds missing keys - phone, phone_confirmed_at, emailed_confirmed_at to User.toJson()([43](https://github.com/supabase-community/gotrue-dart/pull/43))

## [0.1.6]

- fix: fetch the user, if missing, on `/verify` ([#29](https://github.com/supabase-community/gotrue-dart/issues/29))
- feat: add JWT headers when refreshing token ([#53](https://github.com/supabase-community/gotrue-dart/pull/53))
- feat: add `signInWithOpenIDConnect` ([#61](https://github.com/supabase-community/gotrue-dart/pull/61))

## [0.1.5]

- feat: add `toString` method to `GotrueError`class

## [0.1.4]

- fix: trigger signedIn event on recoverSession

## [0.1.3]

- feat: add `tokenRefreshed` auth event
- feat: add slack, spotify and twitch Auth providers
- fix: update currentSession.user when GoTrueClient.update is called
- chore: export missing types

## [0.1.2]

- feat: `setAuth()` method for setting the session with a provided jwt
- fix: improve client tests

## [0.1.1]

- chore: add `X-Client-Info` header

## [0.1.0]

- feat: add support for phone auth

## [0.0.7]

- fix: stop refreshToken timer on session removed
- fix: close http.Client on request done
- chore: update External OAuth Providers
- chore: add example code block

## [0.0.6]

- fix: export gotrue_response classes

## [0.0.5]

- BREAKING CHANGE: rename 'ProviderOptions' to 'AuthOptions'
- feat: support redirectTo option
- fix: handle jwt expiry less than 60 seconds

## [0.0.4]

- fix: session refresh timer

## [0.0.3]

- fix: wrong timestamp value

## [0.0.2]

- fix: persistSessionString with wrong expiresAt

## [0.0.1]

- fix: URL encode redirectTo

## [0.0.1-dev.11]

- fix: parsing provider callback url with fragment #12

## [0.0.1-dev.10]

- fix: parses provider token and adds oauth scopes and redirectTo
- fix: expiresAt conversion to int and getUser resolving JSON
- fix: signOut method

## [0.0.1-dev.9]

- fix: User nullable params
- fix: Session nullable params
- fix: lint errors

## [0.0.1-dev.8]

- chore: Migrate to Null Safety

## [0.0.1-dev.7]

- fix: Password and other attributes defaulting to email field.
- chore: export UserAttributes

## [0.0.1-dev.6]

- chore: export Provider class

## [0.0.1-dev.5]

- fix: updateUser bug
- fix: http success statusCode check
- fix: stateChangeEmitters uninitialized value

## [0.0.1-dev.4]

- fix: email verification required on sign up

## [0.0.1-dev.3]

- chore: export Session and User classes

## [0.0.1-dev.2]

- fix: session and user parsing from json
- chore: method to get persistSessionString

## [0.0.1-dev.1]

- Initial pre-release.
