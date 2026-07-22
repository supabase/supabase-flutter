# Passkeys example

A small Flutter web app that shows off the passkey (WebAuthn) support in
`supabase_flutter`.

It lets you:

- Sign in with email and password, then **register** a passkey for that account
- **Sign in** with an existing passkey (no password)
- **List**, **rename** and **delete** the passkeys on the account

## How passkeys work here

`supabase_flutter` performs the whole WebAuthn ceremony for you, including the
platform prompt (Face ID / Touch ID / Windows Hello / security key), so the
example just calls two methods:

```dart
// Register a passkey for the signed in user.
await supabase.auth.registerPasskey();

// Sign in with a passkey.
await supabase.auth.signInWithPasskey();

// Manage passkeys with the server side API.
final passkeys = await supabase.auth.passkey.list();
await supabase.auth.passkey.update(passkeyId: passkeys.first.id, friendlyName: 'My phone');
await supabase.auth.passkey.delete(passkeyId: passkeys.first.id);
```

The ceremony is driven by the
[`passkeys`](https://pub.dev/packages/passkeys) plugin, which needs some setup
per platform that the library cannot do for you. This web example loads the
plugin's JavaScript bundle in [`web/index.html`](web/index.html); for iOS,
Android and macOS see the
[`supabase_flutter` README](../../packages/supabase_flutter/README.md#passkeys).

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
cd examples
./run.sh
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

## Integration test

[`integration_test/passkeys_test.dart`](integration_test/passkeys_test.dart) is
an end-to-end test that drives the app widgets against the local stack: it
creates an account, lands on the passkey management screen, signs out, tries a
wrong password and signs back in.

The WebAuthn ceremony itself (`registerPasskey` / `signInWithPasskey`) drives a
platform authenticator prompt that cannot be automated headlessly, so it is
exercised manually with the steps above rather than in this test.

With the local stack running, pass the same defines the app uses and run it on a
device (integration tests need one, so `-d macos`, an emulator or a real device):

```bash
flutter test integration_test/passkeys_test.dart -d macos \
  --dart-define=SUPABASE_URL=http://localhost:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_LOCAL_PUBLISHABLE_KEY
```
