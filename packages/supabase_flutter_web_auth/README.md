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

```dart file
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter_web_auth/supabase_flutter_web_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    publishableKey: 'your-publishable-key',
    authOptions: const FlutterAuthClientOptions(
      oauthLauncher: FlutterWebAuth2OAuthLauncher(),
    ),
  );
  runApp(const MaterialApp(home: Placeholder()));
}
```

`signInWithOAuth`, `signInWithSSO`, and `linkIdentity` are called exactly as
documented in `supabase_flutter`; the new `preferEphemeral` parameter (ignored
by the default launcher) requests a session that does not share cookies with
the system browser.

Observe the result on `onAuthStateChange`, as with the default launcher:

- A successful sign-in emits `AuthSignedIn`.
- A failed code exchange, for example an expired flow, arrives as an
  `AuthException` error on the stream, so pass `onError` to the listener.
- When the user closes the session without signing in, the method returns
  `false` and nothing is emitted.

```dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> signIn(SupabaseClient supabase) async {
  final launched = await supabase.auth.signInWithOAuth(
    OAuthProvider.github,
    redirectTo: kIsWeb ? null : 'com.example.myapp://oauth-callback',
  );
  if (!launched) {
    print('Sign-in was cancelled');
  }
}
```

On web the launcher redirects the current page, like the default launcher.
Pass an `https` URL of the app that is on the project's redirect URL allow
list, or leave `redirectTo` null to return to the project's Site URL.

## Setup

### Android

Register the `flutter_web_auth_2` callback activity for your redirect URL
in `android/app/src/main/AndroidManifest.xml`, and set
`android:taskAffinity=""` on it and on `.MainActivity`, as `flutter_web_auth_2`
requires:

```xml
<activity
    android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
    android:exported="true"
    android:taskAffinity="">
  <intent-filter android:label="flutter_web_auth_2">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.example.myapp" android:host="oauth-callback" />
  </intent-filter>
</activity>
```

Replace the scheme and host with those of the `redirectTo` URL you pass to
`signInWithOAuth`/`signInWithSSO`/`linkIdentity`.

If `.MainActivity` already has an intent filter for magic links or other
email redirects, make sure it cannot match the callback URL. When that filter
names a host, give the callback activity a different host. When it only names
a scheme, it matches every host of that scheme, so give the callback activity
a different scheme or add a host to the `.MainActivity` filter. When both activities match the same URL, the
callback can be delivered to the wrong one, and `app_links` and this launcher
can both try to exchange the same code. Add the new redirect URL to the
project's redirect URL allow list too.

If the provider page closes after signing in but the method returns `false`,
the callback did not reach the callback activity: `flutter_web_auth_2`
reports a session that is still open when the app resumes as cancelled.
Check `android:taskAffinity=""` and that the intent filter matches the
`redirectTo` scheme and host.

### iOS and macOS

No extra configuration is needed for a custom URL scheme redirect. For an
`https` universal link `redirectTo`, set up associated domains as usual.

### Linux and Windows

The flow runs in an embedded webview window provided by
[`desktop_webview_window`](https://pub.dev/packages/desktop_webview_window),
which needs a system webview:

- Linux builds need the WebKitGTK 4.1 and libsoup 3 development packages, for
  example on Ubuntu or Debian:

  ```shell
  sudo apt-get install libwebkit2gtk-4.1-dev libsoup-3.0-dev
  ```

  Users need the matching runtime libraries, `libwebkit2gtk-4.1-0` and
  `libsoup-3.0-0`.
- Windows needs the
  [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2),
  which ships with Windows 11 but may be missing on Windows 10. Without it,
  sign-in throws `StateError('Webview is not available')`.
