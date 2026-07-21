# Authentication

A single app that shows every `supabase_flutter` sign in method except passkeys
(those have their own [`passkeys`](../passkeys) example). Pick a method with the
chips at the top; once signed in you land on an account screen that manages MFA
and can upgrade an anonymous user to a permanent account.

What it shows, grouped by method:

- **Email & password**: sign up, sign in and a full password reset (`signUp`,
  `signInWithPassword`, `resetPasswordForEmail`, then `verifyOTP` with
  `OtpType.recovery` and `updateUser`).
- **Magic link & email OTP**: passwordless email sign in
  (`signInWithOtp(email: ...)` then `verifyOTP(type: OtpType.email)`).
- **Phone (SMS OTP)**: passwordless phone sign in
  (`signInWithOtp(phone: ...)` then `verifyOTP(type: OtpType.sms)`).
- **OAuth social**: Google, GitHub and Apple (`signInWithOAuth`), including the
  deep-link redirect back into the app.
- **Anonymous**: `signInAnonymously`, then `updateUser` to add an email and
  password and keep the account.
- **Multi-factor authentication**: enroll, verify and remove a TOTP factor
  (`auth.mfa.enroll`, `challengeAndVerify`, `listFactors`, `unenroll`).

All Supabase calls live in
[`lib/auth_repository.dart`](lib/auth_repository.dart), kept separate from the
UI so the flows are easy to read and to drive from an integration test. The UI
just calls the repository and rebuilds from `onAuthStateChange`.

The auth providers this example needs are enabled in the shared Supabase config
in [`../supabase`](../supabase): anonymous sign in, phone (with a local test
OTP), TOTP MFA and the local mail server, all in `config.toml`. The example
stores no data of its own, so it needs no migration or seed.

## Running

From the `examples` directory, run the launcher and pick `authentication`:

```bash
./run.sh
```

Or run it directly against any project:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## Trying each method locally

- **Email & password** works out of the box; email confirmation is disabled in
  the shared config, so creating an account signs you straight in. *Forgot
  password?* sends a reset email; enter the code from it plus a new password to
  finish resetting.
- **Magic link & email OTP** and **password reset** send an email. Locally it is
  captured by the mail server, not delivered: open its web UI at
  http://localhost:54324 to read the code or link.
- **Phone (SMS OTP)** accepts the number `+15555550100` with the fixed code
  `123456`, set as a test OTP in `config.toml`, so no SMS provider is needed.
- **OAuth social** needs each provider enabled and configured with client
  credentials in the Supabase dashboard, so the buttons only complete against a
  project set up for them.

On native platforms the OAuth, magic link and password reset flows return to the
app through a deep link. The example passes `io.supabase.authexample://login-callback/`
as the `redirectTo` (it is null on web, which uses the site URL). That URL is
already in the shared config's `additional_redirect_urls`; to actually receive
it on iOS, Android or desktop you still need to register the URL scheme with the
platform, as described in the
[deep linking guide](https://supabase.com/docs/guides/auth/native-mobile-deep-linking?platform=flutter).
- **Anonymous** works out of the box. After continuing as a guest, use *Keep
  this account* to attach an email and password.
- **MFA** works out of the box: tap *Add app*, add the shown secret to any TOTP
  authenticator, and enter the six-digit code to confirm the factor.
