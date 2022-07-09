# `supabase_flutter`

Flutter package for [Supabase](https://supabase.io/).

[![pub package](https://img.shields.io/pub/v/supabase_flutter.svg)](https://pub.dev/packages/supabase_flutter)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

---

### [What is Supabase](https://supabase.io/docs/)

Supabase is an open source Firebase alternative. We are a service to:

- listen to database changes
- query your tables, including filtering, pagination, and deeply nested relationships (like GraphQL)
- create, update, and delete rows
- manage your users and their permissions
- interact with your database using a simple UI

## Status

- [x] Alpha: Under heavy development
- [x] Public Alpha: Ready for testing. But go easy on us, there will be bugs and missing functionality.
- [x] Public Beta: Stable. No breaking changes expected in this version but possible bugs.
- [ ] Public: Production-ready

## Features

- [x] Null-safety

| Platform | Email Auth | Provider Auth | Database | Realtime | Storage |
| -------- | :--------: | :-----------: | :------: | :------: | :-----: |
| Web      |     ✅     |      ✅       |    ✅    |    ✅    |   ✅    |
| Android  |     ✅     |      ✅       |    ✅    |    ✅    |   ✅    |
| iOS      |     ✅     |      ✅       |    ✅    |    ✅    |   ✅    |
| macOS    |     ✅     |      ✅       |    ✅    |    ✅    |   ✅    |
| Windows  |     ✅     |      ✅       |    ✅    |    ✅    |   ✅    |
| Linux    |     ✅     |               |    ✅    |    ✅    |   ✅    |

## Getting Started

Import the package:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
```

Intialize `Supabase` before using it:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANNON_KEY,
    authCallbackUrlHostname: 'login-callback', // optional
    debug: true // optional
  );

  runApp(MyApp());
}
```

> `authCallbackUrlHostname` is optional. It will be used to filter Supabase authentication redirect deeplink. You need to provide this param if you use deeplink for other features on the app.

> `debug` is optional. It's enabled by default if you're running the app in debug mode (`flutter run --debug`).

## Usage example

### [Database](https://supabase.io/docs/guides/database)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class MyWidget extends StatefulWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  // Persisting the future as local variable to prevent refetching upon rebuilds. 
  final Future<PostgrestResponse<dynamic>> _future = client
      .from('countries')
      .select()
      .order('name', ascending: true)
      .execute();

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

### [Realtime](https://supabase.io/docs/guides/database#realtime)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final client = Supabase.instance.client;

class MyWidget extends StatefulWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final RealtimeSubscription _subscription;
  @override
  void initState() {
    _subscription =
        client.from('countries').on(SupabaseEventTypes.all, (payload) {
      // Do something when there is an update
    }).subscribe();
    super.initState();
  }

  @override
  void dispose() {
    client.removeSubscription(_subscription);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
```

### Realtime data as `Stream`

To receive realtime updates, you have to first enable Realtime on from your Supabase console. You can read more [here](https://supabase.io/docs/guides/api#managing-realtime) on how to enable it.

> **Warning**
> When using `stream()` with a `StreamBuilder`, make sure to persist the stream value as a variable in a `StatefulWidget` instead of directly constructing the stream within your widget tree, which could cause rapid rebuilds that will lead to losing realtime connection. 

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final client = Supabase.instance.client;

class MyWidget extends StatefulWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  // Persisting the future as local variable to prevent refetching upon rebuilds.
  final _stream = client.from('countries').stream(['id']).execute();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _stream,
      builder: (context, snapshot) {
        // return your widget with the data from snapshot
      },
    );
  }
}
```

### [Authentication](https://supabase.io/docs/guides/auth)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final client = Supabase.instance.client;

class MyWidget extends StatefulWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final GotrueSubscription _authSubscription;
  User? _user;

  @override
  void initState() {
    _authSubscription = client.auth.onAuthStateChange((event, session) {
      setState(() {
        _user = session?.user;
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    _authSubscription.data?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        client.auth.signIn(email: 'my_email@example.com');
      },
      child: const Text('Login'),
    );
  }
}
```

### [Storage](https://supabase.io/docs/guides/storage)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final file = File('example.txt');
        file.writeAsStringSync('File content');
        client.storage
            .from('my_bucket')
            .upload('my/path/to/files/example.txt', file);
      },
      child: const Text('Upload'),
    );
  }
}
```

### [Edge Functions](https://supabase.com/docs/guides/functions)

> **Warning**
> Supabase Edge Functions are Experimental until 1 August 2022. There will be breaking changes. Do not use them in Production.


```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final client = Supabase.instance.client;

class MyWidget extends StatefulWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  // Persisting the future as local variable to prevent refetching upon rebuilds.
  final _future = client.functions.invoke('get_countries');

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

## Authentication

Using this package automatically persists the auth state on local storage. 
It also helps you handle authentication with deeplink from 3rd party service like Google, Github, Twitter...


### Getting initial auth state

You might want to redirect users to different screens upon app launch.
For this, you can await `initialSession` of `SupabaseAuth` to get the initial session of the user. The future will complete once session recovery is done and will contain either the session if user had one or null if user had no session. 

```dart
Future<void> getInitialAuthState() async {
  try {
    final initialSession = await SupabaseAuth.instance.initialSession;
    // Redirect users to different screens depending on the initial session
  } catch(e) {
    // Handle initial auth state fetch error here
  }
}
```

### Email authentication

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> signIn(String email, String password) async {
  final response = await Supabase.instance.client.auth.signIn(email: email, password: password);
  if (response.error != null) {
    /// Handle error
  } else {
    /// Sign in with success
  }
}
```

### signInWithProvider

This method will automatically launch the auth url and open a browser for user to sign in with 3rd party login.

```dart
Supabase.instance.client.auth.signInWithProvider(
  Provider.github,
  options: supabase.AuthOptions(redirectTo: ''),
);
```

### Custom LocalStorage

As default `supabase_flutter` uses [`hive`](https://pub.dev/packages/hive) plugin to persist user session. However you can use any other plugins by creating a `LocalStorage` impl.

For example, we can use `flutter_secure_storage` plugin to store the user session in a secure storage.

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

You can use `EmptyLocalStorage` to disable session persistance:

```dart
Supabase.initialize(
  // ...
  localStorage: const EmptyLocalStorage(),
);
```

## Deeplink config

### Supabase redirect URLs config

- Go to your Supabase project Authentication Settings page.
- You need to enter your app redirect callback on `Additional Redirect URLs` field.

The redirect callback url should have this format `[YOUR_SCHEME]://[YOUR_AUTH_HOSTNAME]`

![authentication settings page](https://user-images.githubusercontent.com/689843/124574731-f735c180-de74-11eb-8f50-2d34161261dd.png)

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

  Setting up deeplinks in Windows has few more steps than other platforms. [Learn more](https://pub.dev/packages/app_links#windows)

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

  The most relevant solution is to include those registry modifications into your installer to allow the unregistration.

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
