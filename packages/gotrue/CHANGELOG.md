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
