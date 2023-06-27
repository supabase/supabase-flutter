# `supabase_flutter`

[![pub package](https://img.shields.io/pub/v/supabase_flutter.svg)](https://pub.dev/packages/supabase_flutter)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

---

Flutter Client library for [Supabase](https://supabase.com/).

- Documentation: https://supabase.com/docs/reference/dart/introduction

## Platform Support

Except Linux, all platforms are fully supported. Linux only doesn't support deeplinks, because of our dependency [app_links](https://pub.dev/packages/app_links). All other features are supported.

## Getting Started

Import the package:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
```

Initialize `Supabase` before using it:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
  );

  runApp(MyApp());
}

// It's handy to then extract the Supabase client in a variable for later uses
final supabase = Supabase.instance.client;
```

## Usage example

### [Authentication](https://supabase.com/docs/guides/auth)

```dart
final supabase = Supabase.instance.client;

// Email and password sign up
await supabase.auth.signUp(
  email: email,
  password: password,
);

// Email and password login
await supabase.auth.signInWithPassword(
  email: email,
  password: password,
);

// Magic link login
await supabase.auth.signInWithOtp(email: 'my_email@example.com');

// Listen to auth state changes
supabase.auth.onAuthStateChange.listen((data) {
  final AuthChangeEvent event = data.event;
  final Session? session = data.session;
  // Do something when there is an auth event
});
```

#### Native Apple Sign in

You can perform native Apple sign in on iOS and MacOS using [sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple).

Although [sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple) plugin is compatible with Android and Web, setting it up requires you to host your own backend, so it is recommended to use `signInWithOAuth()` method to perform Apple sign in on Android, Web and other platforms.

First, you need to [register your app ID with Apple](https://developer.apple.com/help/account/manage-identifiers/register-an-app-id/) with the `Sign In with Apple` capability selected, and add the bundle ID to your Supabase dashboard in `Authentication -> Providers -> Apple -> IOS Bundle ID` before performing native Apple sign in. You can pass multiple bundle IDs as comma separated string.

Then add [sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple) to your app. You also need [crypto](https://pub.dev/packages/crypto) package to hash nonce.

```bash
flutter pub add sign_in_with_apple crypto
```

With that you are ready to perform Apple sign in like this:

```dart
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

String _generateRandomString() {
  final random = Random.secure();
  return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
}

Future<AuthResponse> signInWithApple() {

  final rawNonce = _generateRandomString();
  final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: hashedNonce,
  );

  final idToken = credential.identityToken;
  if (idToken == null) {
    throw 'Could not find ID Token from generated credential.';
  }

  return signInWithIdToken(
    provider: Provider.apple,
    idToken: idToken,
    nonce: rawNonce,
  );
}
```

`signInWithApple()` is only supported on iOS and on macOS. Use the `signInWithOAuth()` method to perform web-based Apple sign in on other platforms.

#### Native Google sign in

You can perform native Google sign in on Android and iOS using [flutter_appauth](https://pub.dev/packages/flutter_appauth).

First, you need to create a client ID in your Google Cloud console and add them to your Supabase dashboard in `Authentication -> Providers -> Google -> Authorized Client IDs`. You can add multiple client IDs as comma separated string.

- [Steps to obtain Android client ID](https://developers.google.com/identity/sign-in/android/start-integrating#configure_a_project)
- [Steps to obtain iOS client ID](https://developers.google.com/identity/sign-in/ios/start-integrating#get_an_oauth_client_id)

Second, add [flutter_appauth](https://pub.dev/packages/flutter_appauth) to your app and complete the [setup steps](https://pub.dev/packages/flutter_appauth#android-setup). You also need [crypto](https://pub.dev/packages/crypto) package to hash nonce.

```bash
flutter pub add flutter_appauth crypto
```

At this point you can perform native Google sign in using the following code. Make sure to replace the `clientId` and `applicationId` with your own.

```dart
import 'package:crypto/crypto.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

/// Function to generate a random 16 character string.
String _generateRandomString() {
  final random = Random.secure();
  return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
}

Future<AuthResponse> signInWithGoogle() {
  // Just a random string
  final rawNonce = _generateRandomString();
  final hashedNonce =
      sha256.convert(utf8.encode(rawNonce)).toString();

  /// TODO: update the client ID with your own
  ///
  /// Client ID that you registered with Google Cloud.
  /// You will have two different values for iOS and Android.
  const clientId = 'YOUR_CLIENT_ID_HERE';

  /// TODO: Replace the following with your own app details
  ///
  /// Application ID or Bundle ID for your app.
  /// If the application ID and Bundle ID is different for Android and iOS,
  /// make sure the value here matches the platform you are running on.
  const applicationId = 'com.supabase.example';

  /// Fixed value for google login
  const redirectUrl = '$applicationId:/google_auth';

  /// Fixed value for google login
  const discoveryUrl =
      'https://accounts.google.com/.well-known/openid-configuration';

  // authorize the user by opening the concent page
  final result = await appAuth.authorize(
    AuthorizationRequest(
      clientId,
      redirectUrl,
      discoveryUrl: discoveryUrl,
      nonce: hashedNonce,
      scopes: [
        'openid',
        'email',
      ],
    ),
  );

  if (result == null) {
    throw 'No result';
  }

  // Request the access and id token to google
  final tokenResult = await appAuth.token(
    TokenRequest(
      clientId,
      redirectUrl,
      authorizationCode: result.authorizationCode,
      discoveryUrl: discoveryUrl,
      codeVerifier: result.codeVerifier,
      nonce: result.nonce,
      scopes: [
        'openid',
        'email',
      ],
    ),
  );

  final idToken = tokenResult?.idToken;

  if (idToken == null) {
    throw 'No idToken';
  }

  return supabase.auth.signInWithIdToken(
    provider: Provider.google,
    idToken: idToken,
    nonce: rawNonce,
  );
}
```

### OAuth login

For providers other than Apple or Google, you need to use the `signInWithOAuth()` method to perform OAuth login. This will open the web browser to perform the OAuth login.

Use the `redirectTo` parameter to redirect the user to a deep link to bring the user back to the app. Learn more about setting up deep links in [Deep link config](#deep-link-config).

```dart
// Perform web based OAuth login
await supabase.auth.signInWithOAuth(
  Provider.github,
  redirectTo: kIsWeb ? null : 'io.supabase.flutter://callback',
);

// Listen to auth state changes in order to detect when ther OAuth login is complete.
supabase.auth.onAuthStateChange.listen((data) {
  final AuthChangeEvent event = data.event;
  if(event == AuthChangeEvent.signIn) {
    // Do something when user sign in
  }
});
```

### [Database](https://supabase.com/docs/guides/database)

Database methods are used to perform basic CRUD operations using the Supabase REST API. Full list of supported operators can be found [here](https://supabase.com/docs/reference/dart/select).

```dart
// Select data with filters
final data = await supabase
  .from('cities')
  .select()
  .eq('country_id', 1) // equals filter
  .neq('name', 'The shire'); // does not equal filter

// Insert a new row
await supabase
  .from('cities')
  .insert({'name': 'The Shire', 'country_id': 554});
```

### [Realtime](https://supabase.com/docs/guides/realtime)

#### Realtime data as `Stream`

To receive realtime updates, you have to first enable Realtime on from your Supabase console. You can read more [here](https://supabase.com/docs/guides/api#realtime-api) on how to enable it.

> **Warning**
> When using `stream()` with a `StreamBuilder`, make sure to persist the stream value as a variable in a `StatefulWidget` instead of directly constructing the stream within your widget tree, which could cause rapid rebuilds that will lead to losing realtime connection.

```dart
class MyWidget extends StatefulWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  // Persisting the future as local variable to prevent refetching upon rebuilds.
  final List<Map<String, dynamic>> _stream = supabase.from('countries').stream(primaryKey: ['id']);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        // return your widget with the data from snapshot
      },
    );
  }
}
```

#### [Postgres Changes](https://supabase.com/docs/guides/realtime#postgres-changes)

You can get notified whenever there is a change in your Supabase tables.

```dart
final myChannel = supabase.channel('my_channel');

myChannel.on(
    RealtimeListenTypes.postgresChanges,
    ChannelFilter(
      event: '*',
      schema: 'public',
      table: 'countries',
    ), (payload, [ref]) {
  // Do something fun or interesting when there is an change on the database
}).subscribe();
```

#### [Broadcast](https://supabase.com/docs/guides/realtime#broadcast)

Broadcast lets you send and receive low latency messages between connected clients without bypassing the database.

```dart
final myChannel = supabase.channel('my_channel');

// Subscribe to `cursor-pos` broadcast event
myChannel.on(RealtimeListenTypes.broadcast,
    ChannelFilter(event: 'cursor-pos'), (payload, [ref]) {
  // Do something fun or interesting when there is an change on the database
}).subscribe();

// Send a broadcast message to other connected clients
await myChannel.send(
  type: RealtimeListenTypes.broadcast,
  event: 'cursor-pos',
  payload: {'x': 30, 'y': 50},
);
```

### [Presence](https://supabase.com/docs/guides/realtime#presence)

Presence let's you easily create "I'm online" feature.

```dart
final myChannel = supabase.channel('my_channel');

// Subscribe to presence events
myChannel.on(
    RealtimeListenTypes.presence, ChannelFilter(event: 'sync'),
    (payload, [ref]) {
  final onlineUsers = myChannel.presenceState();
  // handle sync event
}).on(RealtimeListenTypes.presence, ChannelFilter(event: 'join'),
    (payload, [ref]) {
  // New users have joined
}).on(RealtimeListenTypes.presence, ChannelFilter(event: 'leave'),
    (payload, [ref]) {
  // Users have left
}).subscribe(((status, [_]) async {
  if (status == 'SUBSCRIBED') {
    // Send the current user's state upon subscribing
    final status = await myChannel
        .track({'online_at': DateTime.now().toIso8601String()});
  }
}));
```

### [Storage](https://supabase.com/docs/guides/storage)

```dart
final file = File('example.txt');
file.writeAsStringSync('File content');
await supabase.storage
  .from('my_bucket')
  .upload('my/path/to/files/example.txt', file);

// Use the `uploadBinary` method to upload files on Flutter web
await supabase.storage
  .from('my_bucket')
  .uploadBinary('my/path/to/files/example.txt', file.readAsBytesSync());
```

### [Edge Functions](https://supabase.com/docs/guides/functions)

```dart
final data = await supabase.functions.invoke('get_countries');
```

## Deep links

### Why do you need to setup deep links

You need to setup deep links if you want your native app to open when a user clicks on a link. User clicking on a link and the app opens up happens in a few scenarios when you use Supabase auth, and in order to support those scenarios, you need to setup deep links.

### When do you need to setup deep links

You need to setup deep links when want any of the followings

- Magic link login
- Have `confirm email` enabled and are using email login
- Resetting password for email login
- Calling `.signInWithOAuth()` method

\*Currently supabase_flutter supports deep links on Android, iOS, Web, MacOS and Windows.

### Deep link config

- Go to your Supabase project Authentication Settings page.
- You need to enter your app redirect callback on `Additional Redirect URLs` field.

The redirect callback url should have this format `[YOUR_SCHEME]://[YOUR_HOSTNAME]`. Here, `io.supabase.flutterdemo://login-callback` is just an example, you can choose whatever you would like for `YOUR_SCHEME` and `YOUR_HOSTNAME` as long as the scheme is unique across the user's device. For this reason, typically a reverse domain of your website is used.

![authentication settings page](https://raw.githubusercontent.com/supabase/supabase-flutter/main/.github/images/deeplink-config.png)

### Platform specific config

Follow the guide https://supabase.io/docs/guides/auth#third-party-logins

#### For Android

<details>
  <summary>How to setup</summary>

```xml
<manifest ...>
  <!-- ... other tags -->
  <application ...>
    <activity ...>
      <!-- ... other tags -->

      <!-- Deep Links -->
      <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <!-- Accepts URIs that begin with YOUR_SCHEME://YOUR_HOST -->
        <data
          android:scheme="YOUR_SCHEME"
          android:host="YOUR_HOSTNAME" />
      </intent-filter>
    </activity>
  </application>
</manifest>
```

The `android:host` attribute is optional for Deep Links.

For more info: https://developer.android.com/training/app-links/deep-linking

</details>

#### For iOS

<details>
  <summary>How to setup</summary>

For **Custom URL schemes** you need to declare the scheme in
`ios/Runner/Info.plist` (or through Xcode's Target Info editor,
under URL Types):

```xml
<!-- ... other tags -->
<plist>
<dict>
  <!-- ... other tags -->
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>[YOUR_SCHEME]</string>
      </array>
    </dict>
  </array>
  <!-- ... other tags -->
</dict>
</plist>
```

For more info: https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app

</details>

#### For Windows

<details>
  <summary>How to setup</summary>

Setting up deep links in Windows has few more steps than other platforms.
[Learn more](https://pub.dev/packages/app_links#windows)

Declare this method in <PROJECT_DIR>\windows\runner\win32_window.h

```cpp
  // Dispatches link if any.
  // This method enables our app to be with a single instance too.
  // This is optional but mandatory if you want to catch further links in same app.
  bool SendAppLinkToInstance(const std::wstring& title);
```

Add this inclusion at the top of <PROJECT_DIR>\windows\runner\win32_window.cpp

```cpp
#include "app_links_windows/app_links_windows_plugin.h"
```

Add this method in <PROJECT_DIR>\windows\runner\win32_window.cpp

```cpp
bool Win32Window::SendAppLinkToInstance(const std::wstring& title) {
  // Find our exact window
  HWND hwnd = ::FindWindow(kWindowClassName, title.c_str());

  if (hwnd) {
    // Dispatch new link to current window
    SendAppLink(hwnd);

    // (Optional) Restore our window to front in same state
    WINDOWPLACEMENT place = { sizeof(WINDOWPLACEMENT) };
    GetWindowPlacement(hwnd, &place);
    switch(place.showCmd) {
      case SW_SHOWMAXIMIZED:
          ShowWindow(hwnd, SW_SHOWMAXIMIZED);
          break;
      case SW_SHOWMINIMIZED:
          ShowWindow(hwnd, SW_RESTORE);
          break;
      default:
          ShowWindow(hwnd, SW_NORMAL);
          break;
    }
    SetWindowPos(0, HWND_TOP, 0, 0, 0, 0, SWP_SHOWWINDOW | SWP_NOSIZE | SWP_NOMOVE);
    SetForegroundWindow(hwnd);
    // END Restore

    // Window has been found, don't create another one.
    return true;
  }

  return false;
}
```

Add the call to the previous method in `CreateAndShow`

```cpp
bool Win32Window::CreateAndShow(const std::wstring& title,
                                const Point& origin,
                                const Size& size) {
if (SendAppLinkToInstance(title)) {
    return false;
}

...
```

At this point, you can register your own scheme.  
 On Windows, URL protocols are setup in the Windows registry.

This package won't do it for you.

You can achieve it with [url_protocol](https://pub.dev/packages/url_protocol) inside you app.

The most relevant solution is to include those registry modifications into your installer to allow
for deregistration.

</details>

#### For Mac OS

<details>
  <summary>How to setup</summary>

Add this XML chapter in your macos/Runner/Info.plist inside <plist version="1.0"><dict> chapter:

```xml
<!-- ... other tags -->
<plist version="1.0">
<dict>
  <!-- ... other tags -->
  <key>CFBundleURLTypes</key>
  <array>
      <dict>
          <key>CFBundleURLName</key>
          <!-- abstract name for this URL type (you can leave it blank) -->
          <string>sample_name</string>
          <key>CFBundleURLSchemes</key>
          <array>
              <!-- your schemes -->
              <string>sample</string>
          </array>
      </dict>
  </array>
  <!-- ... other tags -->
</dict>
</plist>
```

</details>

### Custom LocalStorage

As default, `supabase_flutter` uses [`hive`](https://pub.dev/packages/hive) to persist the user session. Encryption is disabled by default, since an unique encryption key is necessary, and we can not define it. To set an `encryptionKey`, do the following:

```dart
Future<void> main() async {
  // set it before initializing
  HiveLocalStorage.encryptionKey = 'my_secure_key';
  await Supabase.initialize(...);
}
```

**Note** the key must be the same. There is no check if the encryption key is correct. If it isn't, there may be unexpected behavior. [Learn more](https://docs.hivedb.dev/#/advanced/encrypted_box) about encryption in hive.

However you can use any other methods by creating a `LocalStorage` implementation. For example, we can use [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) plugin to store the user session in a secure storage.

```dart
// Define the custom LocalStorage implementation
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage() : super(
    initialize: () async {},
    hasAccessToken: () {
      const storage = FlutterSecureStorage();
      return storage.containsKey(key: supabasePersistSessionKey);
    }, accessToken: () {
      const storage = FlutterSecureStorage();
      return storage.read(key: supabasePersistSessionKey);
    }, removePersistedSession: () {
      const storage = FlutterSecureStorage();
      return storage.delete(key: supabasePersistSessionKey);
    }, persistSession: (String value) {
      const storage = FlutterSecureStorage();
      return storage.write(key: supabasePersistSessionKey, value: value);
    },
  );
}

// use it when initializing
Supabase.initialize(
  ...
  localStorage: SecureLocalStorage(),
);
```

You can also use `EmptyLocalStorage` to disable session persistence:

```dart
Supabase.initialize(
  // ...
  localStorage: const EmptyLocalStorage(),
);
```

---

## Contributing

- Fork the repo on [GitHub](https://github.com/supabase/supabase-flutter)
- Clone the project to your own machine
- Commit changes to your own branch
- Push your work back up to your fork
- Submit a Pull request so that we can review your changes and merge

## License

This repo is licenced under MIT.

## Resources

- [Quickstart: Flutter](https://supabase.com/docs/guides/with-flutter)
- [Flutter Tutorial: building a Flutter chat app](https://supabase.com/blog/flutter-tutorial-building-a-chat-app)
- [Flutter Tutorial - Part 2: Authentication and Authorization with RLS](https://supabase.com/blog/flutter-authentication-and-authorization-with-rls)
