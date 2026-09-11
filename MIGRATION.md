# Migration Guides

This document lists the breaking changes between major versions of the Supabase Flutter SDK and
what you need to change in your code.

All packages in this repository are released together for a major version, so a single section
covers `supabase_flutter`, `supabase`, `supabase_auth`, `postgrest`, `supabase_realtime`,
`supabase_storage`, `iceberg` and `supabase_functions`. Every symbol mentioned here is re-exported
from `supabase_flutter`, so the snippets apply whether you depend on the individual package or on
the Flutter one.

## Migrating from v2 to v3

> [!NOTE]
> v3 has not been released yet. This section is updated as breaking changes land on `main`, so
> treat it as the running list rather than the final one.

### Changes the compiler will not catch

Most of this guide produces compile errors until you act on it. These do not, so check them
explicitly:

- [`order()` now sorts ascending by default](#order-now-sorts-ascending-by-default)
- [`RealtimeClient.connectionState` is now typed](#realtimeclientconnectionstate-is-now-typed)
- [`HttpMethod` is one shared enum](#httpmethod-is-one-shared-enum), where the enum `index` shifted
- [Confirming an email or phone change emits `userUpdated`](#confirming-an-email-or-phone-change-emits-userupdated)
- [`AuthChangeEvent.initialSession` is emitted to every subscriber](#authchangeeventinitialsession-is-emitted-to-every-subscriber)
- [The retry backoff defaults are the same in every client](#the-retry-backoff-defaults-are-the-same-in-every-client)
- [The rest client and its builders are stateless](#the-rest-client-and-its-builders-are-stateless),
  where writes without a `select()` now resolve to `void`

### The client packages are renamed

Four packages are renamed. The old ones are discontinued on pub.dev when v3 ships.

| Before                     | After                        |
| -------------------------- | ---------------------------- |
| `gotrue: ^2.27.1`          | `supabase_auth: ^3.0.0`      |
| `functions_client: ^2.7.1` | `supabase_functions: ^3.0.0` |
| `realtime_client: ^2.13.0` | `supabase_realtime: ^3.0.0`  |
| `storage_client: ^2.8.0`   | `supabase_storage: ^3.0.0`   |

| Before                                           | After                                                |
| ------------------------------------------------ | ---------------------------------------------------- |
| `package:gotrue/gotrue.dart`                     | `package:supabase_auth/supabase_auth.dart`           |
| `package:functions_client/functions_client.dart` | `package:supabase_functions/supabase_functions.dart` |
| `package:realtime_client/realtime_client.dart`   | `package:supabase_realtime/supabase_realtime.dart`   |
| `package:storage_client/storage_client.dart`     | `package:supabase_storage/supabase_storage.dart`     |

If you depend on `supabase_flutter` or `supabase`, your dependencies and imports are unchanged.

Only the auth package renames types. The functions, realtime and storage packages keep every type
name they had:

| Before                                | After                               |
| ------------------------------------- | ----------------------------------- |
| `GoTrueClient`                        | `AuthClient`                        |
| `GoTrueAdminApi`                      | `AuthAdminApi`                      |
| `GoTrueAdminCustomProvidersApi`       | `AuthAdminCustomProvidersApi`       |
| `GoTrueAdminMFAApi`                   | `AuthAdminMFAApi`                   |
| `GoTrueAdminOAuthApi`                 | `AuthAdminOAuthApi`                 |
| `GoTrueAdminPasskeyApi`               | `AuthAdminPasskeyApi`               |
| `GoTrueMFAApi`                        | `AuthMFAApi`                        |
| `GoTrueOAuthApi`                      | `AuthOAuthApi`                      |
| `GoTruePasskeyApi`                    | `AuthPasskeyApi`                    |
| `GotrueAsyncStorage`                  | `AuthAsyncStorage`                  |
| `SharedPreferencesGotrueAsyncStorage` | `SharedPreferencesAuthAsyncStorage` |
| `GoTrueClientSignInProvider`          | `AuthClientSignInProvider`          |
| `GoTrueClientPasskey`                 | `AuthClientPasskey`                 |

```dart
// Before
final GoTrueClient auth = supabase.auth;

// After
final AuthClient auth = supabase.auth;
```

The last two are extensions `supabase_flutter` adds to the auth client. You only name them if you
referred to the extension explicitly, for example to hide it in an import.

### The Iceberg catalog moved to its own package

`IcebergRestCatalog`, the Iceberg exceptions and the table and namespace types now live in
`iceberg`. `supabase_storage` depends on it and re-exports the whole surface, so importing
`package:supabase_storage/supabase_storage.dart` or `package:supabase_flutter/supabase_flutter.dart`
keeps working unchanged, and `storage.analyticsCatalog()` is still how you get a catalog for an
analytics bucket.

Depend on `iceberg` directly to talk to an Iceberg REST Catalog without the rest of Storage:

```dart
final catalog = IcebergRestCatalog(
  baseUrl: 'https://example.com/iceberg',
  headers: {'Authorization': 'Bearer $token'},
  warehouse: 'my-warehouse',
);
```

### `publishableKey` is required on `Supabase.initialize`

`anonKey` is removed and `publishableKey` is required. A legacy anon key is still a valid value, it
just goes under the new name.

```dart
// Before
await Supabase.initialize(url: url, anonKey: anonKey);

// After
await Supabase.initialize(url: url, publishableKey: anonKey);
```

### `AuthClient.getSSOSignInUrl` returns a `Uri`

```dart
// Before
final String ssoUrl = await supabase.auth.getSSOSignInUrl(domain: 'company.com');

// After
final Uri ssoUrl = await supabase.auth.getSSOSignInUrl(domain: 'company.com');
```

Use `ssoUrl.toString()` if you need the string.

### `OAuthResponse.url` is a `Uri`

`getOAuthSignInUrl()` and `getLinkIdentityUrl()` return a `Uri` in `OAuthResponse.url` rather than
a `String`.

```dart
// Before
final String url = response.url;

// After
final Uri url = response.url;
```

Use `response.url.toString()` if you need the string, and drop any `Uri.parse()` you were doing
yourself.

### `admin.listUsers()` returns pagination metadata

`listUsers()` returns a `ListUsersResponse` instead of a `List<User>`. The users are under `users`,
alongside `total`, `nextPage`, `lastPage` and `audience`.

```dart
// Before
final List<User> users = await supabase.auth.admin.listUsers(perPage: 50);
for (final user in users) {
  print(user.email);
}

// After
final response = await supabase.auth.admin.listUsers(perPage: 50);
for (final user in response.users) {
  print(user.email);
}
```

`nextPage` is `null` on the last page, so you can walk every page without guessing where it ends:

```dart
var response = await supabase.auth.admin.listUsers(perPage: 50);
while (response.nextPage != null) {
  response = await supabase.auth.admin.listUsers(
    page: response.nextPage,
    perPage: 50,
  );
}
```

### `OAuthAuthorizationDetailsResponse.user` is an `OAuthAuthorizingUser`

```dart
// Before
final User user = details.user;

// After
final OAuthAuthorizingUser user = details.user;
```

`OAuthAuthorizingUser` carries `id` and `email`, which keep their names, so code that only reads
those needs no change.

### Confirming an email or phone change emits `userUpdated`

Confirming an email or phone change now emits `AuthChangeEvent.userUpdated` instead of
`AuthChangeEvent.signedIn`:

| Confirmation                                                      | Before     | After         |
| ----------------------------------------------------------------- | ---------- | ------------- |
| `verifyOTP()` with `OtpType.emailChange` or `OtpType.phoneChange` | `signedIn` | `userUpdated` |
| `getSessionFromUrl()` with an implicit `type=email_change` link   | `signedIn` | `userUpdated` |
| `exchangeCodeForSession()` for a PKCE code from an email change   | `signedIn` | `userUpdated` |

The session is still saved and `currentSession` still updates. Check any `onAuthStateChange`
listener that navigates or fetches on `signedIn` and expects the email-change confirmation to reach
it:

```dart
supabase.auth.onAuthStateChange.listen((data) {
  if (data.event == AuthChangeEvent.signedIn) {
    // Only runs on an actual sign-in.
  } else if (data.event == AuthChangeEvent.userUpdated) {
    // Runs when the user record changed, including a confirmed email change.
  }
});
```

For the PKCE case, `AuthSessionUrlResponse.redirectType` is `'userUpdated'` instead of `null`, so
you can also branch on the response of `exchangeCodeForSession()` directly.

### Cross-tab session sync is opt-in for standalone clients

On web the auth client keeps the tabs of a project in sync through a `BroadcastChannel`. It is now
only opened when the session is persisted. `AuthClientOptions` and `AuthClient` gain
`persistSession`, which defaults to `false`.

`Supabase.initialize` still defaults it to `true` through `FlutterAuthClientOptions`, so an app
initialized that way is unaffected. A client you construct directly no longer takes part unless you
ask for it:

```dart
// Before: every client synced its session across tabs.
final client = SupabaseClient(
  url,
  publishableKey,
  authOptions: AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage()),
);

// After: opt in where the session should be shared.
final client = SupabaseClient(
  url,
  publishableKey,
  authOptions: AuthClientOptions(
    asyncStorage: MemoryAuthAsyncStorage(),
    persistSession: true,
  ),
);
```

An app that passes `persistSession: false` keeps its session in memory and no longer syncs it
across tabs. A client configured with a third-party `accessToken` never opens the channel.

### The auth client persists the session itself

`AuthClient` owns session persistence. It takes one `AuthAsyncStorage` for both the session and the
pkce code verifiers, writes the session whenever it changes, and restores it when the client is
created, so a Dart program without Flutter gets session persistence too.

| Before                                                               | After                                |
| -------------------------------------------------------------------- | ------------------------------------ |
| `FlutterAuthClientOptions(localStorage: …)`                          | `AuthClientOptions(asyncStorage: …)` |
| `AuthClientOptions(pkceAsyncStorage: …)`                             | `AuthClientOptions(asyncStorage: …)` |
| `LocalStorage`, `EmptyLocalStorage`, `SharedPreferencesLocalStorage` | removed                              |
| `getItem({required String key})`                                     | `getItem(String key)`                |
| `setItem({required String key, required String value})`              | `setItem(String key, String value)`  |
| `removeItem({required String key})`                                  | `removeItem(String key)`             |

`SharedPreferencesAuthAsyncStorage` remains the default of `Supabase.initialize`. On web it writes
to `window.localStorage`, so the session is shared with supabase-js under the same key.

A custom storage implements the one interface and no longer needs to know the key:

```dart
// Before
class MySecureStorage extends LocalStorage {
  MySecureStorage({required this.persistSessionKey});

  final String persistSessionKey;

  final storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => storage.read(key: persistSessionKey);

  @override
  Future<bool> hasAccessToken() => storage.containsKey(key: persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      storage.write(key: persistSessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => storage.delete(key: persistSessionKey);
}

await Supabase.initialize(
  url: url,
  publishableKey: publishableKey,
  authOptions: FlutterAuthClientOptions(
    localStorage: MySecureStorage(
      persistSessionKey: defaultPersistSessionKey(url),
    ),
  ),
);

// After
class MySecureStorage extends AuthAsyncStorage {
  final storage = FlutterSecureStorage();

  @override
  Future<String?> getItem(String key) => storage.read(key: key);

  @override
  Future<void> setItem(String key, String value) =>
      storage.write(key: key, value: value);

  @override
  Future<void> removeItem(String key) => storage.delete(key: key);
}

await Supabase.initialize(
  url: url,
  publishableKey: publishableKey,
  authOptions: FlutterAuthClientOptions(asyncStorage: MySecureStorage()),
);
```

Keeping the session in memory only is a flag rather than a storage:

```dart
// Before
authOptions: FlutterAuthClientOptions(localStorage: const EmptyLocalStorage()),

// After
authOptions: FlutterAuthClientOptions(persistSession: false),
```

The code verifiers are still stored in that case, so a sign-in through an email link or an OAuth
redirect completes even when the app was closed in between.

A Dart program persists the session by passing a storage and opting in:

```dart
final client = SupabaseClient(
  url,
  publishableKey,
  authOptions: AuthClientOptions(
    asyncStorage: FileStorage(), // your AuthAsyncStorage
    persistSession: true,
  ),
);
await client.auth.initialized;
print(client.auth.currentSession?.user.email);
```

`AuthClient.initialized` completes once the persisted session has been restored.
`Supabase.initialize` awaits it, so `currentSession` is set when it returns, as before. Await it
yourself when you construct a client directly.

`AuthClientOptions.storageKey` names the key the session is stored under, defaulting to
`defaultPersistSessionKey(url)`, which is `sb-<project-ref>-auth-token`. It also prefixes the code
verifier keys and names the channel that keeps the tabs of a web app in sync. Verifiers under the
old `supabase.auth.token-…` prefix are still read and cleaned up, so a sign-in link requested before
the upgrade still completes after it.

### `AuthChangeEvent.initialSession` is emitted to every subscriber

`initialSession` is emitted to every new subscriber of `onAuthStateChange` as its first event,
carrying the session at that moment or `null`. In v2 it was emitted once at startup by
`Supabase.initialize`, and the stream replayed its latest event to late subscribers.

This is not a compile error. A listener attached after a sign-in now receives `initialSession` with
the signed-in session instead of a replayed `signedIn`, so move any work that ran on `signedIn` at
subscription time to handle `initialSession` as well:

```dart
supabase.auth.onAuthStateChange.listen((data) {
  switch (data.event) {
    case AuthChangeEvent.initialSession:
      // The session as it is when this listener attaches, or null.
    case AuthChangeEvent.signedIn:
      // A sign-in that happened after this listener attached.
    default:
  }
});
```

A client you construct yourself emits the event too. Earlier events and errors are no longer
replayed.

### The session is persisted with `SharedPreferencesAsync`

`SharedPreferencesAuthAsyncStorage`, the storage `Supabase.initialize` uses by default, now writes
through
[`SharedPreferencesAsync`](https://pub.dev/packages/shared_preferences#sharedpreferences-vs-sharedpreferencesasync-vs-sharedpreferenceswithcache)
rather than the legacy `SharedPreferences` API.

It moves an existing value over the first time it is read and deletes the legacy entry, so your
users stay signed in. No code change is needed, and there is nothing to migrate if you pass your own
`AuthAsyncStorage`.

Two things do need action.

If your own code still calls `SharedPreferences.getInstance()`, on Windows and Linux a session write
by the SDK can now drop preferences you wrote through the legacy API, and the other way around.
[Migrate your code to `SharedPreferencesAsync`](https://pub.dev/packages/shared_preferences#migrating-from-sharedpreferences-to-sharedpreferencesasync-or-sharedpreferenceswithcache)
as well. If you cannot do that yet, pass an `AuthAsyncStorage` that keeps the session in the legacy
store:

```dart
class LegacySharedPreferencesStorage extends AuthAsyncStorage {
  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<String?> getItem(String key) async =>
      (await _preferences).getString(key);

  @override
  Future<void> setItem(String key, String value) async =>
      (await _preferences).setString(key, value);

  @override
  Future<void> removeItem(String key) async =>
      (await _preferences).remove(key);
}

await Supabase.initialize(
  url: url,
  publishableKey: publishableKey,
  authOptions: FlutterAuthClientOptions(
    asyncStorage: LegacySharedPreferencesStorage(),
  ),
);
```

Widget tests that call `Supabase.initialize` need one more line of setup, since
`SharedPreferences.setMockInitialValues()` only stands in for the legacy API and the new storage
otherwise throws `StateError: The SharedPreferencesAsyncPlatform instance must be set.`:

```dart
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

setUp(() {
  SharedPreferences.setMockInitialValues({});
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
});
```

`shared_preferences_platform_interface` needs to be a `dev_dependency` for that import. Passing
`FlutterAuthClientOptions(asyncStorage: MemoryAuthAsyncStorage())` instead keeps the tests away from
shared preferences altogether.

### `supabasePersistSessionKey` is gone

The session is stored under `AuthClientOptions.storageKey`, which defaults to
`sb-<project-ref>-auth-token`.

A custom `AuthAsyncStorage` receives the key with every call, so there is nothing to replace the
constant with in the storage itself. To keep reading the sessions stored under it, pass it as the
key:

```dart
await Supabase.initialize(
  url: url,
  publishableKey: publishableKey,
  authOptions: FlutterAuthClientOptions(
    asyncStorage: MySecureStorage(),
    storageKey: 'SUPABASE_PERSIST_SESSION_KEY',
  ),
);
```

Leaving the key at its default signs your users out once instead.

The `MigrationLocalStorage` and `HiveLocalStorage` snippets that migrated a v1 session out of
[hive](https://pub.dev/packages/hive) are gone from the README. If you are still on v1, upgrade to
v2 first and let it migrate the session, then move to v3.

### Auth requires a GoTrue server on API version `2024-01-01` or newer

The auth client no longer falls back to the older `error_code` error field, nor reconstructs
`AuthWeakPasswordException` from a bare `weak_password` body. Error codes are always read from
`code`.

Hosted Supabase projects are long past this version, so this only affects self-hosted setups pinned
to a GoTrue older than `2024-01-01`. Against one of those, an auth failure still throws
`AuthApiException` with the right message and status code, but `code` is `null` and a weak password
surfaces as a plain `AuthApiException` rather than `AuthWeakPasswordException`. Upgrade the server to
restore both.

`ApiVersions` and its `ApiVersions.v20240101` field are removed with nothing replacing them.

### Session and auth request objects are immutable

`Session.expiresAt` is `late final`. Mint a new session, or call `copyWith` with a different
`accessToken`, to change the expiry:

```dart
// Before
session.expiresAt = DateTime.now().add(const Duration(hours: 1));

// After
final refreshed = session.copyWith(accessToken: newAccessToken);
print(refreshed.expiresAt);
```

`ResendResponse.messageId` is `final` too.

The request fields on `UserAttributes` and `AdminUserAttributes` are `final`, so pass them to the
constructor instead of assigning after construction:

```dart
// Before
final attributes = UserAttributes();
attributes.email = 'new@example.com';
attributes.data = {'name': 'Alice'};
await supabase.auth.updateUser(attributes);

// After
await supabase.auth.updateUser(
  UserAttributes(email: 'new@example.com', data: {'name': 'Alice'}),
);
```

### `order()` now sorts ascending by default

`PostgrestTransformBuilder.order()` and `SupabaseStreamBuilder.order()` default `ascending` to
`true` instead of `false`. This is not a compile error, so check every `.order()` call that does not
pass `ascending` explicitly, in both `select()` queries and `stream()`.

```dart
// Before: newest first
final messages = await supabase.from('messages').select().order('created_at');

// After: oldest first
final messages = await supabase.from('messages').select().order('created_at');
```

To keep the previous behaviour, ask for descending order explicitly:

```dart
final messages = await supabase
    .from('messages')
    .select()
    .order('created_at', ascending: false);
```

`ascending: false` already means descending on v2, so you can add it to your current code before
upgrading and leave this change out of the upgrade itself.

`nullsFirst` is unchanged and still defaults to `false`.

### The rest client and its builders are stateless

| Before                                                                                       | After                                                                                      |
| -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `supabase.rest.headers['X-Foo'] = 'bar'`                                                     | `supabase.headers = {...supabase.headers, 'X-Foo': 'bar'}`                                 |
| `postgrest.headers['X-Foo'] = 'bar'`                                                         | pass the header to the `PostgrestClient` constructor, or use `setHeader()` per request     |
| `await supabase.from('countries')`                                                           | does not compile, choose an operation first                                                |
| `SupabaseQuerySchema(headers: …)`                                                            | removed, the headers of the `rest` client are used                                         |
| `PostgrestQueryBuilder(method: …, abortSignal: …)` and `PostgrestRpcBuilder(abortSignal: …)` | removed, both belong to the executable builder returned by a table operation or by `rpc()` |
| `PostgrestBuilder.appendSearchParameters()` and `overrideSearchParameters()`                 | removed                                                                                    |
| `PostgrestQueryBuilder<T>`                                                                   | `PostgrestQueryBuilder`                                                                    |

`PostgrestClient.headers` is an unmodifiable map. Set headers on the constructor for all requests,
or with `setHeader()` on a builder for a single request.

On `SupabaseClient`, assigning `supabase.headers` replaces the rest client with one carrying the new
headers, so in-place mutation of `supabase.rest.headers` throws an `UnsupportedError`. A
`PostgrestClient` reference captured before the assignment keeps the headers it was built with, and
so does the `SupabaseQuerySchema` returned by `supabase.schema(…)`. Read `supabase.rest` or call
`supabase.schema(…)` again, and create new builders, after changing `supabase.headers`.

`insert()`, `upsert()`, `update()` and `delete()` without a trailing `select()` now resolve to
`void` everywhere, where `supabase.from()` used to yield `dynamic`. That value was always `null`, so
drop the assignment or add `select()` to actually return data.

`supabase.from('countries')` by itself no longer implements `Future` and cannot be awaited,
converted with `withConverter()`, or given an `abortSignal()`. Call `select()`, `insert()`,
`upsert()`, `update()`, `delete()` or `count()` first; everything after that point is unchanged.
`setHeader()` and `retry()` remain available before the operation:

```dart
// Before: compiled, but threw an ArgumentError at runtime.
await supabase.from('countries');

// After: does not compile. Choose an operation first.
await supabase.from('countries').select();
```

### `createSignedUrls` reports per-path failures

`createSignedUrls` returns a list of `SignedUrlSuccess` and `SignedUrlFailure` instead of
`List<SignedUrl>`, and the separate `createSignedUrlsResult` is removed. If you were already calling
`createSignedUrlsResult`, drop the `Result` suffix.

```dart
// Before
final urls = await supabase.storage
    .from('avatars')
    .createSignedUrls(['a.png', 'b.png'], 60);
for (final url in urls) {
  print(url.signedUrl);
}

// After
final results = await supabase.storage
    .from('avatars')
    .createSignedUrls(['a.png', 'b.png'], 60);
for (final result in results) {
  switch (result) {
    case SignedUrlSuccess(:final signedUrl):
      print(signedUrl);
    case SignedUrlFailure(:final path, :final error):
      print('could not sign $path: $error');
  }
}
```

### `RealtimeClient.connectionState` is now typed

`connectionState` keeps its name but changes from a `String` getter to `SocketState?`, and the typed
`connState` field is gone. This is not a compile error if you were only reading the string, so check
every use site.

```dart
// Before
if (client.connectionState == 'open') {
  // ...
}

// After
if (client.connectionState == SocketState.open) {
  // ...
}
```

Use `connectionState?.name` for the string form. To check whether the socket is up,
`RealtimeClient.isConnected` is unchanged and is the better choice.

If you were using the typed field under its old name, rename it:

```dart
// Before
final SocketStates? state = client.connState;

// After
final SocketState? state = client.connectionState;
```

### The mutable internals of `RealtimeClient` are private

| Before                                                          | After                                         |
| --------------------------------------------------------------- | --------------------------------------------- |
| `client.channels` (mutable list)                                | `client.channels` (unmodifiable view)         |
| `client.getChannels()`                                          | `client.channels`                             |
| `supabase.getChannels()`                                        | `supabase.channels`                           |
| `client.accessToken = token`                                    | `await client.setAccessToken(token)`          |
| `client.heartbeatInterval = interval`                           | `RealtimeClient(heartbeatInterval: interval)` |
| `client.customAccessToken = getter`                             | `RealtimeClient(customAccessToken: getter)`   |
| `client.reconnectAfter = calculation`                           | `RealtimeClient(reconnectAfter: calculation)` |
| `client.connection = channel`                                   | removed, the getter remains                   |
| `client.connectionState = state`                                | removed, the getter remains                   |
| `client.headers['key'] = value`                                 | `RealtimeClient(headers: headers)`            |
| `client.heartbeatTimer`, `client.reconnectTimer`                | removed                                       |
| `client.ref`, `client.pendingHeartbeatRef`, `client.sendBuffer` | internal and test-only                        |

Channels are added with `channel()` and removed with `removeChannel()` or `removeAllChannels()`.
Mutating the `channels`, `headers` or `parameters` views throws an `UnsupportedError`. Unlike the
removed field write, `setAccessToken()` also propagates the new token to every joined channel.

```dart
// Before
final client = RealtimeClient(realtimeUrl);
client.heartbeatInterval = const Duration(seconds: 60);
client.accessToken = newToken;
final channels = client.getChannels();

// After
final client = RealtimeClient(
  realtimeUrl,
  heartbeatInterval: const Duration(seconds: 60),
);
await client.setAccessToken(newToken);
final channels = client.channels;
```

When the client is managed by a `SupabaseClient`, pass the heartbeat interval and the reconnect
backoff through `RealtimeClientOptions`, and the headers through `SupabaseClient.headers`:

```dart
final supabase = SupabaseClient(
  supabaseUrl,
  supabaseKey,
  realtimeClientOptions: const RealtimeClientOptions(
    heartbeatInterval: Duration(seconds: 60),
  ),
);
```

### The mutable internals of `RealtimeChannel` are private

| Before                             | After                                                |
| ---------------------------------- | ---------------------------------------------------- |
| `channel.joinedOnce = value`       | removed, the getter remains (internal)               |
| `channel.joinPush = push`          | removed, the getter remains (internal and test-only) |
| `channel.presence`                 | removed                                              |
| `channel.parameters` (mutable map) | `channel.parameters` (unmodifiable view, internal)   |

If you read presence state through `channel.presence`, use `channel.presenceState()` and the
`onPresenceSync`, `onPresenceJoin` and `onPresenceLeave` streams instead. Pass channel configuration
through `RealtimeChannelConfig` when creating the channel.

### Broadcasts no longer fall back to the REST API

`sendBroadcastMessage()` only sends over the WebSocket. Calling it on a channel that was never
subscribed throws. Use `httpSend()` for the REST path, which works without subscribing:

```dart
// Before
final channel = supabase.channel('room');
// Delivered over REST because the channel was never subscribed.
await channel.sendBroadcastMessage(
  event: 'cursor-pos',
  payload: {'x': 12, 'y': 34},
);

// After, over REST
final channel = supabase.channel('room');
await channel.httpSend(
  event: 'cursor-pos',
  payload: {'x': 12, 'y': 34},
);

// After, over the WebSocket
final channel = supabase.channel('room')..subscribe();
await channel.sendBroadcastMessage(
  event: 'cursor-pos',
  payload: {'x': 12, 'y': 34},
);
```

Messages sent between `subscribe()` and the channel actually joining are still buffered and flushed
once the join succeeds, so only channels that were never subscribed throw.

`httpSend()` requires a Realtime server running v2.97.0 or newer.

### Realtime listener callbacks are now streams

Every recurring-event listener in `supabase_realtime` is a Dart `Stream` instead of a callback.

On `RealtimeClient`, the four connection callbacks are replaced by two broadcast streams:
`onStatusChange` for the connection lifecycle and `onMessage` for every decoded frame. Connection
errors are emitted as stream errors on `onStatusChange`:

```dart
// Before
client.onOpen(() => print('open'));
client.onClose((event) => print('closed: $event'));
client.onError((error) => print('error: $error'));
client.onMessage((message) => print('message: $message'));

// After
client.onStatusChange.listen(
  (change) => switch (change.status) {
    RealtimeConnectionStatus.open => print('open'),
    RealtimeConnectionStatus.closed => print('closed: ${change.closeEvent}'),
  },
  onError: (error) => print('error: $error'),
);
client.onMessage.listen((message) => print('message: $message'));
```

On `RealtimeChannel`, `onPostgresChanges` and `onBroadcast` no longer take a `callback` parameter
and return a typed stream instead of the channel, so they can no longer be chained. Repeated calls
with the same arguments return the same stream. For `postgres_changes` the stream still has to be
created before `subscribe()`, but it can be listened to at any point:

```dart
// Before
supabase
    .channel('room')
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) => print(payload),
    )
    .onBroadcast(
      event: 'cursor-pos',
      callback: (payload) => print(payload),
    )
    .subscribe();

// After
final channel = supabase.channel('room');
channel
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
    )
    .listen(print);
channel.onBroadcast(event: 'cursor-pos').listen(print);
channel.subscribe();
```

The presence and system listeners are stream getters, and `onSystemEvents` emits a typed
`RealtimeSystemPayload` instead of a raw payload:

```dart
// Before
channel.onPresenceSync((payload) { /* ... */ });
channel.onPresenceJoin((payload) { /* ... */ });
channel.onPresenceLeave((payload) { /* ... */ });
channel.onSystemEvents((payload) {
  final system = RealtimeSystemPayload.fromJson(
    Map<String, dynamic>.from(payload as Map),
  );
});

// After
channel.onPresenceSync.listen((payload) { /* ... */ });
channel.onPresenceJoin.listen((payload) { /* ... */ });
channel.onPresenceLeave.listen((payload) { /* ... */ });
channel.onSystemEvents.listen((system) { /* ... */ });
```

`subscribe()` no longer takes a status callback. Status changes are emitted on the new
`RealtimeChannel.onStatusChange` stream as `RealtimeSubscribeStatusChange` values, which carry the
`RealtimeSubscribeStatus` and, for `channelError`, the error that caused it. The optional timeout is
now the first positional parameter:

```dart
// Before
channel.subscribe((status, [error]) {
  if (status == RealtimeSubscribeStatus.subscribed) {
    // ...
  } else if (status == RealtimeSubscribeStatus.channelError) {
    print('error: $error');
  }
}, const Duration(seconds: 10));

// After
channel.onStatusChange.listen((change) {
  if (change.status == RealtimeSubscribeStatus.subscribed) {
    // ...
  } else if (change.status == RealtimeSubscribeStatus.channelError) {
    print('error: ${change.error}');
  }
});
channel.subscribe(const Duration(seconds: 10));
```

All channel streams complete when the channel closes, so `await for` loops and `onDone` handlers end
on their own once the channel is gone.

### `Binding` and `BindingCallback` are internal

`Binding` and `BindingCallback` are no longer exported, along with their only consumers
`RealtimeChannel.onEvents` and `RealtimeChannel.off`. Use the typed channel streams
(`onPostgresChanges`, `onBroadcast`, `onPresenceSync`, `onPresenceJoin`, `onPresenceLeave`,
`onSystemEvents`) instead.

### `RealtimePresence` is internal

`RealtimePresence` and its helper types (`PresenceOptions`, `PresenceEvents`, `PresenceChooser`,
`PresenceOnJoinCallback`, `PresenceOnLeaveCallback`) are `@internal`, along with the
`RealtimeChannel.presence` field. Everything the class offered is available on the channel:

```dart
// Before
channel.presence.onJoin((key, current, joined) { /* ... */ });
channel.presence.onLeave((key, current, left) { /* ... */ });
channel.presence.onSync(() { /* ... */ });
final Map<String, List<Presence>> state = channel.presence.state;

// After
channel.onPresenceJoin.listen((payload) { /* ... */ });
channel.onPresenceLeave.listen((payload) { /* ... */ });
channel.onPresenceSync.listen((payload) { /* ... */ });
final List<SinglePresenceState> state = channel.presenceState();
```

`presenceState()` returns a `List<SinglePresenceState>` rather than a map, so a presence key is read
from `SinglePresenceState.key` and its payloads from `SinglePresenceState.presences`. When code
depended on the map, rebuild it from the list:

```dart
final byKey = {
  for (final state in channel.presenceState()) state.key: state.presences,
};
```

The `Presence` payload class is unchanged and stays public.

### `RealtimeEncode` and `RealtimeDecode` are asynchronous and typed

Both codec typedefs on `RealtimeClient` now work on a `RealtimeMessage` and return a `Future`:

| Before                                  | After                                      |
| --------------------------------------- | ------------------------------------------ |
| `Object Function(Map<String, dynamic>)` | `Future<Object> Function(RealtimeMessage)` |
| `Map<String, dynamic> Function(Object)` | `Future<RealtimeMessage> Function(Object)` |

```dart
final isolate = YAJsonIsolate();

final client = RealtimeClient(
  'wss://project.supabase.co/realtime/v1',
  encode: (message) => isolate.encode(message.toJson()),
  decode: (frame) async =>
      RealtimeMessage.fromJson(await isolate.decode(frame as String)),
);
```

`RealtimeMessage` carries the `joinRef`, `ref`, `topic`, `event` and `payload` of a message, and
converts to and from the shape a protocol version puts on the wire. `toJson` and
`RealtimeMessage.fromJson` default to protocol `2.0.0`; pass `RealtimeProtocolVersion.v1` to either
when the client runs on the legacy protocol.

`RealtimeClient.onMessage` emits `RealtimeMessage` instead of `Map<String, dynamic>`, so a listener
that reads fields off the map needs to switch to properties:

```dart
// Before
client.onMessage.listen((message) => print(message['event']));

// After
client.onMessage.listen((message) => print(message.event));
```

`RealtimeClientOptions` takes the same two callbacks, so a codec can be set on `SupabaseClient` and
on `Supabase.initialize` without constructing a `RealtimeClient` yourself:

```dart
await Supabase.initialize(
  url: url,
  publishableKey: publishableKey,
  realtimeClientOptions: RealtimeClientOptions(
    encode: (message) => isolate.encode(message.toJson()),
    decode: (frame) async =>
        RealtimeMessage.fromJson(await isolate.decode(frame as String)),
  ),
);
```

`encode` and `decode` are `null` unless you pass one, and reading a custom codec back off the client
changed accordingly:

```dart
// Before
final Map<String, dynamic> message = client.decode(frame);

// After
final RealtimeMessage message = await client.decode!(frame);
```

A codec replaces the built-in one completely, so the one above handles text frames only. Handle a
`Uint8List` frame as well if you send or receive binary broadcasts. A codec call that never
completes fails after `RealtimeClient.timeout`.

### `RealtimeClient.logger` and `RealtimeClient.log` are gone

The `logger` constructor parameter and the public `log` method are removed. Realtime diagnostics are
emitted on the `supabase.realtime` logger, so listen there instead.

```dart
// Before
final client = RealtimeClient(
  realtimeUrl,
  logger: (kind, message, data) => print('$kind: $message $data'),
);

// After
hierarchicalLoggingEnabled = true;
Logger('supabase.realtime').onRecord.listen((record) {
  print('${record.level.name}: ${record.message} ${record.error ?? ''}');
});
final client = RealtimeClient(realtimeUrl);
```

Without `hierarchicalLoggingEnabled = true`, `package:logging` resolves the `onRecord` stream of a
non-root logger to `Logger.root.onRecord`, which receives records from every logger in the
application; in that case listen on `Logger.root` and filter on `LogRecord.loggerName` instead.

### Timestamps are `DateTime` instead of `String` or `int`

Every timestamp the SDK returns is a `DateTime` in UTC instead of an ISO 8601 `String` or a Unix
timestamp `int`.

| Type            | Fields                                                                                                                                        | Before                | After       |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- | ----------- |
| `Session`       | `expiresAt`                                                                                                                                   | `int?` (Unix seconds) | `DateTime?` |
| `User`          | `createdAt`                                                                                                                                   | `String`              | `DateTime`  |
| `User`          | `confirmationSentAt`, `recoverySentAt`, `emailChangeSentAt`, `invitedAt`, `emailConfirmedAt`, `phoneConfirmedAt`, `lastSignInAt`, `updatedAt` | `String?`             | `DateTime?` |
| `UserIdentity`  | `createdAt`, `lastSignInAt`, `updatedAt`                                                                                                      | `String?`             | `DateTime?` |
| `OAuthClient`   | `createdAt`, `updatedAt`                                                                                                                      | `String`              | `DateTime`  |
| `Bucket`        | `createdAt`, `updatedAt`                                                                                                                      | `String`              | `DateTime`  |
| `FileObject`    | `createdAt`, `updatedAt`                                                                                                                      | `String?`             | `DateTime?` |
| `FileObjectV2`  | `createdAt`                                                                                                                                   | `String`              | `DateTime`  |
| `FileObjectV2`  | `updatedAt`, `lastModified`                                                                                                                   | `String?`             | `DateTime?` |
| `PaginatedFile` | `createdAt`, `updatedAt`                                                                                                                      | `String?`             | `DateTime?` |

```dart
// Before
final expiresAt = supabase.auth.currentSession?.expiresAt;
final expiry = expiresAt == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
final createdAt = DateTime.parse(user.createdAt);

// After
final expiry = supabase.auth.currentSession?.expiresAt;
final createdAt = user.createdAt;
```

If you need the previous representation, ask for it explicitly:

```dart
final isoString = user.createdAt.toIso8601String();
final unixSeconds = session.expiresAt!.millisecondsSinceEpoch ~/ 1000;
```

`toJson()` output is unchanged, so sessions persisted by v2 are still readable by v3.

Three behavioural details are worth checking:

- The `DateTime` values are in UTC. `DateTime` equality takes the time zone flag into account, so
  compare against `DateTime.utc(...)` rather than `DateTime(...)`, or call `toLocal()` first.
- `User.createdAt` used to fall back to an empty string when the field was missing and now throws a
  `FormatException`.
- A timestamp naming a date that does not exist is rejected rather than rolled forward.
  `DateTime.parse` reads `2019-02-29` as 1 March 2019; parsing now throws a `FormatException`.

### Plural enum names singularized

| Before                         | After                         | Package             |
| ------------------------------ | ----------------------------- | ------------------- |
| `SocketStates`                 | `SocketState`                 | `supabase_realtime` |
| `PostgresTypes`                | `PostgresType`                | `supabase_realtime` |
| `AuthenticatorAssuranceLevels` | `AuthenticatorAssuranceLevel` | `supabase_auth`     |
| `LoadTableSnapshots`           | `TableSnapshotScope`          | `iceberg`           |

No enum values changed, so the only work is renaming the type where you name it explicitly.

```dart
// Before
final AuthenticatorAssuranceLevels? level =
    supabase.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel;

// After
final AuthenticatorAssuranceLevel? level =
    supabase.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel;
```

```dart
// Before
await catalog.loadTableResult(
  id,
  const LoadTableOptions(snapshots: LoadTableSnapshots.refs),
);

// After
await catalog.loadTableResult(
  id,
  const LoadTableOptions(snapshots: TableSnapshotScope.refs),
);
```

### One shared `SortDirection` for every sort direction

| Before            | After           |
| ----------------- | --------------- |
| `BucketSortOrder` | `SortDirection` |
| `FileSortOrder`   | `SortDirection` |
| `SortDirection`   | unchanged       |

The values are unchanged, so only the type name moves:

```dart
// Before
await supabase.storage.listBuckets(
  const ListBucketsOptions(sortOrder: BucketSortOrder.descending),
);

// After
await supabase.storage.listBuckets(
  const ListBucketsOptions(sortOrder: SortDirection.descending),
);
```

`SortBy.order` is a `SortDirection` too, rather than a `String`. It is non-nullable with
`SortDirection.ascending` as its default:

```dart
// Before
await supabase.storage.from('bucket').list(
      searchOptions: const SearchOptions(
        sortBy: SortBy(column: 'created_at', order: 'desc'),
      ),
    );

// After
await supabase.storage.from('bucket').list(
      searchOptions: const SearchOptions(
        sortBy: SortBy(column: 'created_at', order: SortDirection.descending),
      ),
    );
```

`SortBy(order: null)` no longer compiles; leave `order` out to sort ascending. `column` is
unchanged.

### `HttpMethod` is one shared enum

`supabase_functions` and `postgrest` each declared their own `HttpMethod`. There is now one, shaped
like postgrest's and re-exported from both, so imports are unchanged and postgrest callers are
unaffected. For `functions.invoke`, two things changed:

- `head` was added, so an exhaustive `switch` over `HttpMethod` no longer compiles until you handle
  it.
- The values were reordered, so `index` shifted for `post` (1 to 2), `put` (2 to 3) and `delete`
  (3 to 5). This is not a compile error, so replace any persisted `index` with `name`.

The enum also exposes `value`, the uppercase wire form, in place of `method.name.toUpperCase()`.

### Service exceptions share one base

`AuthException`, `PostgrestException`, `StorageException` and `FunctionException` now extend a
shared `SupabaseException`, and the ones reporting a response from a service also mix in
`SupabaseApiException`:

```dart
abstract class SupabaseException implements Exception {
  final String message;
  final String? errorCode;
}

mixin SupabaseApiException on SupabaseException {
  int get statusCode;
}
```

Both types are re-exported from every package, so one catch handles a failure from any service:

```dart
try {
  await supabase.from('countries').select();
} on SupabaseApiException catch (error) {
  print('${error.statusCode}: ${error.message}');
} on SupabaseException catch (error) {
  print(error.message);
}
```

The renames:

| Before                                         | After                                                                   |
| ---------------------------------------------- | ----------------------------------------------------------------------- |
| `AuthException.statusCode` (`String?`)         | `AuthApiException.statusCode` (`int`)                                   |
| `AuthException.code`                           | `AuthException.errorCode`                                               |
| `StorageException.statusCode` (`String?`)      | `StorageApiException.statusCode` (`int`)                                |
| `StorageException.error`                       | `errorCode`                                                             |
| `StorageException.fromJson(json, '404')`       | `StorageApiException.fromJson(json, 404)`                               |
| `PostgrestException`                           | `PostgrestApiException`                                                 |
| `PostgrestException.code`                      | `PostgrestApiException.errorCode`, with the HTTP status in `statusCode` |
| `PostgrestException.fromJson(json, code: 409)` | `PostgrestApiException.fromJson(json, statusCode: 409)`                 |
| `PostgrestException.toJson()` key `code`       | keys `statusCode` and `errorCode`                                       |
| `FunctionsHttpException`                       | `FunctionsApiException`                                                 |
| `FunctionException.status` (`int`)             | `FunctionsApiException.statusCode`                                      |
| `FunctionException.reasonPhrase`               | folded into `message`                                                   |
| `FunctionsFetchException.status == 0`          | no status at all, no response reached the client                        |
| `FunctionResponse.status`                      | `FunctionResponse.statusCode`                                           |

Reading a status off a per-service base no longer compiles, since the base no longer has one.
Narrow the catch to the API type:

```dart
// Before
try {
  await supabase.auth.signInWithPassword(email: email, password: password);
} on AuthException catch (error) {
  if (error.statusCode == '429') {
    // ...
  }
}

// After
try {
  await supabase.auth.signInWithPassword(email: email, password: password);
} on AuthApiException catch (error) {
  if (error.statusCode == 429) {
    // ...
  }
}
```

Four changes go beyond a rename:

- `PostgrestApiException.errorCode` is only ever the PostgREST or PostgreSQL code and `statusCode`
  only ever the HTTP status, where `PostgrestException.code` held either. A duplicate key violation
  reads as `statusCode: 409, errorCode: '23505'`.
- `AuthSessionMissingException` and `AuthInvalidJwtException` report no status, since they are
  raised without making a request. They report `errorCode` values of `session_missing` and
  `invalid_jwt` instead.
- `AuthRetryableFetchException` covers only the transport case, where the request never reached the
  service. A retryable 5xx the service answered is an `AuthRetryableApiException`, which carries the
  status. Catching `AuthRetryableFetchException` still gets both.
- `FunctionException` gained a `message`, taken from the response's reason phrase and falling back
  to a per-subtype default when the response carries none, as over HTTP/2. The response body is
  still in `details`.

`AuthUnknownException` no longer reports a status of its own. Read it from `originalError` when that
is an `http.Response`. `RealtimeSubscribeException` is not part of this hierarchy and carries a
`RealtimeSubscribeStatus` instead of a message.

### `FunctionException` is sealed

`FunctionException` is a `sealed class`, so a switch over it is exhaustive at compile time:

```dart
try {
  await supabase.functions.invoke('hello');
} on FunctionException catch (error) {
  final message = switch (error) {
    FunctionsFetchException() => 'The request never reached the function',
    FunctionsRelayException() => 'The relay reported an error',
    FunctionsApiException() => 'The function returned ${error.statusCode}',
  };
}
```

`FunctionsRelayException` extends `FunctionsApiException`, so it has to come first for its case to
be reachable. Only `FunctionsFetchException` and `FunctionsApiException` are needed for the switch
to be exhaustive.

A bare `FunctionException` can no longer be constructed, and code outside `supabase_functions` can
no longer extend or implement it. Name one of the three subtypes instead.

### The Iceberg exceptions join the same hierarchy

`IcebergException` splits into two, the same way the other packages do:

|                           |                                                                       |
| ------------------------- | --------------------------------------------------------------------- |
| `IcebergNetworkException` | no response was received from the catalog, so there is no status code |
| `IcebergApiException`     | the catalog answered, so `statusCode` is a real, non-nullable status  |

`IcebergApiException` is the sealed base for the response-backed subtypes, which are unchanged:
`IcebergNotFoundException`, `IcebergConflictException`, `IcebergAuthenticationTimeoutException`,
`IcebergCommitStateUnknownException`, `IcebergServerException` and `IcebergUnknownException`.

| Before                             | After                                                               |
| ---------------------------------- | ------------------------------------------------------------------- |
| `IcebergException.type`            | `errorCode`, from `SupabaseException`                               |
| `IcebergException.statusCode`      | `IcebergApiException.statusCode`; gone from the network case        |
| `IcebergException.statusCode == 0` | catch `IcebergNetworkException`, or check `is SupabaseApiException` |
| `IcebergException.fromResponse`    | `IcebergApiException.fromResponse`                                  |

`message`, `code` and `details` keep their names. `code` is still the Iceberg numeric error code,
which is unrelated to `errorCode`, the string error type such as `NoSuchTableException`.

```dart
// Before
try {
  await catalog.loadTable(id);
} on IcebergException catch (error) {
  if (error.statusCode == 0) {
    // no response was received
  }
  print(error.type);
}

// After
try {
  await catalog.loadTable(id);
} on IcebergNetworkException catch (error) {
  // no response was received, so the outcome of the request is unknown
  print(error.details);
} on IcebergApiException catch (error) {
  print('${error.statusCode}: ${error.errorCode}');
}
```

Exhaustive switches over the sealed hierarchy still compile with the same set of cases.

### Every client takes one `SupabaseRetryOptions`

PostgREST, storage and the auth token refresh all take the same `SupabaseRetryOptions`, which
carries `enabled`, `count`, `initialDelay`, `maxDelay` and `randomizationFactor`.

| Before                                                                                                                                              | After                                                                 |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `PostgrestClient(retryEnabled: …, retryCount: …)`                                                                                                   | `PostgrestClient(retryOptions: …)`                                    |
| `PostgrestClientOptions(retryEnabled: …, retryCount: …)`                                                                                            | `PostgrestClientOptions(retryOptions: …)`                             |
| `PostgrestBuilder`, `PostgrestQueryBuilder` and `PostgrestRpcBuilder` constructors, same parameters                                                 | `retryOptions: …`                                                     |
| `SupabaseStorageClient(retryAttempts: 5)`                                                                                                           | `SupabaseStorageClient(retryOptions: SupabaseRetryOptions(count: 5))` |
| `StorageClientOptions(retryAttempts: 5)`                                                                                                            | `StorageClientOptions(retryOptions: SupabaseRetryOptions(count: 5))`  |
| `upload(…, retryAttempts: 5)` and the same parameter on `uploadBinary`, `uploadToSignedUrl`, `uploadBinaryToSignedUrl`, `update` and `updateBinary` | `retryOptions: SupabaseRetryOptions(count: 5)`                        |

```dart
// Before
postgrestOptions: const PostgrestClientOptions(retryCount: 5),
storageOptions: const StorageClientOptions(retryAttempts: 5),

// After
postgrestOptions: const PostgrestClientOptions(
  retryOptions: SupabaseRetryOptions(count: 5),
),
storageOptions: const StorageClientOptions(
  retryOptions: SupabaseRetryOptions(count: 5),
),
```

`count` is the number of retries after the first attempt, so `count: 0` sends a request exactly
once. The old storage `retryAttempts` counted the same way, so the number carries over unchanged.

The auth token refresh is configurable for the first time, through `AuthClientOptions.retryOptions`
and `AuthClient(retryOptions: …)`. It still stops retrying once the next backoff would fall after
the next refresh tick.

The per-request `PostgrestBuilder.retry()` override keeps `enabled` and `count`. Its
`requestTimeout` parameter is now a method of its own, see
[the builder section](#the-postgrest-builder-has-one-type-parameter-and-no-wrapper-classes).

### The PostgREST builder has one type parameter and no wrapper classes

`PostgrestBuilder<T, S, R>` is now `PostgrestBuilder<T>`, where `T` is the type the request resolves
to when awaited. `RawPostgrestBuilder` and `ResponsePostgrestBuilder` are gone; `withConverter()` and
`count()` are methods of `PostgrestBuilder<T>` itself.

| Before                                                                   | After                                           |
| ------------------------------------------------------------------------ | ----------------------------------------------- |
| `PostgrestBuilder<T, S, R>`                                              | `PostgrestBuilder<T>`                           |
| `RawPostgrestBuilder<T, S, R>` and `ResponsePostgrestBuilder<T, S, R>`   | `PostgrestBuilder<T>`                           |
| `PostgrestBuilder(count: …, converter: …)`                               | `PostgrestBuilder(…).withConverter(…).count(…)` |
| `geojson()` returned `ResponsePostgrestBuilder<Map<String, dynamic>, …>` | `PostgrestBuilder<Map<String, dynamic>>`        |

`withConverter()` converts whatever the request resolves to at the point where it is called. Without
`count()` nothing changes. With `count()`, call `withConverter()` first so the converter keeps
receiving the data:

```dart
// Before
final response = await supabase
    .from('users')
    .select()
    .count(CountOption.exact)
    .withConverter((rows) => rows.map(User.fromJson).toList());

// After
final response = await supabase
    .from('users')
    .select()
    .withConverter((rows) => rows.map(User.fromJson).toList())
    .count(CountOption.exact);
final List<User> users = response.data;
final int count = response.count;
```

A converter placed after `count()` receives the whole `PostgrestResponse`, so the old order no
longer compiles and the compiler points at every call site to update.

The per-request timeout override is a method of its own instead of a parameter of `retry()`:

| Before                                                   | After                                                   |
| -------------------------------------------------------- | ------------------------------------------------------- |
| `.retry(requestTimeout: Duration(seconds: 5))`           | `.requestTimeout(Duration(seconds: 5))`                 |
| `.retry(count: 5, requestTimeout: Duration(seconds: 5))` | `.retry(count: 5).requestTimeout(Duration(seconds: 5))` |

`requestTimeout()` is available wherever `retry()` is: on the query builder before the table
operation, and on every builder after it, where filters and transforms can still follow it.

### The retry backoff defaults are the same in every client

One curve is used everywhere: the first retry waits 400 ms, every retry after that waits twice as
long up to 30 seconds, and each delay is randomized by up to 25%.

| Client             | Before                                    | After                                               |
| ------------------ | ----------------------------------------- | --------------------------------------------------- |
| `postgrest`        | 3 retries, 1s doubling to 30s, no jitter  | 3 retries on the shared curve                       |
| `supabase_storage` | opt-in, 400ms doubling to 30s, 25% jitter | unchanged, still opt-in with `count: 0`             |
| `supabase_auth`    | 400ms doubling to 10s, no jitter          | shared curve, bounded by the refresh tick as before |

PostgREST reads therefore back off sooner than they did, and with jitter. Pass your own
`SupabaseRetryOptions` to keep the old curve:

```dart
postgrestOptions: const PostgrestClientOptions(
  retryOptions: SupabaseRetryOptions(
    initialDelay: Duration(seconds: 1),
    randomizationFactor: 0,
  ),
),
```

### The retried status codes are no longer configurable

`503 Service Unavailable` and `520 Unknown Error` are the only responses that are retried, and the
set is fixed.

| Before                                            | After                                  |
| ------------------------------------------------- | -------------------------------------- |
| `PostgrestClient(retryableStatusCodes: …)`        | removed                                |
| `PostgrestClientOptions(retryableStatusCodes: …)` | removed                                |
| `PostgrestClient.defaultRetryableStatusCodes`     | `PostgrestClient.retryableStatusCodes` |

If you retried a status code outside that set, catch the exception and decide what to do with it
yourself:

```dart
// Before
postgrestOptions: const PostgrestClientOptions(
  retryableStatusCodes: {500, 503, 520},
),

// After
try {
  await supabase.from('todos').select();
} on PostgrestApiException catch (error) {
  if (error.statusCode == 500) {
    // Retry it yourself, or surface it.
  }
}
```

### `setAccessToken()` is gone from the rest, storage and functions clients

`PostgrestClient.setAccessToken()`, `SupabaseStorageClient.setAccessToken()` and
`FunctionsClient.setAccessToken()` are removed. `RealtimeClient.setAccessToken()` stays.

If you never called them, nothing changes. If you did, the replacement depends on what you were
after.

To authenticate as the signed-in user, do nothing. `SupabaseClient` already resolves that token on
every request.

On a client you construct yourself, pass an `accessToken` callback. It is resolved before every
request, so a token that rotates is picked up without you pushing the new value anywhere:

```dart
// Before
final functions = FunctionsClient(functionsUrl, {'apikey': anonKey});
functions.setAccessToken(jwt);

// After
final functions = FunctionsClient(
  functionsUrl,
  {'apikey': anonKey},
  accessToken: () async => currentJwt,
);
```

`PostgrestClient` and `SupabaseStorageClient` take the same callback. If the token never changes, a
constructor header is still enough:

```dart
final functions = FunctionsClient(functionsUrl, {
  'apikey': anonKey,
  'Authorization': 'Bearer $jwt',
});
```

Passing both an `Authorization` header and `accessToken` asserts.

To use a different token for a single call, pass it to that call:

```dart
await functions.invoke('hello', headers: {'Authorization': 'Bearer $jwt'});
await postgrest.from('countries').select().setHeader('Authorization', 'Bearer $jwt');
```

To pin a token on a client you got from `SupabaseClient`, set the header yourself:

```dart
supabase.storage.setHeader('Authorization', 'Bearer $jwt');
supabase.functions.setHeader('Authorization', 'Bearer $jwt');
```

The rest client is stateless and its header map unmodifiable (see
[the stateless rest client](#the-rest-client-and-its-builders-are-stateless)), so a pinned token is
passed per request there, or client-wide through the `headers` setter of `SupabaseClient`:

```dart
await supabase.from('countries').select().setHeader('Authorization', 'Bearer $jwt');
supabase.headers = {...supabase.headers, 'Authorization': 'Bearer $jwt'};
```

Remove the header again once the pinned token should no longer apply.

### Client header maps are unmodifiable

Every `headers` getter returns an unmodifiable view, and mutating one throws an `UnsupportedError`.

| Before                                            | After                                                      |
| ------------------------------------------------- | ---------------------------------------------------------- |
| `supabase.auth.headers['X-Foo'] = 'bar'`          | `supabase.headers = {...supabase.headers, 'X-Foo': 'bar'}` |
| `supabase.functions.headers['X-Foo'] = 'bar'`     | `supabase.headers = {...supabase.headers, 'X-Foo': 'bar'}` |
| `supabase.storage.headers['X-Foo'] = 'bar'`       | `supabase.storage.setHeader('X-Foo', 'bar')`               |
| `storage.from('bucket').headers['X-Foo'] = 'bar'` | `storage.from('bucket').setHeader('X-Foo', 'bar')`         |
| `authClient.headers['X-Foo'] = 'bar'`             | `authClient.setHeader('X-Foo', 'bar')`                     |
| `functionsClient.headers['X-Foo'] = 'bar'`        | `functionsClient.setHeader('X-Foo', 'bar')`                |

To add a single header, the auth, functions and storage clients have a `setHeader()` method, and
storage has one per bucket as well. A whole set of headers is passed to the constructor. For a
client managed by a `SupabaseClient`, assign `SupabaseClient.headers`, which propagates the new
headers to every sub-client at once.

`SupabaseStorageClient.vectors` is a getter that builds a client on each access instead of a cached
instance, so it always carries the current headers. Hold on to the returned client only for as long
as its headers should stay fixed.

### The SDK no longer prints logs

`Supabase.initialize` no longer takes a `debug` flag and never prints anything to the console. All
packages still emit their records through [`package:logging`](https://pub.dev/packages/logging)
under the `supabase` logger hierarchy, so handle them yourself:

```dart
// Before
await Supabase.initialize(
  url: supabaseUrl,
  publishableKey: supabaseKey,
  debug: true,
);

// After
Logger.root.onRecord.listen((record) {
  if (record.loggerName.startsWith('supabase.')) {
    debugPrint('${record.loggerName}: ${record.level.name}: '
        '${record.message} ${record.error ?? ''}');
  }
});
await Supabase.initialize(
  url: supabaseUrl,
  publishableKey: supabaseKey,
);
```

See the `Logging` section of the `supabase_flutter` README for level filtering with
`hierarchicalLoggingEnabled`.

Two logger names changed, so update any listeners that filter on `LogRecord.loggerName`:

| Before                      | After              |
| --------------------------- | ------------------ |
| `supabase.supabase`         | `supabase.dart`    |
| `supabase.supabase_flutter` | `supabase.flutter` |

### JSON encoding and decoding is behind the `AsyncJsonCodec` interface

`SupabaseClient`, `PostgrestClient` and `FunctionsClient` take an `AsyncJsonCodec` through
`jsonCodec:` instead of a `YAJsonIsolate` through `isolate:`. The same rename applies to
`PostgrestBuilder`, `PostgrestQueryBuilder`, `PostgrestRpcBuilder`, `SupabaseQueryBuilder` and
`SupabaseQuerySchema`.

```dart
// Before
final client = SupabaseClient(url, key, isolate: YAJsonIsolate()..initialize());

// After
final client = SupabaseClient(url, key, jsonCodec: YAJsonIsolate()..initialize());
```

`Supabase.initialize` takes the codec too:

```dart
await Supabase.initialize(
  url: url,
  publishableKey: publishableKey,
  jsonCodec: myJsonCodec,
);
```

`AsyncJsonCodec` is exported from `postgrest`, `supabase_functions`, `supabase` and
`supabase_flutter`, so an application can encode and decode JSON its own way:

```dart
class TimedJsonCodec implements AsyncJsonCodec {
  TimedJsonCodec(this._inner);

  final AsyncJsonCodec _inner;

  @override
  Future<dynamic> decode(String json) => _time(() => _inner.decode(json));

  @override
  Future<dynamic> decodeBytes(Uint8List encodedJson) =>
      _time(() => _inner.decodeBytes(encodedJson));

  @override
  Future<String> encode(Object? json) => _time(() => _inner.encode(json));

  @override
  Future<void> dispose() => _inner.dispose();
}
```

A codec passed to a client belongs to the caller, so `dispose()` leaves it alone, exactly as the old
`isolate:` parameter did. `SupabaseClient` passes its codec on to the rest and functions clients it
builds.

`YAJsonIsolate` is not exported by `supabase` or `supabase_flutter`, so depend on
`yet_another_json_isolate` directly to name the default implementation.

### Abbreviations in the public API are spelled out

The wire format is unchanged throughout: where a JSON key, query parameter or URL path matched the
abbreviation, only the Dart identifier is renamed.

Across every package:

| Before                     | After                             |
| -------------------------- | --------------------------------- |
| `RealtimeClient.setAuth()` | `RealtimeClient.setAccessToken()` |
| `queryParams:`             | `queryParameters:`                |
| `opts:`                    | `options:`                        |
| `PresenceOpts`             | `PresenceOptions`                 |
| `appendSearchParams`       | `appendSearchParameters`          |
| `overrideSearchParams`     | `overrideSearchParameters`        |
| `toQueryParams`            | `toQueryParameters`               |

`supabase_realtime`:

| Before                                      | After                                       |
| ------------------------------------------- | ------------------------------------------- |
| `RealtimeClient.conn`                       | `RealtimeClient.connection`                 |
| `RealtimeClient.connState`                  | `RealtimeClient.connectionState`            |
| `RealtimeClient.onConnMessage`              | `RealtimeClient.onConnectionMessage`        |
| `RealtimeClient.params`                     | `RealtimeClient.parameters`                 |
| `RealtimeClient.endPoint`                   | `RealtimeClient.endpoint`                   |
| `RealtimeClient.endPointURL`                | `RealtimeClient.endpointUrl`                |
| `RealtimeConstants.wsCloseNormal`           | `RealtimeConstants.webSocketCloseNormal`    |
| `RealtimeProtocolVersion.vsn`               | `RealtimeProtocolVersion.wireVersion`       |
| `RealtimeChannel(topic, socket, params: …)` | `RealtimeChannel(topic, socket, config: …)` |
| `Presence.presenceRef`                      | `Presence.presenceReference`                |

`supabase_auth`:

| Before                                                      | After                                                                          |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `JwtPayload.iss/sub/aud/exp/nbf/iat/jti`                    | `issuer`, `subject`, `audience`, `expiresAt`, `notBefore`, `issuedAt`, `jwtId` |
| `JwtHeader.alg/kid/typ`                                     | `algorithm`, `keyId`, `type`                                                   |
| `JWK.kty/keyOps/alg/kid`                                    | `keyType`, `keyOperations`, `algorithm`, `keyId`                               |
| `User.aud`                                                  | `User.audience`                                                                |
| `CreateOAuthClientParams` / `UpdateOAuthClientParams`       | `…Options`                                                                     |
| `CreateCustomProviderParams` / `UpdateCustomProviderParams` | `…Options`                                                                     |
| `authorizationParams`                                       | `authorizationParameters`                                                      |
| `supportedIdTokenSigningAlgs`                               | `supportedIdTokenSigningAlgorithms`                                            |
| `tokenEndpointAuthMethod`                                   | `tokenEndpointAuthenticationMethod`                                            |
| `userinfoEndpoint` / `userinfoUrl`                          | `userInfoEndpoint` / `userInfoUrl`                                             |
| `validateExp(int? exp)`                                     | `validateExpiration(int? expiresAt)`                                           |
| `AMRMethod` / `AMREntry`                                    | `AuthenticationMethodReference` / `…Entry`                                     |
| `AuthChangeEvent.jsName`                                    | `AuthChangeEvent.value`                                                        |
| `AuthenticationMethodReference.code`                        | `AuthenticationMethodReference.value`                                          |
| `GenerateLinkType.fromString`                               | `GenerateLinkType.fromValue`                                                   |
| `OAuthClientType.fromString`                                | `OAuthClientType.fromValue`                                                    |
| `OAuthClientRegistrationType.fromString`                    | `OAuthClientRegistrationType.fromValue`                                        |
| `CustomProviderType.fromString`                             | `CustomProviderType.fromValue`                                                 |

`supabase_storage` and `iceberg`:

| Before                                         | After                                       |
| ---------------------------------------------- | ------------------------------------------- |
| `StorageFileApi.info()`                        | `StorageFileApi.getMetadata()`              |
| `VectorBucketEncryption.sseType`               | `serverSideEncryptionType`                  |
| `PartitionSpec` and the Iceberg `spec` cluster | `PartitionSpecification`, `…Specification…` |
| `TableMetadata.refs`                           | `TableMetadata.references`                  |
| `TableField.doc`                               | `TableField.documentation`                  |
| `LoadTableSnapshots.value`                     | `TableSnapshotScope.name`                   |

These renames also change a type:

| Before                                                              | After                                              |
| ------------------------------------------------------------------- | -------------------------------------------------- |
| `RealtimeClient.heartbeatIntervalMs` (`int`)                        | `heartbeatInterval` (`Duration`)                   |
| `RealtimeConstants.defaultHeartbeatIntervalMs` (`int`)              | `defaultHeartbeatInterval` (`Duration`)            |
| `RealtimeClient.reconnectAfterMs` (`int` return)                    | `reconnectAfter` (`Duration` return)               |
| `SnapshotReference.maxReferenceAgeMs` / `maxSnapshotAgeMs` (`int?`) | `maxReferenceAge` / `maxSnapshotAge` (`Duration?`) |
| `Snapshot.timestampMs` / `TableMetadata.lastUpdatedMs` (`int`)      | `timestamp` / `lastUpdated` (`DateTime`, UTC)      |

### Every deprecated API is gone

| Removed                                                    | Replacement                                  | Package             |
| ---------------------------------------------------------- | -------------------------------------------- | ------------------- |
| `AuthChangeEvent.userDeleted`                              | none, it was never emitted                   | `supabase_auth`     |
| `OAuthProvider.snakeCase`                                  | `OAuthProvider.name`                         | `supabase_auth`     |
| `User.confirmedAt`                                         | `User.emailConfirmedAt`                      | `supabase_auth`     |
| `ReturningOption`                                          | none, it was unused                          | `postgrest`         |
| `PostgrestClient.auth()`                                   | none, pass an `Authorization` header instead | `postgrest`         |
| `RealtimeClient.longpollerTimeout`                         | none, there is no longpoll transport         | `supabase_realtime` |
| `ChannelResponse.rateLimited`                              | none, it was never returned                  | `supabase_realtime` |
| `FileObject.lastAccessedAt`, `FileObjectV2.lastAccessedAt` | none, the server does not populate it        | `supabase_storage`  |
| `AuthUser`                                                 | `User`                                       | `supabase`          |
| `RealtimeClientOptions.eventsPerSecond`                    | none, it was already ignored                 | `supabase`          |
| `RemoveSubscriptionResult`                                 | none                                         | `supabase`          |
| `SupabaseRealtimeError`                                    | none                                         | `supabase`          |
| `SupabaseEventTypes` and `SupabaseEventTypesName`          | none, it was unused                          | `supabase`          |
| `SupabaseStreamBuilder.execute()`                          | listen to the builder directly               | `supabase`          |

Both `lastAccessedAt` fields were also required constructor parameters, so any code that builds a
`FileObject` or `FileObjectV2` by hand drops that argument.

`User.confirmedAt` is no longer parsed from or written to JSON, so `toJson()` output no longer
contains a `confirmed_at` key:

```dart
// Before
final confirmed = user.confirmedAt != null;

// After
final confirmed = user.emailConfirmedAt != null;
```

`SupabaseStreamBuilder` is itself a `Stream`, so drop the `execute()` call:

```dart
// Before
supabase.from('users').stream(primaryKey: ['id']).execute().listen(handle);

// After
supabase.from('users').stream(primaryKey: ['id']).listen(handle);
```
