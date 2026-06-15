# Passkeys example

A small Flutter web app that shows off the passkey (WebAuthn) API added to
`supabase_flutter` via `supabase.auth.passkey`.

It lets you:

- Sign in with email and password, then **register** a passkey for that account
- **Sign in** with an existing passkey (no password)
- **List**, **rename** and **delete** the passkeys on the account

## How passkeys work here

`supabase_flutter` exposes the server side of the WebAuthn ceremony. The actual
prompt (Face ID / Touch ID / Windows Hello / security key) is performed by the
platform, so each flow has two steps:

1. Ask Supabase to start the ceremony, which returns `options` and a
   `challengeId`.
2. Run the platform ceremony with those `options` to get a `credential`, then
   send it back to Supabase together with the `challengeId` to verify.

```dart
// Register a passkey for the signed in user.
final start = await supabase.auth.passkey.startRegistration();
final credential = await authenticator.create(start.options);
await supabase.auth.passkey.verifyRegistration(
  challengeId: start.challengeId,
  credential: credential,
);

// Sign in with a passkey.
final start = await supabase.auth.passkey.startAuthentication();
final credential = await authenticator.get(start.options);
await supabase.auth.passkey.verifyAuthentication(
  challengeId: start.challengeId,
  credential: credential,
);
```

This example performs the ceremony in the browser with the standard
`navigator.credentials` WebAuthn JSON API (see
[`lib/passkey_authenticator.dart`](lib/passkey_authenticator.dart)). On iOS,
Android and macOS you would instead use a passkey plugin, which produces and
consumes the same W3C WebAuthn JSON format.

## Prerequisites

Passkeys are a BETA feature and must be enabled on the project:

- **Local stack:** already enabled in the shared
  [`supabase/config.toml`](../supabase/config.toml), so the launcher works out of
  the box.
- **Hosted project:** enable it in the Supabase Dashboard under
  **Authentication > Configuration > Passkeys**.

You also need a browser and device that support WebAuthn (all current browsers
do).

## Run it

The easiest way is the [examples launcher](../README.md), which boots a local
Supabase stack and runs this example with the right credentials:

```bash
cd examples/launcher
dart pub get
dart run
```

Alternatively, run it directly against any project by passing the URL and
publishable key as `--dart-define`s:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Then:

1. Enter an email and password and tap **Create an account** (or **Sign in
   with password** if you already have one).
2. Tap **Register a passkey** and follow the browser prompt.
3. Sign out and tap **Sign in with a passkey** to log back in without a
   password.

> Passkeys are bound to the domain (relying party) they were created on, so a
> passkey registered on `localhost` only works on `localhost`.
