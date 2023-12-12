# `Supabase Flutter`

Monorepo containing all [Supabase](https://supabase.com/) libraries for Flutter.

- [postgrest](https://github.com/supabase/supabase-flutter/tree/main/packages/postgrest)
- [gotrue](https://github.com/supabase/supabase-flutter/tree/main/packages/gotrue)
- [realtime_client](https://github.com/supabase/supabase-flutter/tree/main/packages/realtime_client)
- [storage_client](https://github.com/supabase/supabase-flutter/tree/main/packages/storage_client)
- [functions_client](https://github.com/supabase/supabase-flutter/tree/main/packages/functions_client)
- [supabase](https://github.com/supabase/supabase-flutter/tree/main/packages/supabase)
- [supabase_flutter](https://github.com/supabase/supabase-flutter/tree/main/packages/supabase_flutter)
- [yet_another_json_isolate](https://github.com/supabase/supabase-flutter/tree/main/packages/yet_another_json_isolate)

Documentation: https://supabase.com/docs/reference/dart/introduction

---

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

> `debug` is optional. It's enabled by default if you're running the app in debug mode (`flutter run --debug`).

## Usage example

### [Authentication](https://supabase.com/docs/guides/auth)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class MyWidget extends StatefulWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final StreamSubscription<AuthState> _authSubscription;
  User? _user;

  @override
  void initState() {
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      setState(() {
        _user = session?.user;
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        supabase.auth.signInWithOtp(email: 'my_email@example.com');
      },
      child: const Text('Login'),
    );
  }
}
```

#### Native Sign in with Apple example

Before you run the code, you need to [register your app ID with Apple](https://developer.apple.com/help/account/manage-identifiers/register-an-app-id/) with the `Sign In with Apple` capability selected, and add the bundle ID to your Supabase dashboard in `Authentication -> Providers -> Apple`.

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

return supabase.auth.signInWithApple();
```

`signInWithApple()` is only supported on iOS and on macOS. Other platforms can use the `signInWithOAuth()` method to perform Apple login.

The `signInWithApple` method is currently experimental and is subject to change. Follow [this issue](https://github.com/supabase/supabase-flutter/issues/399) for platform support progress.

### [Database](https://supabase.com/docs/guides/database)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class MyWidget extends StatefulWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  // Persisting the future as local variable to prevent refetching upon rebuilds.
  final Future<dynamic> _future = supabase
      .from('countries')
      .select()
      .order('name', ascending: true);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        // return your widget with the data from snapshot
      },
    );
  }
}
```

### [Realtime](https://supabase.com/docs/guides/realtime)

#### Realtime data as `Stream`

To receive realtime updates, you have to first enable Realtime on from your Supabase console. You can read more [here](https://supabase.com/docs/guides/api#realtime-api) on how to enable it.

> **Warning**
> When using `stream()` with a `StreamBuilder`, make sure to persist the stream value as a variable in a `StatefulWidget` instead of directly constructing the stream within your widget tree, which could cause rapid rebuilds that will lead to losing realtime connection.

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class MyWidget extends StatefulWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  // Persisting the future as local variable to prevent refetching upon rebuilds.
  final stream = supabase.from('countries').stream(primaryKey: ['id']);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
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

Broadcast lets you send and receive low latency messages between connected clients by bypassing the database.

```dart
final myChannel = supabase.channel('my_channel');

// Subscribe to `cursor-pos` broadcast event
 myChannel.on(
  RealtimeListenTypes.broadcast,
  ChannelFilter(event: 'cursor-pos'),
  (payload, [ref]) {
    // Do something fun or interesting when there is an change on the database
  },
 ).subscribe();
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
}).subscribe((status, error) async {
  if (status == RealtimeSubscribeStatus.subscribed) {
    // Send the current user's state upon subscribing
    final status = await myChannel
        .track({'online_at': DateTime.now().toIso8601String()});
  }
});
```

### [Storage](https://supabase.com/docs/guides/storage)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final file = File('example.txt');
        file.writeAsStringSync('File content');
        supabase.storage
            .from('my_bucket')
            .upload('my/path/to/files/example.txt', file);
      },
      child: const Text('Upload'),
    );
  }
}
```

### [Edge Functions](https://supabase.com/docs/guides/functions)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class MyWidget extends StatefulWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  // Persisting the future as local variable to prevent refetching upon rebuilds.
  final future = supabase.functions.invoke('get_countries');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        // return your widget with the data from snapshot
      },
    );
  }
}
```

## Authentication Deep Dive

Using this package automatically persists the auth state on local storage.
It also helps you handle authentication with deep link from 3rd party service like Google, Github, Twitter...

### Email authentication

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> signIn(String email, String password) async {
  final response = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
  final Session? session = response.session;
  final User? user = response.user;
}
```

### signInWithProvider

This method will automatically launch the auth url and open a browser for user to sign in with 3rd party login.

```dart
supabase.auth.signInWithOAuth(
  Provider.google,
  redirectTo: 'io.supabase.flutter://reset-callback/',
);
```

### Custom LocalStorage

As default, `supabase_flutter` uses [`Shared preferences`](https://pub.dev/packages/shared_preferences) to persist the user session.

However, you can use any other methods by creating a `LocalStorage` implementation. For example, we can use [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) plugin to store the user session in a secure storage.

```dart
// Define the custom LocalStorage implementation
class MockLocalStorage extends LocalStorage {

  final storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async {
    return storage.containsKey(key: supabasePersistSessionKey);
  }

  @override
  Future<bool> hasAccessToken() async {
    return storage.read(key: supabasePersistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    return storage.write(key: supabasePersistSessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    return storage.delete(key: supabasePersistSessionKey);
  }
}

// use it when initializing
Supabase.initialize(
  ...
  authOptions: FlutterAuthClientOptions(
    localStorage: const EmptyLocalStorage(),
  ),
);
```

You can also use `EmptyLocalStorage` to disable session persistence:

```dart
Supabase.initialize(
  // ...
  authOptions: FlutterAuthClientOptions(
    localStorage: const EmptyLocalStorage(),
  ),
);
```

## Deep link config

\*Currently supabase_flutter supports deep links on Android, iOS, Web, MacOS and Windows.

### Supabase redirect URLs config

- Go to your Supabase project Authentication Settings page.
- You need to enter your app redirect callback on `Additional Redirect URLs` field.

The redirect callback url should have this format `[YOUR_SCHEME]://[YOUR_AUTH_HOSTNAME]`

![authentication settings page](https://raw.githubusercontent.com/supabase/supabase-flutter/main/.github/images/deeplink-config.png)

### Supabase 3rd party logins config

Follow the guide https://supabase.io/docs/guides/auth#third-party-logins

#### For Android

<details>
  <summary>How to setup</summary>

Deep Links can have any custom scheme. The downside is that any app can claim a scheme, so make sure yours are as unique as possible, eg. `HST0000001://host.com`.

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
          android:scheme="[YOUR_SCHEME]"
          android:host="[YOUR_HOST]" />
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

Custom URL schemes can have... any custom scheme and there is no host specificity, nor entitlements or a hosted file. The downside is that any app can claim any scheme, so make sure yours is as unique as possible, eg. `hst0000001` or `myIncrediblyAwesomeScheme`.

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

This allows for your app to be started from `YOUR_SCHEME://ANYTHING` links.

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
