# supabase_flutter_web_auth

Runs [supabase_flutter](https://pub.dev/packages/supabase_flutter)'s
`signInWithOAuth`, `signInWithSSO`, and `linkIdentity` flows through a system
web authentication session (`ASWebAuthenticationSession` on iOS/macOS, Custom
Tabs on Android) instead of a plain browser launch. On Linux and Windows there
is no equivalent OS session, so the flow runs in an embedded webview window
instead (see Setup below).

By default, `supabase_flutter` opens the sign-in URL with `url_launcher`. That
browser surface does not close itself when the OAuth redirect returns to the
app, so the user is left on a blank page after a successful sign-in and has to
dismiss it manually. This package's launcher always auto-dismisses once the
redirect arrives. On iOS/macOS and Android it also shares cookies with the
system browser, so a user already signed in to a provider elsewhere isn't
asked to sign in again; the embedded webview used on Linux and Windows has its
own separate cookie store and does not share that session.

This behavior isn't the default in `supabase_flutter` because achieving it
pulls in `flutter_web_auth_2` and, on Linux/Windows, its own embedded-webview
dependency. Add this package only if you want that trade-off.

## Usage

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter_web_auth/supabase_flutter_web_auth.dart';

await Supabase.initialize(
  url: 'https://your-project.supabase.co',
  publishableKey: 'your-publishable-key',
  authOptions: const FlutterAuthClientOptions(
    oauthLauncher: FlutterWebAuth2OAuthLauncher(),
  ),
);
```

`signInWithOAuth`, `signInWithSSO`, and `linkIdentity` are called exactly as
documented in `supabase_flutter`; the new `preferEphemeral` parameter (ignored
by the default launcher) requests a session that does not share cookies with
the system browser.

## Setup

### Android

Register the `flutter_web_auth_2` callback activity for your redirect scheme
in `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
    android:exported="true">
  <intent-filter android:label="flutter_web_auth_2">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="my-scheme" />
  </intent-filter>
</activity>
```

Replace `my-scheme` with the scheme of the `redirectTo` URL you pass to
`signInWithOAuth`/`signInWithSSO`/`linkIdentity`.

### iOS and macOS

No extra configuration is needed for a custom URL scheme redirect. For an
`https` universal link `redirectTo`, set up associated domains as usual.

### Linux and Windows

No native configuration is needed; the flow runs in an embedded webview
window provided by `flutter_web_auth_2`.
