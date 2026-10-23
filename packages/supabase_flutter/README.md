<br />
<p align="center">
  <a href="https://supabase.com">
    <img alt="Supabase Logo" width="300" src="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/logo-preview.jpg">
  </a>

  <h1 align="center">supabase_flutter</h1>

  <p align="center">
    Flutter client library for <a href="https://supabase.com">Supabase</a>.
  </p>

  <p align="center">
    <a href="https://supabase.com/docs/guides/with-flutter">Guides</a>
    ·
    <a href="https://supabase.com/docs/reference/dart/introduction">Reference Docs</a>
    ·
    <a href="https://github.com/supabase/supabase-flutter/blob/main/MIGRATION.md">Migration Guides</a>
  </p>
</p>

<div align="center">

[![pub package](https://img.shields.io/pub/v/supabase_flutter.svg)](https://pub.dev/packages/supabase_flutter)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

</div>

`supabase_flutter` is the Supabase client for Flutter apps: typed database
queries, auth, realtime, storage and edge functions, plus the Flutter parts
around them, such as session persistence, deep links for auth redirects and
the app lifecycle. For Dart code that does not run in Flutter, such as a
server or a command line tool, use [`supabase`](https://pub.dev/packages/supabase)
instead.

This README describes v3. Most Supabase Dart examples published elsewhere are
v2 code, which no longer compiles. To upgrade a v2 project, follow
[MIGRATION.md](https://github.com/supabase/supabase-flutter/blob/main/MIGRATION.md).

## Using an AI coding agent

`supabase_flutter` ships [package skills](https://dart.dev/ai/package-skills),
instructions that teach coding agents such as Claude Code, Cursor, Gemini or
Copilot the current API. Agents trained on v2 examples otherwise tend to write
code that does not compile against v3. The skills for generating the schema
and for testing ship with the dev dependencies they are about. Install the
skills of every package you use:

```sh
dart run skills@ get -p supabase_flutter
dart run skills@ get -p supabase_typegen
dart run skills@ get -p supabase_test
```

| Skill                         | Package            | Covers                                                                   |
| ----------------------------- | ------------------ | ------------------------------------------------------------------------ |
| `supabase-flutter-idioms`     | `supabase_flutter` | Writing or reviewing any code that uses the client                       |
| `supabase-flutter-realtime`   | `supabase_flutter` | Live lists with `stream()`, `onTableChanges`, broadcast and presence     |
| `supabase-flutter-auth-setup` | `supabase_flutter` | OAuth, magic links and password reset that return to the app with a link |
| `supabase-flutter-migrate-v3` | `supabase_flutter` | Upgrading a project from v2 to v3                                        |
| `supabase-typegen-generate`   | `supabase_typegen` | Generating the typed database schema and keeping it in sync              |
| `supabase-test-testing`       | `supabase_test`    | Unit and widget tests with `supabase_test`                               |

Run the commands again after upgrading the packages to update the skills.
Commit the installed skills together with `.config/dart_skills/` so everyone
working on the project gets the same version.

## Getting started

### 1. Add the package

```sh
flutter pub add supabase_flutter
```

### 2. Initialize Supabase

Call `Supabase.initialize` once, before `runApp`. It restores the persisted
session before it returns. Find the URL and the publishable key of your
project in the dashboard under **Project Settings > API Keys**.

```dart file
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    publishableKey: 'your-publishable-key',
  );
  runApp(const MaterialApp(home: Placeholder()));
}

final supabase = Supabase.instance.client;
```

Use this one client everywhere in the app.

### 3. Generate the typed schema

Queries are typed by a Dart file generated from your database schema. It
holds a row type per table, `BooksRow` for a `books` table, the
`BooksInsert` and `BooksUpdate` values that writes accept, and a `Books`
class with the table definition and one constant per column. Generate it with
the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started),
version 2.122.0 or newer, from the directory of your `pubspec.yaml`:

```sh
flutter pub add dev:supabase_typegen
supabase gen types --lang dart --local > lib/supabase_schema.g.dart
```

`--local` reads the schema of the stack started with `supabase start`.
Use `--linked` for the project linked with `supabase link`, or
`--project-id <ref>` for any hosted project. Never edit the generated file:
regenerate it after every database migration and commit it. The
[`supabase_typegen` README](https://pub.dev/packages/supabase_typegen) lists
everything it generates.

### 4. Query

Import the generated file next to `supabase_flutter`, and pass a table
definition to `table()`:

```dart
final List<BooksRow> books = await supabase
    .table(Books.table)
    .select()
    .where(Books.inPrint.isTrue())
    .order(Books.title);

print(books.first.title);
```

## Rules of the v3 API

- Query tables with `table()` and the generated schema. `from()` with
  `Map<String, dynamic>` rows is only the fallback for a table that is not in
  the generated file.
- Pass `publishableKey` to `Supabase.initialize`. `anonKey` does not exist.
- Realtime events arrive on streams. No method takes a `callback:`.
- A typed `update()` or `delete()` sends nothing until `.where(…)` or
  `.all()` is called on it.
- Catch the `SupabaseException` hierarchy, never `ClientException`,
  `TimeoutException` or `String`.
- Create a `stream()` once, in a `State` or a controller, never inside
  `build()`.

## Contents

- [Database](#database)
- [Authentication](#authentication)
  - [Native Apple sign in](#native-apple-sign-in)
  - [Native Google sign in](#native-google-sign-in)
  - [Native Facebook sign in](#native-facebook-sign-in)
  - [OAuth login](#oauth-login)
  - [Passkeys](#passkeys)
  - [Android Restore Credentials](#android-restore-credentials)
- [Realtime](#realtime)
  - [Live rows with `stream()`](#live-rows-with-stream)
  - [Postgres changes](#postgres-changes)
  - [Broadcast](#broadcast)
  - [Presence](#presence)
  - [Realtime and the app lifecycle](#realtime-and-the-app-lifecycle)
- [Storage](#storage)
- [Edge Functions](#edge-functions)
- [Errors](#errors)
- [Deep links](#deep-links)
- [Custom session storage](#custom-session-storage)
- [Logging](#logging)
- [Request ids and tracing](#request-ids-and-tracing)
- [Testing](#testing)

The examples below use a `books` table with a foreign key to an `authors`
table, and the types generated for them.

## [Database](https://supabase.com/docs/guides/database)

Filters are methods on the column constants, combined with `&`, `|` and
`not()`. The compiler checks that a value matches the type of its column, and
`isNull()` only exists on nullable columns.

```dart
// A list of rows.
final List<BooksRow> cheapBooks = await supabase
    .table(Books.table)
    .select()
    .where(Books.inPrint.isTrue() & Books.price.lt(10))
    .order(Books.createdAt.desc())
    .limit(20);

// Exactly one row, or a PostgrestException when there is none.
final BooksRow book = await supabase
    .table(Books.table)
    .select()
    .where(Books.id.eq(1))
    .single();

// Some columns only, with the author embedded through the foreign key.
final titles = await supabase.table(Books.table).selectOnly([
  Books.title,
  Books.authors(Authors.name),
]);
final String title = titles.first.read(Books.title);
final String? author = titles.first.read(Books.authors)?.read(Authors.name);
```

Writes take the generated insert and update types, which mark the required
columns as required parameters:

```dart
await supabase
    .table(Books.table)
    .insert(BooksInsert(authorId: 2, title: 'Dune'));

// Add select() to get the written row back.
final BooksRow inserted = await supabase
    .table(Books.table)
    .insert(BooksInsert(authorId: 2, title: 'Emma'))
    .select()
    .single();

await supabase
    .table(Books.table)
    .update(BooksUpdate(inPrint: false).setPriceToNull())
    .where(Books.id.eq(1));

await supabase.table(Books.table).delete().where(Books.id.eq(1));
```

A `null` argument to `BooksInsert` or `BooksUpdate` leaves the column out,
and the generated `set…ToNull()` methods write SQL `NULL`. Several rows go
through `insertAll()` and `upsertAll()`.

Database functions get a typed method on `rpc`:

```dart
final BooksRow? book = await supabase.rpc.bookById(bookId: 1);
```

The untyped `supabase.from('books')` and `supabase.rpc('fn', params: {…})`
remain for tables and functions that are not in the generated file. The full
list of filters and modifiers is in the
[Dart reference](https://supabase.com/docs/reference/dart/select).

## [Authentication](https://supabase.com/docs/guides/auth)

Sign-in methods that always produce a session return the `Session`. `signUp()`
and `verifyOTP()` return an `AuthResponse`, since they can complete without
one, for example while the email address waits for confirmation.

```dart
await supabase.auth.signUp(
  email: 'user@example.com',
  password: 'a-strong-password',
);

final Session session = await supabase.auth.signInWithPassword(
  email: 'user@example.com',
  password: 'a-strong-password',
);

// Sends a magic link. The link opens the app through a deep link.
await supabase.auth.signInWithOtp(email: 'user@example.com');

await supabase.auth.signOut();
```

`onAuthStateChange` emits a sealed `AuthState`, with one subtype per event.
Every new listener first receives `AuthInitialSession` with the current
session, or `null` when no user is signed in. A token refresh that fails, for
example while the device is offline, arrives as an error on the stream, so
always pass `onError`. Without it the error is unhandled:

```dart
final subscription = supabase.auth.onAuthStateChange.listen(
  (state) {
    switch (state) {
      case AuthInitialSession(:final session):
        print('Started with ${session?.user.email ?? 'no user'}');
      case AuthSignedIn(:final session):
        print('Signed in as ${session.user.email}');
      case AuthSignedOut(:final reason):
        print('Signed out, reason: ${reason?.name}');
      case _:
        print('Auth event: ${state.event.name}');
    }
  },
  onError: (Object error) => print('Auth error: $error'),
);
```

`supabase.auth.currentUser` and `supabase.auth.currentSession` hold the
state at any time, without listening.

### Native Apple sign in

Use the [sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple)
package and follow its README to set up Apple sign in on iOS and macOS. Then
add the bundle ID of your app in the Supabase dashboard under
**Authentication > Providers > Apple**.

```dart skip
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<Session> signInWithApple() async {
  final rawNonce = supabase.auth.generateRawNonce();
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
    throw const AuthException('Apple returned no ID token.');
  }

  return supabase.auth.signInWithIdToken(
    provider: OAuthProvider.apple,
    idToken: idToken,
    nonce: rawNonce,
  );
}
```

### Native Google sign in

Use the [google_sign_in](https://pub.dev/packages/google_sign_in) package and
follow its README for the platform setup. Google sign in with Supabase needs a
web client ID, plus an iOS client ID on iOS:

- [Steps to obtain the web client ID](https://developers.google.com/identity/sign-in/android/start-integrating#configure_a_project)
- [Steps to obtain the Android client ID](https://developers.google.com/identity/sign-in/android/start-integrating#configure_a_project)
- [Steps to obtain the iOS client ID](https://developers.google.com/identity/sign-in/ios/start-integrating#get_an_oauth_client_id)

Add the web client ID in the Supabase dashboard under
**Authentication > Providers > Google**, and turn on **Skip nonce check**,
which iOS needs.

```dart skip
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

const webClientId = 'my-web.apps.googleusercontent.com';
const iosClientId = 'my-ios.apps.googleusercontent.com';

/// Call once, when the app starts.
Future<void> initializeGoogleSignIn() {
  return GoogleSignIn.instance.initialize(
    clientId: iosClientId,
    serverClientId: webClientId,
  );
}

Future<Session> signInWithGoogle() async {
  final account = await GoogleSignIn.instance.authenticate();
  final idToken = account.authentication.idToken;
  if (idToken == null) {
    throw const AuthException('Google returned no ID token.');
  }
  final authorization = await account.authorizationClient
      .authorizationForScopes(['email']);

  return supabase.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
    accessToken: authorization?.accessToken,
  );
}
```

### Native Facebook sign in

Use [flutter_facebook_auth](https://pub.dev/packages/flutter_facebook_auth)
`^7.1.7` with `signInWithIdToken` on iOS and Android:

- **iOS** uses Facebook's
  [Limited Login](https://developers.facebook.com/docs/facebook-login/limited-login/)
  (`LoginTracking.limited`), which returns a `LimitedToken` holding an OIDC ID
  token.
- **Android** needs `LoginBehavior.webOnly` and the `openid` permission to
  receive an OIDC ID token in `ClassicToken.authenticationToken`.

```dart skip
import 'dart:io';

import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<Session> signInWithFacebook() async {
  final LoginResult result;
  if (Platform.isIOS) {
    result = await FacebookAuth.instance.login(
      permissions: ['public_profile', 'email'],
      loginTracking: LoginTracking.limited,
    );
  } else {
    result = await FacebookAuth.instance.login(
      permissions: ['public_profile', 'email', 'openid'],
      loginBehavior: LoginBehavior.webOnly,
    );
  }
  if (result.status != LoginStatus.success) {
    throw AuthException('Facebook sign in failed: ${result.message}');
  }

  final idToken = switch (result.accessToken) {
    LimitedToken(:final tokenString) => tokenString,
    ClassicToken(:final authenticationToken) => authenticationToken,
    _ => null,
  };
  if (idToken == null) {
    throw const AuthException(
      'Facebook returned no ID token. On Android, use LoginBehavior.webOnly '
      'and request the openid permission.',
    );
  }

  return supabase.auth.signInWithIdToken(
    provider: OAuthProvider.facebook,
    idToken: idToken,
  );
}
```

Without the Facebook SDK, use `signInWithOAuth()` from the next section,
which runs the Facebook login in the browser.

### OAuth login

`signInWithIdToken()` supports Apple, Google, Facebook, Kakao and Keycloak.
Every other provider signs in through `signInWithOAuth()`, which opens the
browser. Pass a deep link as `redirectTo` to bring the user back to the app,
as described in [Deep links](#deep-links). `signInWithOAuth()` returns once
the browser is open, and `false` when it could not be opened:

```dart file
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<void> signInWithGitHub() async {
  final launched = await supabase.auth.signInWithOAuth(
    OAuthProvider.github,
    // On the web the browser returns to the current page instead.
    redirectTo: kIsWeb ? null : 'io.supabase.flutterdemo://login-callback',
  );
  if (!launched) {
    throw const AuthException('Could not open the sign in page.');
  }
}
```

The sign in completes when the app receives the link, and
`onAuthStateChange` then emits `AuthSignedIn`. Listen for it rather than
awaiting it after the call: the user can close the browser without signing
in, and no event arrives then.

To run the flow in an in-app browser session instead of the system browser,
add [`supabase_flutter_web_auth`](https://pub.dev/packages/supabase_flutter_web_auth).

### Passkeys

> Passkeys are a beta feature. Enable them in the Supabase dashboard under
> **Authentication > Configuration > Passkeys** before using these methods.

`supabase_flutter` performs the server side of the WebAuthn ceremony and
hands the platform prompt (Face ID, Touch ID, a security key) to an
authenticator you pass in. It does not depend on a passkey plugin itself, so
apps that do not use passkeys keep their minimum platform versions.

The `PasskeyAuthenticator` of the [`passkeys`](https://pub.dev/packages/passkeys)
plugin implements the `PasskeyAuthenticatorInterface` these methods expect
(since `passkeys` 2.21.0), and any other implementation works too:

```dart file
import 'package:passkeys/authenticator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
final authenticator = PasskeyAuthenticator();

Future<void> passkeys() async {
  // Prompts the user to pick and unlock a passkey.
  await supabase.auth.signInWithPasskey(authenticator);

  // Registers a new passkey for the signed in user.
  await supabase.auth.registerPasskey(authenticator);

  // Manages the passkeys of the signed in user.
  final passkeys = await supabase.auth.passkey.list();
  await supabase.auth.passkey.update(
    passkeyId: passkeys.first.id,
    friendlyName: 'My phone',
  );
  await supabase.auth.passkey.delete(passkeyId: passkeys.first.id);
}
```

The plugin documents its platform requirements and setup, and how to handle a
failed ceremony, such as the user cancelling.

### Android Restore Credentials

Android's
[Restore Credentials](https://developer.android.com/identity/sign-in/restore-credentials)
restore keys are passkeys, so they use the same beta passkey feature and the
same authenticator. The `PasskeyAuthenticator` of the
[`passkeys`](https://pub.dev/packages/passkeys) plugin implements the
`RestoreCredentialInterface` these methods expect (since `passkeys` 2.23.1).

- Call `supabase.auth.createRestoreKey(authenticator)` after a sign in that
  is not anonymous.
- Call `supabase.auth.signInWithRestoreKey(authenticator)` on the first
  launch on a new device.
- On sign out, delete the passkey on the server and call
  `clearRestoreCredential()` on the authenticator.

The API documentation of `AuthClientRestoreCredential` has the details.

## [Realtime](https://supabase.com/docs/guides/realtime)

Postgres changes only arrive for tables in the `supabase_realtime`
publication. Add a table to it in the dashboard under **Database >
Publications**, or in a migration:

```sql
alter publication supabase_realtime add table books;
```

### Live rows with `stream()`

`stream()` emits the rows of a table, first as they are and then again after
every change:

```dart
final Stream<List<BooksRow>> books = supabase
    .table(Books.table)
    .stream(primaryKey: [Books.id])
    .filter(Books.authorId.eq(2))
    .order(Books.title);
```

Create the stream once, in a `State` or a controller. A stream created inside
`build()` subscribes again on every rebuild, which loses the realtime
connection.

```dart file
import 'package:flutter/material.dart';
import 'package:my_app/supabase_schema.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookList extends StatefulWidget {
  const BookList({super.key});

  @override
  State<BookList> createState() => _BookListState();
}

class _BookListState extends State<BookList> {
  final _books = Supabase.instance.client
      .table(Books.table)
      .stream(primaryKey: [Books.id])
      .order(Books.title);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BooksRow>>(
      stream: _books,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('${snapshot.error}');
        final books = snapshot.data ?? const [];
        return ListView(children: [for (final book in books) Text(book.title)]);
      },
    );
  }
}
```

### [Postgres changes](https://supabase.com/docs/guides/realtime/postgres-changes)

`onTableChanges` emits each insert, update and delete as a typed change.
Create the stream before calling `subscribe()`, and remove the channel when
you no longer need it:

```dart
final channel = supabase.channel('books');
final subscription = channel
    .onTableChanges(Books.table, filters: [Books.authorId.eq(2)])
    .listen((change) {
      switch (change) {
        case TypedPostgresInsert(:final newRow):
          print('Added ${newRow.title}');
        case TypedPostgresUpdate(:final newRow):
          print('Changed ${newRow.title}');
        case TypedPostgresDelete(:final oldRow):
          print('Removed ${oldRow.read(Books.id)}');
      }
    });
channel.subscribe();

// Later, when done:
await subscription.cancel();
await supabase.removeChannel(channel);
```

Pass `event: PostgresChangeEvent.insert` to receive one kind of change only.

### [Broadcast](https://supabase.com/docs/guides/realtime/broadcast)

Broadcast sends low latency messages between connected clients, without
going through the database. Send once the channel is subscribed:

```dart
final channel = supabase.channel('room');

channel.onBroadcast(event: 'cursor').listen((message) {
  print('Cursor moved: ${message['payload']}');
});

channel.onStatusChange.listen((change) async {
  if (change.status == RealtimeSubscribeStatus.subscribed) {
    await channel.sendBroadcastMessage(
      event: 'cursor',
      payload: {'x': 30, 'y': 50},
    );
  }
});

channel.subscribe();
```

### [Presence](https://supabase.com/docs/guides/realtime/presence)

Presence shares state between the clients of a channel, such as who is
online:

```dart
final channel = supabase.channel('room');

channel.onPresenceSync.listen((_) {
  print('Online: ${channel.presenceState()}');
});
channel.onPresenceJoin.listen((payload) {
  print('Joined: ${payload.newPresences}');
});
channel.onPresenceLeave.listen((payload) {
  print('Left: ${payload.leftPresences}');
});

channel.onStatusChange.listen((change) async {
  if (change.status == RealtimeSubscribeStatus.subscribed) {
    await channel.track({'online_at': DateTime.now().toIso8601String()});
  }
});

channel.subscribe();
```

### Realtime and the app lifecycle

`Supabase` disconnects the realtime socket when the app is paused, and
reconnects it, rejoining every joined channel, when the app is resumed. Every
reconnect costs a new socket and a new authorization of each channel.

On iOS, a full-screen view such as a video ad or a system sheet reports the
app as paused while it is on screen. Pass `RealtimeLifecycleOptions` to keep
the socket open through pauses shorter than a grace period:

```dart
await Supabase.initialize(
  url: 'https://your-project.supabase.co',
  publishableKey: 'your-publishable-key',
  realtimeLifecycleOptions: const RealtimeLifecycleOptions(
    disconnectAfterPause: Duration(minutes: 1),
  ),
);
```

`RealtimeLifecycleOptions.manual()` keeps the socket out of the app lifecycle
entirely. The socket then stays open in the background until the operating
system closes it, and the realtime client reconnects and rejoins its channels
once the app runs again.

## [Storage](https://supabase.com/docs/guides/storage)

`storage.from()` selects a bucket. It is the storage API, not a database
query.

```dart file
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<void> storage() async {
  final bucket = supabase.storage.from('avatars');

  await bucket.uploadBinary('users/1/notes.txt', utf8.encode('File content'));

  final Uint8List downloaded = await bucket.download('users/1/notes.txt');

  final String url = await bucket.createSignedUrl('users/1/notes.txt', 60);
}
```

`upload()` takes a `File` instead of bytes, on every platform except the web.

## [Edge Functions](https://supabase.com/docs/guides/functions)

```dart
final response = await supabase.functions.invoke(
  'hello',
  body: {'name': 'Dart'},
);
print(response.data);
```

## Errors

Every exception the SDK throws for a failed request extends
`SupabaseException`. `SupabaseApiException` means the server answered with an
error, and `SupabaseTransportException` means no response arrived, including
a timeout:

```dart
try {
  await supabase.table(Books.table).select();
} on SupabaseApiException catch (error) {
  print('${error.statusCode} ${error.errorCode}: ${error.message}');
} on SupabaseTransportException catch (error) {
  print('No response: ${error.cause}');
}
```

Each service also has its own base class, such as `PostgrestException`,
`AuthException`, `StorageException` or `FunctionException`, to catch the
errors of one service only.

## Deep links

### When you need deep links

A deep link brings the user back into your app from an email or a browser.
Set them up when you use any of these:

- Magic link sign in.
- Email sign in with **Confirm email** enabled.
- Password reset by email.
- `signInWithOAuth()`.

`supabase_flutter` handles deep links on Android, iOS, the web, macOS, Windows
and Linux. It completes the sign in itself when the app is opened through a
link carrying a `code` (the PKCE flow, the default) or an `access_token`.

By default, every link with a `code`, `access_token`, `error`, `error_code` or
`error_description` parameter, in the query or the fragment, is treated as an
auth callback. If your app receives other links with one of those parameters,
pass `detectSessionInUriPredicate` to tell the auth callbacks apart, for
example by the redirect URL they arrive on. On the web the predicate receives
the URL of the page, so check only the parameters there:

```dart file
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _authParameters = {
  'access_token',
  'code',
  'error',
  'error_code',
  'error_description',
};

bool _isAuthCallback(Uri uri) {
  if (!kIsWeb && uri.host != 'login-callback') return false;
  final fragmentParameters = Uri.splitQueryString(uri.fragment);
  return _authParameters.any(
    (parameter) =>
        uri.queryParameters.containsKey(parameter) ||
        fragmentParameters.containsKey(parameter),
  );
}

Future<void> initializeSupabase() async {
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    publishableKey: 'your-publishable-key',
    authOptions: FlutterAuthClientOptions(
      detectSessionInUriPredicate: _isAuthCallback,
    ),
  );
}
```

`detectSessionInUri: false` turns the handling off, for example when the app
calls `exchangeCodeForSession` itself.

### Dashboard configuration

Add your redirect URL in the dashboard under
**Authentication > URL Configuration > Redirect URLs**.

The redirect URL has the format `[YOUR_SCHEME]://[YOUR_HOSTNAME]`, for example
`io.supabase.flutterdemo://login-callback`. Choose any scheme and host name,
as long as the scheme is unique on the user's device, which is why the
reverse domain of your website is the usual choice.

![authentication settings page](https://raw.githubusercontent.com/supabase/supabase-flutter/main/.github/images/deeplink-config.png)

### Flutter configuration

`supabase_flutter` uses [app_links](https://pub.dev/packages/app_links) to
receive deep links. Follow its
[getting started guide](https://github.com/llfbandit/app_links/tree/master?tab=readme-ov-file#getting-started)
for the configuration of each platform. The
[native mobile deep linking guide](https://supabase.com/docs/guides/auth/native-mobile-deep-linking)
covers the Supabase side for each OAuth provider.

## Custom session storage

By default, `supabase_flutter` persists the user session, and the code
verifiers of pending PKCE flows, with the `SharedPreferencesAsync` API of
[`shared_preferences`](https://pub.dev/packages/shared_preferences). If your
own code still uses the legacy `SharedPreferences` API,
[migrate it to `SharedPreferencesAsync`](https://pub.dev/packages/shared_preferences#migrating-from-sharedpreferences-to-sharedpreferencesasync-or-sharedpreferenceswithcache):
on Windows and Linux both APIs rewrite the same file from their own cache, so
a write through one drops what the other wrote, and a mixed setup can lose
your preferences as well as the session.

To store them anywhere else, pass an `AuthAsyncStorage` implementation. This
one keeps the session in secure storage with
[`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage):

```dart skip
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureAuthStorage extends AuthAsyncStorage {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> getItem(String key) => _storage.read(key: key);

  @override
  Future<void> setItem(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> removeItem(String key) => _storage.delete(key: key);
}

Future<void> initialize() async {
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    publishableKey: 'your-publishable-key',
    authOptions: FlutterAuthClientOptions(asyncStorage: SecureAuthStorage()),
  );
}
```

The session is stored under a key derived from your project URL, which
`defaultPersistSessionKey` returns and `storageKey` on the auth options
overrides. The code verifiers are stored under keys prefixed with it.

Set `persistSession` to `false` to keep the session in memory only. The code
verifiers are still stored, so a sign in through an email link or an OAuth
redirect can complete after the app was closed in between.

```dart
await Supabase.initialize(
  url: 'https://your-project.supabase.co',
  publishableKey: 'your-publishable-key',
  authOptions: const FlutterAuthClientOptions(persistSession: false),
);
```

## Logging

All Supabase packages log through the
[logging](https://pub.dev/packages/logging) package, with loggers under the
shared `supabase` hierarchy. They never print anything and never change any
`package:logging` settings, so your app decides whether, where and at which
level logs are handled.

### Listen to Supabase logs

The simplest setup listens on the root logger and filters on the logger
name. It receives the records allowed by `Logger.root.level`, which defaults
to `Level.INFO`. Set `Logger.root.level = Level.ALL` to also receive the
fine-grained records, including the `Level.FINEST` payloads described below.

```dart file
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

void main() {
  Logger.root.onRecord.listen((record) {
    if (record.loggerName.startsWith('supabase.')) {
      debugPrint(
        '${record.loggerName}: ${record.level.name}: '
        '${record.message} ${record.error ?? ''}',
      );
    }
  });
}
```

### Filter Supabase logs by level

To set the level of the Supabase logs apart from the rest of your app, enable
hierarchical logging and configure the `supabase` logger:

```dart file
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

void main() {
  hierarchicalLoggingEnabled = true;
  Logger('supabase')
    ..level = Level.INFO
    ..onRecord.listen((record) {
      debugPrint(
        '${record.loggerName}: ${record.level.name}: '
        '${record.message} ${record.error ?? ''}',
      );
    });
}
```

Without `hierarchicalLoggingEnabled = true`, `package:logging` only supports
listening and setting levels on `Logger.root`.

### Log levels

- `Level.CONFIG`: client configuration during initialization.
- `Level.FINEST`: wire-level details such as request and response payloads.
  These records can contain sensitive data like row data, so handle them
  accordingly. Credentials never appear in any record at any level: headers,
  URL parameters and payload fields that carry an API key, access token or
  other credential are replaced by `<redacted>` before they are logged.
- `Level.FINE`: internal lifecycle events, for example the realtime socket
  connecting or disconnecting.
- `Level.INFO`: notable events, for example completed initialization or
  session recovery.
- `Level.WARNING`: recoverable problems, for example a failed retry attempt
  or an unexpected disconnect.

### Package loggers

| Package              | Logger                              |
| -------------------- | ----------------------------------- |
| `supabase_flutter`   | `Logger('supabase.flutter')`        |
| `supabase`           | `Logger('supabase.dart')`           |
| `postgrest`          | `Logger('supabase.postgrest')`      |
| `supabase_auth`      | `Logger('supabase.auth')`           |
| `supabase_realtime`  | `Logger('supabase.realtime')`       |
| `supabase_storage`   | `Logger('supabase.storage')`        |
| `supabase_functions` | `Logger('supabase.functions')`      |
| `iceberg`            | `Logger('supabase.storage.iceberg')` |

## Request ids and tracing

When a request fails, the Supabase logs of your project usually say why. There
are two ways to find the entries of a specific request: the request id on the
exception, which needs no setup, and trace propagation, which ties requests
into the traces of a tracing tool you already use.

### Request id on a failure

Every response from the Supabase gateway carries a request id, and the
exceptions thrown by the auth, database, storage and functions clients expose
it as `requestId`. Paste it into the log explorer of your project dashboard to
find the server side logs of the failed request, or quote it when you contact
support.

```dart
try {
  await supabase.table(Books.table).select();
} on SupabaseException catch (error) {
  print('Request failed: ${error.message} (request id: ${error.requestId})');
}
```

`requestId` is also part of the `toString()` of every one of these
exceptions, so an error reporter that records the exception records the id
with it.

It is read from the `sb-request-id` response header, falling back to
`x-request-id` for a self-hosted stack behind a reverse proxy that assigns its
own. It is `null` when no response was received, for example on a network
failure, or when the response carried neither header. Realtime errors do not
carry a request id.

### Trace propagation

If your app already records traces with a tool like Sentry or OpenTelemetry,
the client can send the active
[W3C trace context](https://www.w3.org/TR/trace-context/) along with each
request, so the Supabase logs of that request carry the trace id of the span
that made it.

Propagation is off by default. Turn it on by passing `TracePropagationOptions`
with a `traceContextProvider`, which the client calls before each request to
read the active trace. Return `null` when there is no active trace, and the
request is sent without trace headers.

#### Sentry

`toSentryTrace()` returns a header in the `sentry-trace` format, so convert it
with `formatAsW3CHeader` from `package:sentry` before passing it on:

```dart skip
import 'package:sentry/sentry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initialize() async {
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    publishableKey: 'your-publishable-key',
    tracePropagationOptions: TracePropagationOptions(
      traceContextProvider: () {
        final span = Sentry.getSpan();
        if (span == null) return null;
        return TraceContext(
          traceparent: formatAsW3CHeader(span.toSentryTrace()),
          baggage: span.toBaggageHeader()?.value,
        );
      },
    ),
  );
}
```

#### OpenTelemetry

Let the propagator you registered write the active context into a map, and
read the headers back out of it with `TraceContext.fromCarrier`:

```dart skip
import 'package:opentelemetry/api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapSetter implements TextMapSetter<Map<String, String>> {
  @override
  void set(Map<String, String> carrier, String key, String value) {
    carrier[key] = value;
  }
}

Future<void> initialize() async {
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    publishableKey: 'your-publishable-key',
    tracePropagationOptions: TracePropagationOptions(
      traceContextProvider: () {
        final carrier = <String, String>{};
        globalTextMapPropagator.inject(Context.current, carrier, MapSetter());
        return TraceContext.fromCarrier(carrier);
      },
    ),
  );
}
```

#### Other tracing tools

For a tool that exposes the ids of the active span rather than a W3C header,
build the context with `TraceContext.w3c`:

```dart skip
traceContextProvider: () => TraceContext.w3c(
  traceId: span.traceId,
  spanId: span.spanId,
  sampled: span.isSampled,
),
```

A `traceparent` that is not valid W3C trace context is not sent, and the
client logs a warning the first time it sees one.

#### Which requests carry trace headers

The headers are only added to requests addressed to a Supabase host: your
project URL, `*.supabase.co`, `*.supabase.in`, and `localhost`, `127.0.0.1`
and `::1` for local development. Third-party hosts never receive them: when a
Supabase host redirects a request to another host, the redirected request is
sent without them. The exception is the web, where the browser follows
redirects itself and a redirect to another host still carries the headers.
They are sent on every HTTP request the client makes, including realtime
broadcasts sent over HTTP, but not over the realtime WebSocket connection.

#### Sampling

On a trace that is not sampled, one whose `traceparent` carries a sampled flag
of `0`, the client still sends `traceparent` so the Supabase logs get a trace
id to correlate on, but withholds `tracestate` and `baggage`. Set
`respectSamplingDecision` to `false` to send them on unsampled traces as well.

## Testing

Test code that uses Supabase with
[`supabase_test`](https://pub.dev/packages/supabase_test): a real client whose
HTTP requests are answered by stubs and whose realtime socket runs in memory,
so no running stack is needed. In widget tests, initialize `Supabase` with
`initializeTestSupabase` from `package:supabase_flutter/testing.dart`. The
`supabase-test-testing` skill of `supabase_test` teaches a coding agent the
same setup.

## Migrating

The breaking changes of each major version, and what to do about them, are
documented in
[MIGRATION.md](https://github.com/supabase/supabase-flutter/blob/main/MIGRATION.md).

## Contributing

- Fork the repo on [GitHub](https://github.com/supabase/supabase-flutter)
- Clone the project to your own machine
- Commit changes to your own branch
- Push your work back up to your fork
- Submit a pull request so that we can review your changes and merge

## License

This repo is licensed under MIT.

## Resources

- [Quickstart: Flutter](https://supabase.com/docs/guides/with-flutter)
- [Flutter Tutorial: building a Flutter chat app](https://supabase.com/blog/flutter-tutorial-building-a-chat-app)
- [Flutter Tutorial - Part 2: Authentication and Authorization with RLS](https://supabase.com/blog/flutter-authentication-and-authorization-with-rls)
