## 2.9.0

 - Require Dart >=3.3.0 and flutter >=3.19.0
 - **FIX**: Dispose supabase client after flutter web hot-restart ([#1142](https://github.com/supabase/supabase-flutter/issues/1142)). ([ce582e3e](https://github.com/supabase/supabase-flutter/commit/ce582e3ee7e5d9922d5e38554dfe36a97a47d988))
 - **FEAT**(gotrue,supabase,supabase_flutter,realtime_client): Use web package to access web APIs ([#1135](https://github.com/supabase/supabase-flutter/issues/1135)). ([dfa71c9a](https://github.com/supabase/supabase-flutter/commit/dfa71c9a308b9c51f037f379196ed6f6a9e78f18))

## 2.8.4

 - **FIX**: Allow null to be returned from accessToken function when the user is not signed in ([#1099](https://github.com/supabase/supabase-flutter/issues/1099)). ([d04d9e63](https://github.com/supabase/supabase-flutter/commit/d04d9e63bcc46c2ee71e311b4c3addb216f0f520))
 - **DOCS**: Fix typos ([#1108](https://github.com/supabase/supabase-flutter/issues/1108)). ([46b483f8](https://github.com/supabase/supabase-flutter/commit/46b483f83a70fb7785ef3bccca6849fa6b07852c))

## 2.8.3

 - Update a dependency to the latest release.

## 2.8.2

 - Update a dependency to the latest release.

## 2.8.1

 - **FIX**: Support custom access token ([#1073](https://github.com/supabase/supabase-flutter/issues/1073)). ([fc9ad2c9](https://github.com/supabase/supabase-flutter/commit/fc9ad2c94a02921ca8ced4564d9bcd8cde2c2397))

## 2.8.0

 - **FIX**: Rename logger from gotrue to auth ([#1055](https://github.com/supabase/supabase-flutter/issues/1055)). ([eea1ea6c](https://github.com/supabase/supabase-flutter/commit/eea1ea6c4e200e8ffc52d8343c0684c19670e3ed))
 - **FEAT**: Add logging ([#1042](https://github.com/supabase/supabase-flutter/issues/1042)). ([d1ecabd7](https://github.com/supabase/supabase-flutter/commit/d1ecabd77881a0488d2d4b41ea5ee5abda6c5c35))

## 2.7.0

 - **FIX**: Better stream and access token management ([#1019](https://github.com/supabase/supabase-flutter/issues/1019)). ([4a8b6416](https://github.com/supabase/supabase-flutter/commit/4a8b641661da4ce9b6ddaea64793df58411809f7))
 - **FIX**: Update example native code ([#1029](https://github.com/supabase/supabase-flutter/issues/1029)). ([588b5000](https://github.com/supabase/supabase-flutter/commit/588b5000d64a5d71b45ed57f70f0ed812dd34619))
 - **FEAT**: Broadcast auth events to other tabs on web ([#1005](https://github.com/supabase/supabase-flutter/issues/1005)). ([8f473f1a](https://github.com/supabase/supabase-flutter/commit/8f473f1a99e0cbb9d570eb3fff0786ed5084351c))

## 2.6.0

 - **FIX**: Upgrade `web_socket_channel` for supporting `web: ^1.0.0` and therefore WASM compilation on web ([#992](https://github.com/supabase/supabase-flutter/issues/992)). ([7da68565](https://github.com/supabase/supabase-flutter/commit/7da68565a7aa578305b099d7af755a7b0bcaca46))
 - **FEAT**: Add third-party auth support ([#999](https://github.com/supabase/supabase-flutter/issues/999)). ([c68d44d1](https://github.com/supabase/supabase-flutter/commit/c68d44d10ac4bf8180e5b1833fe0e2bfa2c83515))

## 2.5.11

 - Update a dependency to the latest release.

## 2.5.10

 - Update a dependency to the latest release.

## 2.5.9

 - **FIX**(gotrue): Ensure a single `initialSession` is emitted. ([#975](https://github.com/supabase/supabase-flutter/issues/975)). ([6323f9fd](https://github.com/supabase/supabase-flutter/commit/6323f9fd40564b36027a1fc48004822baa063e19))

## 2.5.8

 - **FIX**: Fix duplicate initial deeplink handling when using AppLinks >= 6.0.0 ([#965](https://github.com/supabase/supabase-flutter/issues/965)). ([74747f0d](https://github.com/supabase/supabase-flutter/commit/74747f0de13187ddb2ebfba06a75d902dd1d98a5))

## 2.5.7

 - Update a dependency to the latest release.

## 2.5.6

 - Update a dependency to the latest release.

## 2.5.5

 - Update a dependency to the latest release.

## 2.5.4

 - Update a dependency to the latest release.

## 2.5.3

 - **FIX**: Keep compatible with app_links 6.0.0 and 5.0.0 ([#918](https://github.com/supabase/supabase-flutter/issues/918)). ([04a59dca](https://github.com/supabase/supabase-flutter/commit/04a59dcae738cf41e3a7daa293751db444f80f4c))

## 2.5.2

 - **FIX**: Update app_links dependency to accept v5.0.0 ([#908](https://github.com/supabase/supabase-flutter/issues/908)). ([7e9b9054](https://github.com/supabase/supabase-flutter/commit/7e9b905475c58d77078655e7cd944236f00a07a9))

## 2.5.1

 - Update a dependency to the latest release.

## 2.5.0

 - **FEAT**(gotrue,supabase_flutter): New auth token refresh algorithm ([#879](https://github.com/supabase/supabase-flutter/issues/879)). ([99931681](https://github.com/supabase/supabase-flutter/commit/9993168137f2e48279840c6c1b311ac7ac6138a6))

## 2.4.0

 - **FEAT**: Add `detectSessionInUri` option to optionally disable deep link observer.  ([#848](https://github.com/supabase/supabase-flutter/issues/848)). ([cb9aed80](https://github.com/supabase/supabase-flutter/commit/cb9aed8056a9725f8a3413958530474faef1d5d1))
 - **DOCS**: Fixed imprecision in Custom Local Storage README.md ([#853](https://github.com/supabase/supabase-flutter/issues/853)). ([6655e576](https://github.com/supabase/supabase-flutter/commit/6655e576b96550e91a24eccce3a79c948adf2922))

## 2.3.4

 - **FIX**(gotrue,supabase_flutter): Throw error when parsing auth URL that contains an error description. ([#839](https://github.com/supabase/supabase-flutter/issues/839)). ([afc4ce51](https://github.com/supabase/supabase-flutter/commit/afc4ce51c14798c2319a0ebebe231895c6ddd8ae))
 - **FIX**: Correct the class name used for custom storage ([#825](https://github.com/supabase/supabase-flutter/issues/825)). ([a7216626](https://github.com/supabase/supabase-flutter/commit/a72166268facd97f07cf9588415a2f3d31f68c22))

## 2.3.3

 - **REFACTOR**: Remove hive dependency and add instructinos to migration from v1 while persisting the auth state ([#823](https://github.com/supabase/supabase-flutter/issues/823)). ([26885c20](https://github.com/supabase/supabase-flutter/commit/26885c20167fd8f689ed0bd532fbff04f0e8006f))

## 2.3.2

 - **FIX**: Remove platform check to start deep link observer on every platform including Linux ([#815](https://github.com/supabase/supabase-flutter/issues/815)). ([9b05eeac](https://github.com/supabase/supabase-flutter/commit/9b05eeac559a1f2da6289e1d70b3fa89e262fa3c))

## 2.3.1

 - Update a dependency to the latest release.

## 2.3.0

 - **FIX**(supabase_flutter): Add timeout to Hive.openBox to fix hanging issue ([#799](https://github.com/supabase/supabase-flutter/issues/799)). ([7fc3ed0b](https://github.com/supabase/supabase-flutter/commit/7fc3ed0bfc14335e3a87b60edc25ba6edbfce6ab))
 - **FEAT**(gotrue,supabase_flutter): Add `signInWithSSO` method ([#798](https://github.com/supabase/supabase-flutter/issues/798)). ([87c16327](https://github.com/supabase/supabase-flutter/commit/87c163279866ac9d44756fd7d5faf01d48860fb0))

## 2.2.0

 - **FEAT**(supabase_flutter): Update app_link to v3.5.0, to add Linux support for deep links ([#792](https://github.com/supabase/supabase-flutter/issues/792)). ([5ad7a674](https://github.com/supabase/supabase-flutter/commit/5ad7a674a22033ac0f792fba8ba3e7fed721190e))

## 2.1.0

 - **FIX**: Update Provider to OAuthProvider in readme ([#778](https://github.com/supabase/supabase-flutter/issues/778)). ([0585ee96](https://github.com/supabase/supabase-flutter/commit/0585ee960c7dbd1b232fe84a169daf8b3f37170c))
 - **FEAT**(gotrue,supabase_flutter): Add identity linking and unlinking methods. ([#760](https://github.com/supabase/supabase-flutter/issues/760)). ([6c0c922d](https://github.com/supabase/supabase-flutter/commit/6c0c922df6097a6ef5a43b801fbd45900118bd7a))

## 2.0.2

 - Update a dependency to the latest release.

## 2.0.1

 - Update a dependency to the latest release.
 - **FIX**: fix(supabase_flutter): export signInWithOAuth() and generateRawNonce() ([#763](https://github.com/supabase/supabase-flutter/pull/763))

## 2.0.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries. Upgrade guide can be found [here](https://supabase.com/docs/reference/dart/upgrade-guide).

## 2.0.0-dev.4

 - **FIX**: PKCE flow not emitting password recovery event ([#744](https://github.com/supabase/supabase-flutter/issues/744)). ([65859bd2](https://github.com/supabase/supabase-flutter/commit/65859bd2676873c685397b4b37d2685bed18b5a1))
 - **FIX**: update sign in with Apple instruction on readme ([#746](https://github.com/supabase/supabase-flutter/issues/746)). ([a4897d06](https://github.com/supabase/supabase-flutter/commit/a4897d06684d38bb159721f8f308fcbde836095e))
 - **FIX**: use SharedPreferences on web ([#738](https://github.com/supabase/supabase-flutter/issues/738)). ([d0cc2015](https://github.com/supabase/supabase-flutter/commit/d0cc20153f23004f1ef2f821b0e9c6d9189f6b03))
 - **FIX**(supabase_flutter): session migration from hive to sharedPreferences now works properly ([#731](https://github.com/supabase/supabase-flutter/issues/731)). ([c81cf07f](https://github.com/supabase/supabase-flutter/commit/c81cf07f75be13916b8b90ccc1ded20f1ad4aec9))

## 2.0.0-dev.3

 - Update a dependency to the latest release.

## 2.0.0-dev.2

 - **FIX**(supabase_flutter): The session is not restored when the application is started. ([#702](https://github.com/supabase/supabase-flutter/issues/702)). ([e1cc576c](https://github.com/supabase/supabase-flutter/commit/e1cc576c53d4f7f84f866e98a03222c1e85c5376))
 
## 2.0.0-dev.1

 - Update a dependency to the latest release.

## 2.0.0-dev.0

> Note: This release has breaking changes.

 - **FEAT**(supabase_flutter): use SharedPreferences for access token ([#608](https://github.com/supabase/supabase-flutter/issues/608)). ([9d72a59d](https://github.com/supabase/supabase-flutter/commit/9d72a59d90434fa30dd3fe1b5f2cea42701eef2d))
 - **DOCS**: update readme to v2 ([#647](https://github.com/supabase/supabase-flutter/issues/647)). ([514cefb4](https://github.com/supabase/supabase-flutter/commit/514cefb40afe65da17de6f54d7884e1a897aa22b))
 - **BREAKING** **REFACTOR**: remove `signInWithApple` method and make `generateRawNonce` public ([#650](https://github.com/supabase/supabase-flutter/issues/650)). ([2f9fe41f](https://github.com/supabase/supabase-flutter/commit/2f9fe41fd71464e6345470097ac4e61cd367fa83))
 - **BREAKING** **REFACTOR**: create package specific configs ([#640](https://github.com/supabase/supabase-flutter/issues/640)). ([53cd3e09](https://github.com/supabase/supabase-flutter/commit/53cd3e0994d09c9818ab1aeac165522e5d80f04b))
 - **BREAKING** **REFACTOR**: many auth breaking changes ([#636](https://github.com/supabase/supabase-flutter/issues/636)). ([7782a587](https://github.com/supabase/supabase-flutter/commit/7782a58768e2e05b15510566dd171eac75331ac1))
 - **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))
 
## 1.10.25

 - Update native Google sign-in instructions on README

## 1.10.24

 - Update a dependency to the latest release.

## 1.10.23

 - Update a dependency to the latest release.

## 1.10.22

 - Update a dependency to the latest release.

## 1.10.21

 - Update a dependency to the latest release.

## 1.10.20

 - Update a dependency to the latest release.

## 1.10.19

 - Update a dependency to the latest release.

## 1.10.18

 - Update a dependency to the latest release.

## 1.10.17

 - Update a dependency to the latest release.

## 1.10.16

 - Update a dependency to the latest release.

## 1.10.15

 - Update a dependency to the latest release.

## 1.10.14

 - **FIX**(realtime_client,supabase): pass apikey as the initial access token for realtime client ([#596](https://github.com/supabase/supabase-flutter/issues/596)). ([af8e368b](https://github.com/supabase/supabase-flutter/commit/af8e368bdb0b2a07f9cf9806c854456f8e9d198e))

## 1.10.13

 - **FIX**(supabase_flutter): update readme.md on the notes about broadcast ([#589](https://github.com/supabase/supabase-flutter/issues/589)). ([d0f4e2dd](https://github.com/supabase/supabase-flutter/commit/d0f4e2dd8e6b6eeb550c164cf19cb2c8a6cb50ba))

## 1.10.12

 - Update a dependency to the latest release.

## 1.10.11

 - Update a dependency to the latest release.

## 1.10.10

 - Update a dependency to the latest release.

## 1.10.9

 - **FIX**(supabase_flutter): update sign_in_with_apple version constraints to allow v5.0.0 ([#548](https://github.com/supabase/supabase-flutter/issues/548)). ([bc977431](https://github.com/supabase/supabase-flutter/commit/bc9774319a578c96d43eea121b7dca319d63a749))

## 1.10.8

 - **FIX**: update the google auth setup instruction to use reversed client ID ([#542](https://github.com/supabase/supabase-flutter/issues/542)). ([fa52378a](https://github.com/supabase/supabase-flutter/commit/fa52378aadc7ad23c422b1c5b515743b814bea7d))

## 1.10.7

 - **FIX**(supabase_flutter): update README.md with additional imports and code to enable Google sign in ([#531](https://github.com/supabase/supabase-flutter/issues/531)). ([de2628fa](https://github.com/supabase/supabase-flutter/commit/de2628fa9d6b6e99871a9dcc7dfc4d4a08182dcb))

## 1.10.6

 - update README.md to include native auth instructions

## 1.10.5

 - Update a dependency to the latest release.

## 1.10.4

 - Update a dependency to the latest release.

## 1.10.3

 - Update a dependency to the latest release.

## 1.10.2

 - Update a dependency to the latest release.

## 1.10.1

 - **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))

## 1.10.0

 - **FIX**: Format the files to adjust to Flutter 3.10.1 ([#475](https://github.com/supabase/supabase-flutter/issues/475)). ([eb0bcd95](https://github.com/supabase/supabase-flutter/commit/eb0bcd954d1691a28a659dc367c4562c7f16b301))
 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

## 1.9.2

 - **FIX**(supabase_flutter): prevent Platform.environment use on web ([#468](https://github.com/supabase/supabase-flutter/issues/468)). ([de5a6300](https://github.com/supabase/supabase-flutter/commit/de5a6300d75f8951f1b75b73d8e6db5f31f581a1))

## 1.9.1

 - chore: update the repo to be a monorepo for all sub-libraries

## [1.9.0]

- feat: add pkce support [#432](https://github.com/supabase/supabase-flutter/pull/432)
  ```dart
  // Initialize Supabase with AuthFlowType.pkce to enable PKCE flow for deep link related auth
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
    authFlowType: AuthFlowType.pkce,
  );
  ```

## [1.8.1]

- fix: ensure that Google login on Android always opens in external browser [#455](https://github.com/supabase/supabase-flutter/pull/455)

## [1.8.0]

- feat: allow `signInWithOAuth` with `platformDefault` option to open in app webview for iOS [#431](https://github.com/supabase/supabase-flutter/pull/431)

## [1.7.0]

- feat: Add signInWithApple method [#437](https://github.com/supabase/supabase-flutter/pull/437)
  ```dart
  final AuthResponse response = await supabase.auth.signInWithApple();
  ```
- fix: upgrade webview_flutter to 4.0.0 [#427](https://github.com/supabase/supabase-flutter/pull/427)

## [1.6.2]

- fix: persist session to local storage on `onAuthStateChanged` event with a session [#422](https://github.com/supabase/supabase-flutter/pull/422)

## [1.6.1]

- fix: log errors from `onAuthStateChange` [#416](https://github.com/supabase/supabase-flutter/pull/416)
- fix: catch initial session [#418](https://github.com/supabase/supabase-flutter/pull/418)

## [1.6.0]

- feat: Added custom WebView for OAuth (LaunchMode.inAppWebView) [#355](https://github.com/supabase/supabase-flutter/pull/355)
- fix: update supabase to v1.6.1
    - add setAuth() function to storage
    - fix: keep one storage and functions instance to persist auth

## [1.5.0]

- feat: update supabase-dart to 1.6.0 [#381](https://github.com/supabase/supabase-flutter/pull/381)
  - add support for `signInWithIdToken`
- fix: declare web support [#392](https://github.com/supabase/supabase-flutter/pull/392)

## [1.4.2]

- fix: show web support on pub.dev [#373](https://github.com/supabase/supabase-flutter/pull/373)
- refactor: update example [#374](https://github.com/supabase/supabase-flutter/pull/374)

## [1.4.1]

- fix: print stack trace on the console while in debug mode when auth error occurs

## [1.4.0]

- feat: add `realtimeClientOptions` to `Supabase.initialize()`
- feat: update supabase to v1.5.0
  - add `realtimeClientOptions` to SupabaseClient
  - add missing `options` parameter to rpc
  - use single isolate for functions and postgrest and add `isolate` parameter to `SupabaseClient`
  - update postgrest to v1.2.2
    - improve comment docs
    - deprecate `returning` parameter of `.delete()`
  - update storage to v1.2.2
    - properly parse content type 
    - correct path parameter documentation
  - update gotrue to v1.4.1
    - `onAuthStateChanged` now emits the latest `AuthState`
    - downgrade minimum `collection` version to support wider range of Flutter SDK versions

## [1.3.1]

- chore: update readme.md file [#335](https://github.com/supabase/supabase-flutter/pull/335)
## [1.3.0]

- feat: add `authScreenLaunchMode` to `auth.signInWithOAuth()` to change OAuth sign-in screen behavior  [#323](https://github.com/supabase/supabase-flutter/pull/323)
  ```dart
  await supabase.auth.signInWithOAuth(
    Provider.goodle,
    authScreenLaunchMode: LaunchMode.inAppWebView,
  );
  ```
- fix: only start deep link observer on supported platforms [#333](https://github.com/supabase/supabase-flutter/pull/333)
- feat: update supabase to v1.3.0
  - fix: handle update and delete on record that wasn't found properly using stream [#167](https://github.com/supabase/supabase-dart/pull/167)
  - feat: update gotrue to v1.4.0
    - add support for [MFA](https://supabase.com/docs/guides/auth/auth-mfa)
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
    - paginate `admin.listUsers()`
      ```dart
      auth.admin.listUsers(page: 2, perPage: 10);
      ```
  - feat: update postgrest to v1.2.1
  - fix: update realtime to v1.0.2
    - export realtime presence
  - feat: update storage to v1.2.0
    - add transform option to `createSignedUrl()`, `getPublicUrl()`, and `.download()` to transform images on the fly
      ```dart
      final signedUrl = await storage.from(newBucketName).createSignedUrl(uploadPath, 2000,
                  transform: TransformOptions(
                    width: 100,
                    height: 100,
                  ));
      final publicUrl = storage.from(bucket).getPublicUrl(path,
              transform: TransformOptions(width: 200, height: 300));
      final file = await storage.from(newBucketName).download(uploadPath,
              transform: TransformOptions(
                width: 200,
                height: 200,
              ));
      ```


## [1.2.2]

- fix: bug where auth callback URL is not correctly parsed [#292](https://github.com/supabase/supabase-flutter/pull/292)

## [1.2.1]

- fix: Only parse deep links if it contains access_token [#284](https://github.com/supabase/supabase-flutter/pull/284)
- chore: update and add some links in Readme.md [#286](https://github.com/supabase/supabase-flutter/pull/286)

## [1.2.0]

- feat: update supabase to v1.2.0
  - add createUser(), deleteUser(), and listUsers() to admin methods.
- feat: add storage retry option to enable storage to auto retry failed upload attempts [#280](https://github.com/supabase/supabase-flutter/pull/280)
  ```dart
  // The following will initialize Supabase that will retry failed uploads up to 25 times,
  // which is about 10 minutes of retrying.
  await Supabase.initialize(
    supabaseUrl,
    supabaseAnonKey,
    storageRetryAttempts: 25,
  );
  ```

## [1.1.0]

- fix: await for the initial deeplink to be handled during auth initialize [#262](https://github.com/supabase/supabase-flutter/pull/262)
- feat: update supabase to v1.1.0
  - fix: stream filter other than eq is not properly applied.
  - fail to getSessionFromUrl throws error on `onAuthStateChange`
    ```dart
    supabase.onAuthStateChange.listen((data) {
      // handle auth state change here
    }, onError: (error) {
      // handle error here
    });
    ```
  - feat: add generic types to `.select()`
    ```dart
    // data is `List<Map<String, dynamic>>`
    final data = await supabase.from('users').select<List<Map<String, dynamic>>>();

    // data is `Map<String, dynamic>`
    final data = await supabase.from('users').select<Map<String, dynamic>>().eq('id', myId).single();
    ```
## [1.0.1]

- fix: update sample code on readme.md
## [1.0.0]


- chore: v1.0.0 release 🚀
- BREAKING: update supabase to [v1.0.0](https://github.com/supabase-community/supabase-flutter/pull/240)
  - BREAKING: `.stream()` now takes a named parameter `primaryKey` instead of a positional argument. 
    ```dart
    supabase.from('my_table').stream(primaryKey: ['id']);
    ```
  - feat: `.stream()` has 5 additional filters: `neq`, `gt`, `gte`, `lt`, `lte` ([148](https://github.com/supabase-community/supabase-dart/pull/148)
  - `auth.signUp()` now uses named parameters
  ```dart
    // Before
    final res = await supabase.auth.signUp('example@email.com', 'password');
    // After
    final res = await supabase.auth.signUp(email: 'example@email.com', password: 'password');
  ```
  - `auth.signIn()` is split into different methods
  ```dart
    // Magic link sign-in
    // Before
    final res = await supabase.auth.signIn(email: 'example@email.com');
    // After
    final res = await supabase.auth.signInWithOtp(email: 'example@email.com');

    // Email and password sign-in
    // Before
    final res = await supabase.auth.signIn(email: 'example@email.com', password: 'password');
    // After
    final res = await supabase.auth.signInWithPassword(email: 'example@email.com', password: 'password');
  ``` 
  - `auth.onAuthStateChange` is now a stream
  ```dart
    // Before
    supabase.auth.onAuthStateChange((event, session) {
      // ...
    });
    // After
    final subscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
    });
    // Don't forget to cancel the subscription when you're done
    subscription.cancel();
  ```
  - `auth.update()` is renamed to `auth.updateUser()`
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
  - `SupabaseAuth.instance.onAuthChange()` is now removed and `supabase.auth.onAuthStateChange()` should be used instead
- BREAKING: set minimum required Flutter version to 2.8.0



## [1.0.0-dev.9]

- fix: update supabase to [v1.0.0-dev.9](https://github.com/supabase-community/supabase-dart/blob/main/CHANGELOG.md#100-dev9)
  - fix: recreate a `PostgrestClient` with proper auth headers when calling `.rpc()` [(#143)](https://github.com/supabase-community/supabase-dart/pull/143)
  - fix: allow custom headers to be set for `SupabaseClient` [(#144)](https://github.com/supabase-community/supabase-dart/pull/144)
  - fix: stream error will emit the entire exception and the stack trace [(#145)](https://github.com/supabase-community/supabase-dart/pull/145)
  - fix: update realtime to [v1.0.0-dev.5](https://github.com/supabase-community/realtime-dart/blob/main/CHANGELOG.md#100-dev5)
    - fix: bug where it throws exception when listening to postgres changes on old version of realtime server
    - fix: sends null for access_token when not signed in [(#53)](https://github.com/supabase-community/realtime-dart/pull/53)



## [1.0.0-dev.8]

- BREAKING: update supabase to [v1.0.0-dev.7](https://github.com/supabase-community/supabase-dart/pull/141)
  - update payload shape on old version of realtime server to match the new version in realtime [v1.0.0-dev.3](https://github.com/supabase-community/realtime-dart/blob/main/CHANGELOG.md#100-dev3)
  - fix: encoding issue with some languages in gotrue [v1.0.0-dev.4](https://github.com/supabase-community/gotrue-dart/blob/main/CHANGELOG.md#100-dev4)
  - fix: update insert documentation to reflect new `returning` behavior in postgrest [v1.0.0-dev.4](https://github.com/supabase-community/postgrest-dart/blob/master/CHANGELOG.md#100-dev4)

## [1.0.0-dev.7]

- chore: update supabase to [v1.0.0-dev.6](https://github.com/supabase-community/supabase-dart/pull/139)
  - fix: `.stream()` typing issue [#138](https://github.com/supabase-community/supabase-dart/pull/138)

## [1.0.0-dev.6]

- BREAKING: update supabase package [v1.0.0-dev.5](https://github.com/supabase-community/supabase-dart/blob/main/CHANGELOG.md#100-dev5)
  - deprecated: `.stream()` no longer needs `.execute()`
  - BREAKING: `eq` filter on `.stream()` is a separate method now
  ```dart
  // before
  Supabase.instance.client.from('my_table:title=eq.Supabase')
    .stream(['id'])
    .order('created_at')
    .limit(10)
    .execute()
    .listen((payload) {
      // do something with payload here
    });

  // now
  Supabase.instance.client.from('my_table')
    .stream(['id'])
    .eq('title', 'Supabase')
    .order('created_at')
    .limit(10)
    .listen((payload) {
      // do something with payload here
    });
  ```
  - BREAKING: listening to database changes has a new API
  - feat: added support for [broadcast](https://supabase.com/docs/guides/realtime/broadcast) and [presence](https://supabase.com/docs/guides/realtime/presence)
  ```dart
  final channel = Supabase.instance.client.channel('can_be_any_string');

  // listen to insert events on public.messages table
  channel.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
      ), (payload, [ref]) {
    print('database insert payload: $payload');
  });

  // listen to `location` broadcast events
  channel.on(
      RealtimeListenTypes.broadcast,
      ChannelFilter(
        event: 'location',
      ), (payload, [ref]) {
    print(payload);
  });

  // send `location` broadcast events
  channel.send(
    type: RealtimeListenTypes.broadcast,
    event: 'location',
    payload: {'lat': 1.3521, 'lng': 103.8198},
  );

  // listen to presence states
  channel.on(RealtimeListenTypes.presence, ChannelFilter(event: 'sync'),
      (payload, [ref]) {
    print(payload);
    print(channel.presenceState());
  });

  // subscribe to the above changes
  channel.subscribe((status) async {
    if (status == 'SUBSCRIBED') {
      // if subscribed successfully, send presence event
      final status = await channel.track({'user_id': myUserId});
    }
  });
  ```

## [1.0.0-dev.5]

- chore: add example app in example directory
- fix: `WidgetsBinding` warning

## [1.0.0-dev.4]

- BREAKING: update supabase package [v1.0.0-dev.4](https://github.com/supabase-community/supabase-dart/blob/main/CHANGELOG.md#100-dev4)
- feat: accept custom headers
- feat: add add X-Client-Info header

## [1.0.0-dev.3]

- BREAKING: update supabase package [v1.0.0-dev.3](https://github.com/supabase-community/supabase-dart/blob/main/CHANGELOG.md#100-dev3)

## [1.0.0-dev.2]

- feat: custom http client

## [1.0.0-dev.1]
- feat: add Mac OS and Windows support for deep links
- BREAKING: Remove SupabaseAuthRequiredState as well as overriding methods in SupabaseAuthState
```dart
// Before

await Supabase.initialize(
  url: 'SUPABASE_URL',
  anonKey: 'SUPABASE_ANON_KEY',
);
...

// Class extending `SupabaseAuthState` or `AuthRequiredState` was necessary
// to persist auth state
class AuthState<T extends StatefulWidget> extends SupabaseAuthState<T> {
  ...
}

// After

// Initializing Supabase is all you need to do to persist auth state
// Deep links will also be automatically handled when you initialize Supabase.
await Supabase.initialize(
  url: 'SUPABASE_URL',
  anonKey: 'SUPABASE_ANON_KEY',
);

...

// You can get the initial session of the user with `SupabaseAuth.instance.initialSession`
try {
    final initialSession = await SupabaseAuth.instance.initialSession;
} catch(error) {
    // Handle errors in session initial recovery here
}

// You should now use `onAuthStateChanged` as the 
Supabase.instance.client.auth.onAuthStateChange((event, session) {
    // handle sign-in/signups here
});
```
- fix: OAuth should open in an external browser
- BREAKING: update supabase package [v1.0.0-dev.1](https://github.com/supabase-community/supabase-dart/blob/main/CHANGELOG.md#100-dev1)

## [0.3.3]
- feat: update supabase package [v0.3.6](https://github.com/supabase-community/supabase-dart/blob/main/CHANGELOG.md#036)

## [0.3.2]
- chore: add basic example codes on readme.md

## [0.3.1+3]
- fix: OAuth authentication page should open in an external browser

## [0.3.1+2]
- chore: update supabase package [v0.3.4+1](https://github.com/supabase-community/supabase-dart/blob/main/CHANGELOG.md#0341)

## [0.3.1+1]

- fix: lint error on Flutter 2.X
- chore: add multiple Flutter version to the CI pipeline

## [0.3.1]

- feat: update supabase to [v0.3.4](https://github.com/supabase-community/supabase-dart/blob/main/CHANGELOG.md#030)

## [0.3.0]

- BREAKING: update supabase to [v0.3.0](https://github.com/supabase-community/supabase-dart/blob/main/CHANGELOG.md#030)

## [0.2.12]

- chore: update supabase-dart package v0.2.14

## [0.2.11]

- chore: update supabase-dart package v0.2.13

## [0.2.10]

- chore: update supabase-dart package v0.2.12
- chore: update documents

## [0.2.9]

- feat: signing out now triggers `onUnauthenticated()`
- feat: export supabase package so that underlying symbols can be imported
- fix: update code samples to reflect breaking change from v0.0.3
- fix: typos on code samples on readme.md

## [0.2.8]

- chore: update supabase to v0.2.7

## [0.2.7]

- chore: update supabase to v0.2.6

## [0.2.6]

- fix: export local_storage

## [0.2.5]

- chore: update supabase to v0.2.5

## [0.2.4]

- chore: update supabase to v0.2.4

## [0.2.3]

- chore: update supabase to v0.2.3

## [0.2.2]

- chore: update supabase to v0.2.2

## [0.2.1]

- chore: update supabase to v0.2.1

## [0.2.0]

- chore: update supabase to v0.2.0

## [0.1.0]

- BREAKING CHANGE: `Supabase.initialize` is now `Future<void>`
- chore: update supabase to v0.1.0
- feat: using hive to persist session by default

## [0.0.8]

- chore: update supabase to v0.0.8

## [0.0.7]

- chore: update supabase to v0.0.7

## [0.0.6]

- chore: update supabase to v0.0.5

## [0.0.5]

- chore: update supabase to v0.0.4

## [0.0.4]

- chore: update supabase to v0.0.3

## [0.0.3]

- BREAKING CHANGE: rework Supabase singleton with `Supabase.initialize` and `Supabase.instance`
- chore: update docs

## [0.0.2]

- feat: support custom localStorage with fallback to SharedPreferences as default

## [0.0.1]

- chore: update supabase, url_launcher packages

## [0.0.1-dev.5]

- fix: launch url in the current tab for flutter web
- fix: SupabaseAuthRequiredState to trigger onAuthenticated when user session available

## [0.0.1-dev.4]

- feat: support flutter web

## [0.0.1-dev.3]

- chore: update supabase to v0.0.1

## [0.0.1-dev.2]

- feat: support nested authentication flow with startAuthObserver() and stopAuthObserver()
- feat: support SupabaseAuthRequiredState
- feat: support enable/disable debug log
- refactor: tidy up

## [0.0.1-dev.1]

- Initial pre-release.
