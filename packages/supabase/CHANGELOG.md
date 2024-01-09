## 2.0.4

 - Update a dependency to the latest release.

## 2.0.3

 - Update a dependency to the latest release.

## 2.0.2

 - Update a dependency to the latest release.

## 2.0.1

 - Update a dependency to the latest release.

## 2.0.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 2.0.0-dev.4

 - **FIX**: realtime ordering on double ([#741](https://github.com/supabase/supabase-flutter/issues/741)). ([f20faef7](https://github.com/supabase/supabase-flutter/commit/f20faef710e4e730590543ccd0a7bafd072be2ff))
 - **REFACTOR**: make `schema` variable private and rename `useSchema()` to `schema()` ([#737](https://github.com/supabase/supabase-flutter/issues/737)). 

## 2.0.0-dev.3

 - Update a dependency to the latest release.

## 2.0.0-dev.2

- Update a dependency to the latest release.

## 2.0.0-dev.1

 - Update a dependency to the latest release.

## 2.0.0-dev.0

> Note: This release has breaking changes.

 - **FIX**: stream with a different schema ([#661](https://github.com/supabase/supabase-flutter/issues/661)). ([c8fc2482](https://github.com/supabase/supabase-flutter/commit/c8fc24828d4f36fed64453a53d1bb5b4ff918d32))
 - **FIX**(gotrue,supabase): allow refreshSession after exception ([#633](https://github.com/supabase/supabase-flutter/issues/633)). ([8853155f](https://github.com/supabase/supabase-flutter/commit/8853155fdaaec984818323b35718cb1c4c3ede4c))
 - **FEAT**(supabase_flutter): use SharedPreferences for access token ([#608](https://github.com/supabase/supabase-flutter/issues/608)). ([9d72a59d](https://github.com/supabase/supabase-flutter/commit/9d72a59d90434fa30dd3fe1b5f2cea42701eef2d))
 - **FEAT**(postgrest): immutability ([#600](https://github.com/supabase/supabase-flutter/issues/600)). ([95256697](https://github.com/supabase/supabase-flutter/commit/952566979dfae1e76ff9bac08354a729c0bd9514))
 - **DOCS**: update readme to v2 ([#647](https://github.com/supabase/supabase-flutter/issues/647)). ([514cefb4](https://github.com/supabase/supabase-flutter/commit/514cefb40afe65da17de6f54d7884e1a897aa22b))
 - **BREAKING** **REFACTOR**: rename is_ and in_ to isFilter and inFilter ([#646](https://github.com/supabase/supabase-flutter/issues/646)). ([1227394e](https://github.com/supabase/supabase-flutter/commit/1227394ed41913907d10bcafe59e3dbcea62e9e4))
 - **BREAKING** **REFACTOR**: create package specific configs ([#640](https://github.com/supabase/supabase-flutter/issues/640)). ([53cd3e09](https://github.com/supabase/supabase-flutter/commit/53cd3e0994d09c9818ab1aeac165522e5d80f04b))
 - **BREAKING** **REFACTOR**: many auth breaking changes ([#636](https://github.com/supabase/supabase-flutter/issues/636)). ([7782a587](https://github.com/supabase/supabase-flutter/commit/7782a58768e2e05b15510566dd171eac75331ac1))
 - **BREAKING** **REFACTOR**: use Dart 3 ([#598](https://github.com/supabase/supabase-flutter/issues/598)). ([02c4071a](https://github.com/supabase/supabase-flutter/commit/02c4071aaf2792d365792eed18ec65d09af4c247))
 - **BREAKING** **FIX**(supabase): make Supabase credentials private in `SupabaseClient` ([#649](https://github.com/supabase/supabase-flutter/issues/649)). ([fa341bfe](https://github.com/supabase/supabase-flutter/commit/fa341bfee883526a994bd61893aaba19bd521496))
 - **BREAKING** **FEAT**(postgrest): stronger type system for query building ([#624](https://github.com/supabase/supabase-flutter/issues/624)). ([951ce89e](https://github.com/supabase/supabase-flutter/commit/951ce89eced66afe88b6c406226823e1f7ced58e))
 - **BREAKING** **FEAT**: use Object? instead of dynamic ([#606](https://github.com/supabase/supabase-flutter/issues/606)). ([0c6caa00](https://github.com/supabase/supabase-flutter/commit/0c6caa00912bc73fc220110bdd9f3d69aaecb3ac))
 
## 1.11.11

 - Update a dependency to the latest release.

## 1.11.10

 - **FIX**: make Supabase client work in Dart Edge again ([#675](https://github.com/supabase/supabase-flutter/issues/675)). ([53530f22](https://github.com/supabase/supabase-flutter/commit/53530f222b1430debf40d0beb95f75f279d1830f))
 - **FIX**(gotrue,supabase): allow refreshSession after exception ([#633](https://github.com/supabase/supabase-flutter/issues/633)). ([8853155f](https://github.com/supabase/supabase-flutter/commit/8853155fdaaec984818323b35718cb1c4c3ede4c))

## 1.11.9

 - Update a dependency to the latest release.

## 1.11.8

 - Update a dependency to the latest release.

## 1.11.7

 - Update a dependency to the latest release.

## 1.11.6

 - Update a dependency to the latest release.

## 1.11.5

 - **FIX**(gotrue,supabase): allow refreshSession after exception ([#633](https://github.com/supabase/supabase-flutter/issues/633)). ([8853155f](https://github.com/supabase/supabase-flutter/commit/8853155fdaaec984818323b35718cb1c4c3ede4c))

## 1.11.4

 - Update a dependency to the latest release.

## 1.11.3

 - Update a dependency to the latest release.

## 1.11.2

 - Update a dependency to the latest release.

## 1.11.1

 - **FIX**(realtime_client,supabase): pass apikey as the initial access token for realtime client ([#596](https://github.com/supabase/supabase-flutter/issues/596)). ([af8e368b](https://github.com/supabase/supabase-flutter/commit/af8e368bdb0b2a07f9cf9806c854456f8e9d198e))

## 1.11.0

 - **FEAT**: add `logLevel` parameter to `RealtimeClientOptions` ([#592](https://github.com/supabase/supabase-flutter/issues/592)). ([76e9fc20](https://github.com/supabase/supabase-flutter/commit/76e9fc2067cc36e67c7bbaaed1fcad6281426f82))

## 1.10.0

 - **FEAT**(postgrest,supabase): add `useSchema()` method for making rest API calls on custom schema. ([#525](https://github.com/supabase/supabase-flutter/issues/525)). ([40a0f090](https://github.com/supabase/supabase-flutter/commit/40a0f09078bface9cb51cb0f7fe7bd6e1032b99b))

## 1.9.9

 - Update a dependency to the latest release.

## 1.9.8

 - **FIX**(supabase): get jwt on http call ([#540](https://github.com/supabase/supabase-flutter/issues/540)). ([e044d3ca](https://github.com/supabase/supabase-flutter/commit/e044d3caa2a0085804b7b4f39b050d25ab949083))

## 1.9.7

 - Update a dependency to the latest release.

## 1.9.6

 - Update a dependency to the latest release.

## 1.9.5

 - Update a dependency to the latest release.

## 1.9.4

 - Update a dependency to the latest release.

## 1.9.3

 - **REFACTOR**: bump minimum Dart SDK version to 2.17.0 ([#510](https://github.com/supabase/supabase-flutter/issues/510)). ([ed927ee0](https://github.com/supabase/supabase-flutter/commit/ed927ee061272f61c84ee3ee145bb4e8c0eae59a))
 - **FIX**(supabase): add stackTrace on stream exception ([#509](https://github.com/supabase/supabase-flutter/issues/509)). ([c8c3ace2](https://github.com/supabase/supabase-flutter/commit/c8c3ace2b70a2a789eb87dd2ca3437f5d98fd0f3))
 - **FIX**: Add errors from `.subscribe()` to `.stream()` streamController ([#506](https://github.com/supabase/supabase-flutter/issues/506)). ([a4cb4c53](https://github.com/supabase/supabase-flutter/commit/a4cb4c530330bf03aa37ae2521e6b6d2f3b96fbf))

## 1.9.2

 - **REFACTOR**(supabase): simplify functions url ([#496](https://github.com/supabase/supabase-flutter/issues/496)). ([21e9fc1b](https://github.com/supabase/supabase-flutter/commit/21e9fc1be2cd09f1626bc23de5b21f9a4b9609fe))

## 1.9.1

 - **FIX**: Update http dependency constraints ([#491](https://github.com/supabase/supabase-flutter/issues/491)). ([825d0737](https://github.com/supabase/supabase-flutter/commit/825d07375d873b2a56b31c7cc881cb3a4226a8fd))
 - **DOCS**(supabase): update comment docs on stream ([#482](https://github.com/supabase/supabase-flutter/issues/482)). ([5de84c24](https://github.com/supabase/supabase-flutter/commit/5de84c246740ba94ec2b91688ed5a108df9c0c7f))

## 1.9.0

 - **FEAT**: update dependency constraints to sdk < 4.0.0 ([#474](https://github.com/supabase/supabase-flutter/issues/474)). ([7894bc70](https://github.com/supabase/supabase-flutter/commit/7894bc70a154b68cb62507262470504188f32c06))

## 1.8.1

 - chore: move the repo into supabase-flutter monorepo

## [1.8.0]
- feat: make the headers property editable [#185](https://github.com/supabase/supabase-dart/pull/185)
  ```dart
  // Add custom headers using the `headers` setter
  supabase.headers = {'my-headers': 'my-value'};
  ```

## [1.7.0]
- feat: add async storage as parameter to support pkce flow [#190](https://github.com/supabase/supabase-dart/pull/190)
- fix: use onAuthStateChangeSync to set auth headers [#193](https://github.com/supabase/supabase-dart/pull/193)

## [1.6.4]
- fix: race condition for passing auth headers for rest client [#192](https://github.com/supabase/supabase-dart/pull/192)


## [1.6.3]
- fix: copy headers value on from() call [#189](https://github.com/supabase/supabase-dart/pull/189)

## [1.6.2]
- fix: handle onAuthStateChange errors silently [#187](https://github.com/supabase/supabase-dart/pull/187)
- fix: persist a single postgrest client [#186](https://github.com/supabase/supabase-dart/pull/186)

## [1.6.1]
- fix: update storage to v1.2.3
  - add `setAuth()` function
- fix: keep one storage and functions instance to persist auth [#182](https://github.com/supabase/supabase-dart/pull/182)

## [1.6.0]
- feat: update gotrue to v1.5.1
  - add support for `signInWithIdToken`
- feat: update functions_client to v1.1.0
  - add method parameter to invoke() to support all GET, POST, PUT, PATCH, DELETE methods

## [1.5.1]

- fix: reuse isolate for `.rpc()` call [#177](https://github.com/supabase/supabase-dart/pull/177)

## [1.5.0]

- feat: add `realtimeClientOptions` to SupabaseClient [#173](https://github.com/supabase/supabase-dart/pull/173)
- fix: add missing `options` parameter to rpc [#174](https://github.com/supabase/supabase-dart/pull/174)
- fix: update postgrest to v1.2.2
  - improve comment docs
  - deprecate `returning` parameter of `.delete()`
- fix: update storage to v1.2.2
  - properly parse content type 
## [1.4.0]

- feat: use single isolate for functions and postgrest and add `isolate` parameter to `SupabaseClient` [#169](https://github.com/supabase/supabase-dart/pull/169)
- fix: update gotrue to v1.4.1
  - `onAuthStateChanged` now emits the latest `AuthState`
  - downgrade minimum `collection` version to support wider range of Flutter SDK versions
- fix: update storage to v1.2.1
  - correct path parameter documentation


## [1.3.0]

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


## [1.2.0]

- feat: add storage retry option to enable storage to auto retry failed upload attempts [(#163)](https://github.com/supabase/supabase-dart/pull/163)
  ```dart
  // The following will initialize a supabase client that will retry failed uploads up to 25 times,
  // which is about 10 minutes of retrying.
  final supabase = SupabaseClient('Supabase_URL', 'Anon_key', storageRetryAttempts: 25);
  ```
- feat: update storage to v1.1.0
- feat: update gotrue to v1.2.0
  - add createUser(), deleteUser(), and listUsers() to admin methods.


## [1.1.2]

- fix: enable listening to the same stream multiple times [(#161)](https://github.com/supabase/supabase-dart/pull/161)

## [1.1.1]

- fix: update postgrest to v1.1.1
- fix: implement asyncMap and asyncExpand [(#159)](https://github.com/supabase/supabase-dart/pull/159)

## [1.1.0]

- fix: stream filter other than eq is not properly applied. [(#156)](https://github.com/supabase-community/supabase-dart/pull/156)
- fix: update examples [(#157)](https://github.com/supabase-community/supabase-dart/pull/157)
- feat: update gotrue to v1.1.1
  - fail to getSessionFromUrl throws error on `onAuthStateChange`
    ```dart
    supabase.onAuthStateChange.listen((data) {
      // handle auth state change here
    }, onError: (error) {
      // handle error here
    });
    ```
- feat: update postgrest to v1.1.0
  - feat: add generic types to `.select()`
    ```dart
    // data is `List<Map<String, dynamic>>`
    final data = await supabase.from<List<Map<String, dynamic>>>('users').select();

    // data is `Map<String, dynamic>`
    final data = await supabase.from<Map<String, dynamic>>('users').select().eq('id', myId).single();
    ```


## [1.0.1]

- fix: update sample code on readme.md

## [1.0.0]

- chore: v1.0.0 release 🚀
- BREAKING: set minimum SDK of Dart at 2.15.0 [(#150)](https://github.com/supabase-community/supabase-dart/pull/150)
- BREAKING: `.stream()` now takes a named parameter `primaryKey` instead of a positional argument. 
  ```dart
  supabase.from('my_table').stream(primaryKey: ['id']);
  ```
- feat: `.stream()` has 5 additional filters: `neq`, `gt`, `gte`, `lt`, `lte` [(#148)](https://github.com/supabase-community/supabase-dart/pull/148)
- chore: update postgrest to v1.0.0
- chore: update realtime to v1.0.0
- chore: update storage to v1.0.0
- chore: update functions to v1.0.0
- BREAKING: update gotrue to v1.0.0
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

## [1.0.0-dev.9]

- fix: update realtime to [v1.0.0-dev.5](https://github.com/supabase-community/realtime-dart/blob/main/CHANGELOG.md#100-dev5)
  - fix: sends null for access_token when not signed in [(#53)](https://github.com/supabase-community/realtime-dart/pull/53)

## [1.0.0-dev.8]

- fix: recreate a `PostgrestClient` with proper auth headers when calling `.rpc()` [(#143)](https://github.com/supabase-community/supabase-dart/pull/143)
- fix: allow custom headers to be set for `SupabaseClient` [(#144)](https://github.com/supabase-community/supabase-dart/pull/144)
- fix: stream error will emit the entire exception and the stack trace [(#145)](https://github.com/supabase-community/supabase-dart/pull/145)
- fix: update realtime to [v1.0.0-dev.4](https://github.com/supabase-community/realtime-dart/blob/main/CHANGELOG.md#100-dev4)
  - fix: bug where it throws exception when listening to postgres changes on old version of realtime server

## [1.0.0-dev.7]

- BREAKING: update relatime to [v1.0.0-dev.3](https://github.com/supabase-community/realtime-dart/blob/main/CHANGELOG.md#100-dev3)
  - update payload shape on old version of realtime server to match the new version
- fix: update gotrue to [v1.0.0-dev.4](https://github.com/supabase-community/gotrue-dart/blob/main/CHANGELOG.md#100-dev4)
  - fix: encoding issue with some languages
- fix: update postgrest to [v1.0.0-dev.4](https://github.com/supabase-community/postgrest-dart/blob/master/CHANGELOG.md#100-dev4)
  - fix: update insert documentation to reflect new `returning` behavior

## [1.0.0-dev.6]

- fix: `.stream()` method typing issue

## [1.0.0-dev.5]

- BREAKING: update realtime to [v1.0.0-dev.2](https://github.com/supabase-community/realtime-dart/blob/main/CHANGELOG.md#100-dev2)
- deprecated: `.execute()` and `.stream()` can be used without it
- BREAKING: filters on `.stream()` no longer takes the realtime syntax. `.eq()` method should be used to apply `eq` filter on `.stream()`. 
```dart
// before
supabase.from('my_table:title=eq.Supabase')
  .stream(['id'])
  .order('created_at')
  .limit(10)
  .execute()
  .listen((payload) {
    // do something with payload here
  });

// now
supabase.from('my_table')
  .stream(['id'])
  .eq('title', 'Supabase')
  .order('created_at')
  .limit(10)
  .listen((payload) {
    // do something with payload here
  });
```

## [1.0.0-dev.4]

- fix: update storage to [v1.0.0-dev.3](https://github.com/supabase-community/storage-dart/blob/main/CHANGELOG.md#100-dev3)
- fix: add `web_socket_channel` to dev dependencies since it is used in tests
- fix: add basic `postgrest` test
- BREAKING: update gotrue to [v1.0.0-dev.3](https://github.com/supabase-community/gotrue-dart/blob/main/CHANGELOG.md#100-dev3)

## [1.0.0-dev.3]

- fix: export storage types
- BREAKING: update postgrest to [v1.0.0-dev.2](https://github.com/supabase-community/postgrest-dart/blob/master/CHANGELOG.md#100-dev2)
- BREAKING: update gotrue to [v1.0.0-dev.2](https://github.com/supabase-community/gotrue-dart/blob/main/CHANGELOG.md#100-dev2)
- feat: update storage to [v1.0.0-dev.2](https://github.com/supabase-community/storage-dart/blob/main/CHANGELOG.md#100-dev2)

## [1.0.0-dev.2]

- feat: custom http client

## [1.0.0-dev.1]

- BREAKING: update postgrest to [v1.0.0-dev.1](https://github.com/supabase-community/postgrest-dart/blob/master/CHANGELOG.md#100-dev1)
- BREAKING: update gotrue to [v1.0.0-dev.1](https://github.com/supabase-community/gotrue-dart/blob/main/CHANGELOG.md#100-dev1)
- BREAKING: update storage to [v1.0.0-dev.1](https://github.com/supabase-community/storage-dart/blob/main/CHANGELOG.md#100-dev1)
- BREAKING: update functions to [v1.0.0-dev.1](https://github.com/supabase-community/functions-dart/blob/main/CHANGELOG.md#100-dev1)

## [0.3.6]

- fix: Calling postgrest endpoints within realtime callback throws exception
- feat: update gotrue to [v0.2.3](https://github.com/supabase-community/gotrue-dart/blob/main/CHANGELOG.md#023)

## [0.3.5]

- fix: update gotrue to [v0.2.2+1](https://github.com/supabase-community/gotrue-dart/blob/main/CHANGELOG.md#0221)
- feat: update postgrest to [v0.1.11](https://github.com/supabase-community/postgrest-dart/blob/master/CHANGELOG.md#0111)
- fix: flaky test on stream()

## [0.3.4+1]

- fix: export type, `SupabaseRealtimePayload`

## [0.3.4]

- fix: update gotrue to [v0.2.2](https://github.com/supabase-community/gotrue-dart/blob/main/CHANGELOG.md#022)

## [0.3.3]

- feat: update gotrue to[v0.2.1](https://github.com/supabase-community/gotrue-dart/blob/main/CHANGELOG.md#021)
- fix: update postgrest to[0.1.10+1](https://github.com/supabase-community/postgrest-dart/blob/master/CHANGELOG.md#01101)

## [0.3.2]

- feat: update postgrest to [v0.1.10](https://github.com/supabase-community/postgrest-dart/blob/master/CHANGELOG.md#0110)
- fix: update functions_client to [v0.0.1-dev.4](https://github.com/supabase-community/functions-dart/blob/main/CHANGELOG.md#001-dev4)

## [0.3.1+1]

- feat: exporting classes of functions_client

## [0.3.1]

- feat: add functions support

## [0.3.0]

- BREAKING: update gotrue_client to [v0.2.0](https://github.com/supabase-community/gotrue-dart/blob/main/CHANGELOG.md#020)

## [0.2.15]

- chore: update gotrue_client to v0.1.6

## [0.2.14]

- chore: update gotrue_client to v0.1.5
- chore: update postgrest to v0.1.9
- chore: update realtime_client to v0.1.15
- chore: update storage_client to v0.0.6+2

## [0.2.13]

- chore: update realtime_client to v0.1.14

## [0.2.12]

- fix: changedAccessToken never initialized error when changing account
- fix: stream replaces the correct row

## [0.2.11]

- feat: listen for auth event and handle token changed
- chore: update gotrue to v0.1.3
- chore: update realtime_client to v0.1.13
- fix: use PostgrestFilterBuilder type for rpc
- docs: correct stream method documentation

## [0.2.10]

- fix: type 'Null' is not a subtype of type 'List<dynamic>' in type cast

## [0.2.9]

- feat: add user_token when creating realtime channel subscription
- fix: typo on Realtime data as Stream on readme.md

## [0.2.8]

- chore: update gotrue to v0.1.2
- chore: update storage_client to v0.0.6
- fix: cleanup imports in `supabase_stream_builder` to remove analysis error

## [0.2.7]

- chore: update postgrest to v0.1.8

## [0.2.6]

- chore: add `X-Client-Info` header
- chore: update gotrue to v0.1.1
- chore: update postgrest to v0.1.7
- chore: update realtime_client to v0.1.11
- chore: update storage_client to v0.0.5

## [0.2.5]

- chore: update realtime_client to v0.1.10

## [0.2.4]

- chore: update postgrest to v0.1.6

## [0.2.3]

- chore: update realtime_client to v0.1.9

## [0.2.2]

- fix: bug where `stream()` tries to emit data when `StreamController` is closed

## [0.2.1]

- chore: update realtime_client to v0.1.8

## [0.2.0]

- feat: added `stream()` method to listen to realtime updates as stream

## [0.1.0]

- chore: update gotrue to v0.1.0
- feat: add phone auth

## [0.0.8]

- chore: update postgrest to v0.1.5
- chore: update storage_client to v0.0.4

## [0.0.7]

- chore: update realtime_client to v0.1.7

## [0.0.6]

- chore: update realtime_client to v0.1.6

## [0.0.5]

- chore: update realtime_client to v0.1.5

## [0.0.4]

- chore: update realtime_client to v0.1.4

## [0.0.3]

- chore: update storage_client to v0.0.3

## [0.0.2]

- chore: update gotrue to v0.0.7
- chore: update postgrest to v0.1.4
- chore: update storage_client to v0.0.2

## [0.0.1]

- chore: update storage_client to v0.0.1
- Initial Release

## [0.0.1-dev.27]

- chore: update realtime to v0.1.3

## [0.0.1-dev.26]

- chore: update gotrue to v0.0.6

## [0.0.1-dev.25]

- chore: update realtime to v0.1.2

## [0.0.1-dev.24]

- fix: export postgrest classes

## [0.0.1-dev.23]

- chore: update realtime to v0.1.1

## [0.0.1-dev.22]

- chore: update gotrue to v0.0.5

## [0.0.1-dev.21]

- chore: update realtime to v0.1.0

## [0.0.1-dev.20]

- chore: update gotrue to v0.0.4

## [0.0.1-dev.19]

- chore: update gotrue to v0.0.3

## [0.0.1-dev.18]

- chore: update gotrue to v0.0.2
- chore: update postgrest to v0.1.3
- chore: update storage_client to v0.0.1-dev.3

## [0.0.1-dev.17]

- chore: update realtime to v0.0.9
- chore: update postgrest to v0.1.2

## [0.0.1-dev.16]

- chore: update storage_client to v0.0.1-dev.2
- chore: update gotrue to v0.0.1

## [0.0.1-dev.15]

- chore: update postgrest to v0.1.1
- chore: update gotrue to v0.0.1-dev.11

## [0.0.1-dev.14]

- refactor: use storage_client package v0.0.1-dev.1

## [0.0.1-dev.13]

- fix: package dependencies

## [0.0.1-dev.12]

- feat: implement Storage API
- chore: update postgrest to v0.1.0
- chore: update gotrue to v0.0.1-dev.10

## [0.0.1-dev.11]

- fix: aligned exports with supabase-js

## [0.0.1-dev.10]

- chore: migrate to null-safety

## [0.0.1-dev.9]

- fix: rpc to return PostgrestTransformBuilder
- chore: update postgrest to v0.0.7
- chore: expose gotrue User as AuthUser
- chore: expose 'RealtimeSubscription'
- chore: update lib description

## [0.0.1-dev.8]

- fix: rpc method missing param name

## [0.0.1-dev.8]

- chore: update postgrest ^0.0.6

## [0.0.1-dev.6]

- chore: update gotrue v0.0.1-dev.7
- chore: update realtime_client v0.0.7

## [0.0.1-dev.5]

- refactor: SupabaseRealtimePayload variable names

## [0.0.1-dev.4]

- fix: export SupabaseEventTypes
- chore: include realtime supscription code in example

## [0.0.1-dev.3]

- fix: SupabaseRealtimeClient client and payload parsing bug
- update: realtime_client to v0.0.5

## [0.0.1-dev.2]

- fix: builder method not injecting table in the url

## [0.0.1-dev.1]

- Initial pre-release.
