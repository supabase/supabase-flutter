# Migration Guides

This document describes the breaking changes you need to be aware of when upgrading between major
versions of the Supabase Flutter SDK, together with the steps required to migrate your code.

All packages in this repository are released together for a major version, so a single section
covers `supabase_flutter`, `supabase`, `gotrue`, `postgrest`, `realtime_client`, `storage_client`
and `functions_client`. Every symbol mentioned here is re-exported from `supabase_flutter`, so the
snippets apply whether you depend on the individual package or on the Flutter one.

## Migrating from v2 to v3

> [!NOTE]
> v3 has not been released yet. This section is updated as breaking changes land on `main`, so
> treat it as the running list rather than the final one.

### `RealtimeClient.connectionState` is now typed

`RealtimeClient` used to expose the socket state twice: a typed `connState` field and a stringly
typed `connectionState` getter derived from it. The getter is gone and the typed field has taken
its name, so there is now one way to read the socket state.

This one does not produce a compile error if you were only reading the string, so it is worth
checking every use site: the name stayed the same and the type changed from `String` to
`SocketState?`.

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

If you need the string form, use `connectionState?.name`. For the common case of checking whether
the socket is up, `RealtimeClient.isConnected` is unchanged and is the better choice.

If you were using the typed field under its old name, rename it:

```dart
// Before
final SocketStates? state = client.connState;

// After
final SocketState? state = client.connectionState;
```

### `conn` abbreviations on `RealtimeClient` spelled out

The `conn` shortening on `RealtimeClient` is spelled out. The behaviour is unchanged, only the
names are different.

| Before | After |
| --- | --- |
| `RealtimeClient.conn` | `RealtimeClient.connection` |
| `RealtimeClient.connState` | `RealtimeClient.connectionState` |
| `RealtimeClient.onConnMessage` | `RealtimeClient.onConnectionMessage` |

```dart
// Before
final WebSocketChannel? socket = client.conn;
client.onConnMessage(rawMessage);

// After
final WebSocketChannel? socket = client.connection;
client.onConnectionMessage(rawMessage);
```

### Broadcasts no longer fall back to the REST API

`sendBroadcastMessage()` used to silently post to the REST broadcast endpoint whenever the channel
could not push over the WebSocket, logging a warning that the fallback would go away. It has gone
away: the message is only ever sent over the WebSocket, and calling it on a channel that was never
subscribed throws instead.

The fallback made delivery depend on socket timing, so the same call could take two different
transports with two different sets of failure modes. `httpSend()` is the explicit REST path, and it
works without subscribing at all.

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

Messages sent between `subscribe()` and the channel actually joining are still buffered and
flushed once the join succeeds, so only channels that were never subscribed throw.

`httpSend()` requires a Realtime server running v2.97.0 or newer.

### Realtime listener callbacks are now streams

Every recurring-event listener in `realtime_client` is now a Dart `Stream` instead of a callback,
following the shape `RealtimeClient.onHeartbeat` already had. Streams compose (`map`, `where`,
`firstWhere`, `timeout`), support multiple listeners, and removing a listener is a
`StreamSubscription.cancel()`, which the callback API had no public equivalent for.

On `RealtimeClient`, the connection listeners are broadcast stream getters instead of
callback-registration methods:

```dart
// Before
client.onOpen(() => print('open'));
client.onClose((event) => print('closed: $event'));
client.onError((error) => print('error: $error'));
client.onMessage((message) => print('message: $message'));

// After
client.onOpen.listen((_) => print('open'));
client.onClose.listen((event) => print('closed: $event'));
client.onError.listen((error) => print('error: $error'));
client.onMessage.listen((message) => print('message: $message'));
```

On `RealtimeChannel`, `onPostgresChanges` and `onBroadcast` no longer take a `callback` parameter
and return a typed stream instead of the channel, so they can no longer be chained. Repeated calls
with the same arguments return the same stream. For `postgres_changes` the stream still has to be
created before `subscribe()`, because the requested changes are part of the join payload, but it
can be listened to at any point:

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
`RealtimeSubscribeStatus` and, for `channelError`, the error that caused it. The optional timeout
moved up to be the first positional parameter:

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

All channel streams complete when the channel closes, so `await for` loops and `onDone` handlers
end on their own once the channel is gone.

### Plural enum names singularized

A Dart enum type names one value rather than the set, so its name should be singular. Five enums
were ports of the `realtime-js` and `gotrue-js` names instead, and one more turned up in storage.
Three of them were never reachable from outside the package and are now marked `@internal`; the
ones below are the renames you can actually hit.

| Before | After | Package |
| --- | --- | --- |
| `SocketStates` | `SocketState` | `realtime_client` |
| `PostgresTypes` | `PostgresType` | `realtime_client` |
| `AuthenticatorAssuranceLevels` | `AuthenticatorAssuranceLevel` | `gotrue` |
| `LoadTableSnapshots` | `TableSnapshotScope` | `storage_client` |

No enum values changed, so the only work is renaming the type where you name it explicitly.

```dart
// Before
final AuthenticatorAssuranceLevels? level =
    supabase.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel;

// After
final AuthenticatorAssuranceLevel? level =
    supabase.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel;
```

`LoadTableSnapshots` was additionally renamed to describe what it is rather than where it is used,
since it selects which snapshots a table load returns:

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

### Timestamps are `DateTime` instead of `String` or `int`

Every timestamp the SDK returns is now a `DateTime` in UTC, parsed once when the response is
decoded, instead of a raw ISO 8601 `String` or a Unix timestamp `int`. Comparing, formatting and
doing arithmetic on them no longer requires parsing them yourself.

| Type | Fields | Before | After |
| --- | --- | --- | --- |
| `Session` | `expiresAt` | `int?` (Unix seconds) | `DateTime?` |
| `User` | `createdAt` | `String` | `DateTime` |
| `User` | `confirmationSentAt`, `recoverySentAt`, `emailChangeSentAt`, `invitedAt`, `emailConfirmedAt`, `phoneConfirmedAt`, `lastSignInAt`, `updatedAt` | `String?` | `DateTime?` |
| `UserIdentity` | `createdAt`, `lastSignInAt`, `updatedAt` | `String?` | `DateTime?` |
| `OAuthClient` | `createdAt`, `updatedAt` | `String` | `DateTime` |
| `Bucket` | `createdAt`, `updatedAt` | `String` | `DateTime` |
| `FileObject` | `createdAt`, `updatedAt` | `String?` | `DateTime?` |
| `FileObjectV2` | `createdAt` | `String` | `DateTime` |
| `FileObjectV2` | `updatedAt`, `lastModified` | `String?` | `DateTime?` |
| `PaginatedFile` | `createdAt`, `updatedAt` | `String?` | `DateTime?` |

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

The wire format is unchanged. Of the types above only `Session`, `User` and `UserIdentity` have a
`toJson()`, and those still write ISO 8601 strings for the `User` and `UserIdentity` timestamps and
Unix seconds for `Session.expires_at`, so sessions persisted by v2 are still readable by v3. The
storage types have no `toJson()`, in v2 or v3.

Three behavioural details are worth checking:

- The `DateTime` values are in UTC. `DateTime` equality takes the time zone flag into account, so
  compare against `DateTime.utc(...)` rather than `DateTime(...)`, or call `toLocal()` first.
- A timestamp the server is documented to always send is now parsed strictly. `User.createdAt`
  used to fall back to an empty string when the field was missing and now throws a
  `FormatException`, which surfaces a malformed payload instead of passing an unusable value on.
- A timestamp naming a date that does not exist is rejected rather than rolled forward.
  `DateTime.parse` reads `2019-02-29` as 1 March 2019; parsing now throws a `FormatException`
  instead.

### `OAuthAuthorizationDetailsResponse.user` is an `OAuthAuthorizingUser`

The OAuth 2.1 server returns only an id and an email for the user a pending authorization request
belongs to, so `OAuthAuthorizationDetailsResponse.user` was a `User` with every other field
defaulted. It is now an `OAuthAuthorizingUser`, which carries exactly the two fields the server
sends, matching what the other Supabase client libraries expose.

```dart
// Before
final User user = details.user;

// After
final OAuthAuthorizingUser user = details.user;
```

`id` and `email` keep their names, so code that only reads those needs no change.

### `order()` now sorts ascending by default

`PostgrestTransformBuilder.order()` and `SupabaseStreamBuilder.order()` defaulted `ascending` to
`false`, so a call that left the parameter out sorted descending. That was the opposite of SQL's
`ORDER BY` and of the other Supabase client libraries. Both now default to `true`.

Like the `connectionState` change above, this one does not produce a compile error. The call still
compiles and still returns the same rows, only in the reverse order, so it is worth checking every
`.order()` call that does not pass `ascending` explicitly, in both `select()` queries and
`stream()`.

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

### `admin.listUsers()` returns pagination metadata

`listUsers()` accepted `page` and `perPage` but returned a bare `List<User>`, so the pagination
metadata the server reports went unused and there was no way to tell how many users or pages exist
short of requesting pages until a short one came back. It now returns a `ListUsersResponse` that
carries the page of users plus that metadata.

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

`total` comes from the `X-Total-Count` response header, `nextPage` and `lastPage` from the `Link`
header, and `audience` from the `aud` field of the body. `nextPage` is `null` on the last page, so
you can walk every page without guessing where it ends:

```dart
var response = await supabase.auth.admin.listUsers(perPage: 50);
while (response.nextPage != null) {
  response = await supabase.auth.admin.listUsers(
    page: response.nextPage,
    perPage: 50,
  );
}
```

### Every deprecated API is gone

v3 drops the whole deprecated surface that accumulated over v1 and v2. Where an entry has a
replacement, that replacement has been available for at least one minor version. The rest were
already inert: unused types, options the client ignored, or values the server never sent.

| Removed | Replacement | Package |
| --- | --- | --- |
| `AuthChangeEvent.userDeleted` | none, it was never emitted | `gotrue` |
| `OAuthProvider.snakeCase` | `OAuthProvider.name` | `gotrue` |
| `User.confirmedAt` | `User.emailConfirmedAt` | `gotrue` |
| `ReturningOption` | none, it was unused | `postgrest` |
| `PostgrestClient.auth()` | `PostgrestClient.setAuth()` | `postgrest` |
| `RealtimeClient.longpollerTimeout` | none, there is no longpoll transport | `realtime_client` |
| `ChannelResponse.rateLimited` | none, it was never returned | `realtime_client` |
| `FileObject.lastAccessedAt`, `FileObjectV2.lastAccessedAt` | none, the server does not populate it | `storage_client` |
| `AuthUser` | `User` | `supabase` |
| `RealtimeClientOptions.eventsPerSecond` | none, it was already ignored | `supabase` |
| `RemoveSubscriptionResult` | none | `supabase` |
| `SupabaseRealtimeError` | none | `supabase` |
| `SupabaseEventTypes` and `SupabaseEventTypesName` | none, it was unused | `supabase` |
| `SupabaseStreamBuilder.execute()` | listen to the builder directly | `supabase` |

Both `lastAccessedAt` fields were also required constructor parameters, so any code that builds a
`FileObject` or `FileObjectV2` by hand drops that argument.

Two of these need more than a rename.

`User.confirmedAt` mirrored `emailConfirmedAt` and is no longer parsed from or written to JSON, so
`toJson()` output no longer contains a `confirmed_at` key:

```dart
// Before
final confirmed = user.confirmedAt != null;

// After
final confirmed = user.emailConfirmedAt != null;
```

`SupabaseStreamBuilder` has been a `Stream` since 1.0.0, so `execute()` only returned the builder's
own stream:

```dart
// Before
supabase.from('users').stream(primaryKey: ['id']).execute().listen(handle);

// After
supabase.from('users').stream(primaryKey: ['id']).listen(handle);
```

### `publishableKey` is required on `Supabase.initialize`

The deprecated `anonKey` parameter is removed and `publishableKey` is now required. A legacy anon
key is still a valid value, it just goes under the new name.

```dart
// Before
await Supabase.initialize(url: url, anonKey: anonKey);

// After
await Supabase.initialize(url: url, publishableKey: anonKey);
```

### `createSignedUrls` reports per-path failures

The old `createSignedUrls` returned `List<SignedUrl>` and silently dropped paths the server could
not sign, so there was no way to tell a missing file from a successful one. It is removed, and
`createSignedUrlsResult` takes over the name. Each entry in the returned list is either a
`SignedUrlSuccess` or a `SignedUrlFailure`.

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

If you were already on `createSignedUrlsResult`, drop the `Result` suffix from the call.

### Confirming an email or phone change emits `userUpdated`

Confirming an email or phone change used to emit `AuthChangeEvent.signedIn`, which made it
indistinguishable from an actual sign-in. It now emits `AuthChangeEvent.userUpdated`, the same event
that `updateUser()` emits when the change is requested. This applies to every way the change can be
confirmed:

| Confirmation | Before | After |
| --- | --- | --- |
| `verifyOTP()` with `OtpType.emailChange` or `OtpType.phoneChange` | `signedIn` | `userUpdated` |
| `getSessionFromUrl()` with an implicit `type=email_change` link | `signedIn` | `userUpdated` |
| `exchangeCodeForSession()` for a PKCE code from an email change | `signedIn` | `userUpdated` |

The session is still saved and `currentSession` still updates, only the event differs. Because this
is a runtime change and not a compile error, check any `onAuthStateChange` listener that navigates
or fetches on `signedIn` and expects the email-change confirmation to reach it:

```dart
// Before
supabase.auth.onAuthStateChange.listen((data) {
  if (data.event == AuthChangeEvent.signedIn) {
    // Ran both on sign-in and after an email change was confirmed.
  }
});

// After
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

### `HttpMethod` is one shared enum

`functions_client` and `postgrest` each declared their own `HttpMethod`. There is now one, shaped
like postgrest's and re-exported from both, so imports are unchanged and postgrest callers are
unaffected. For `functions.invoke`, two things changed:

- `head` was added, so an exhaustive `switch` over `HttpMethod` no longer compiles until you handle
  it.
- The values were reordered, so `index` shifted for `post` (1 to 2), `put` (2 to 3) and `delete`
  (3 to 5). This one is not a compile error, so replace any persisted `index` with `name`.

The enum also exposes `value`, the uppercase wire form, in place of `method.name.toUpperCase()`.

### Auth requires a GoTrue server on API version `2024-01-01` or newer

The auth client used to read the `x-supabase-api-version` response header and decide how to parse
errors from it: the `code` field on servers reporting `2024-01-01` or newer, and the older
`error_code` field on anything else. It also reconstructed `AuthWeakPasswordException` by inspecting
a bare `weak_password` body, for servers so old they sent no error code at all.

Both fallbacks are gone. Error codes are now always read from `code`, and `AuthWeakPasswordException`
is only thrown when the server names it. The client still sends
`x-supabase-api-version: 2024-01-01` on every request, but no longer looks at what comes back.

Hosted Supabase projects have been past this version for a long time, so this only affects
self-hosted setups pinned to a GoTrue older than `2024-01-01`. Against one of those, an auth failure
still throws `AuthApiException` with the right message and status code, but `code` is `null` and a
weak password surfaces as a plain `AuthApiException` rather than `AuthWeakPasswordException`. Upgrade
the server to restore both.

The `ApiVersions` class, and its `ApiVersions.v20240101` field, are removed along with it. Nothing
replaces them; they only existed to drive the comparison above.

### The session is persisted with `SharedPreferencesAsync`

`SharedPreferencesLocalStorage` and `SharedPreferencesGotrueAsyncStorage`, the storage
implementations `Supabase.initialize` uses by default, wrote through the legacy
[`SharedPreferences`](https://pub.dev/packages/shared_preferences#sharedpreferences-vs-sharedpreferencesasync-vs-sharedpreferenceswithcache)
API. They now use `SharedPreferencesAsync`. On web the session still goes into
`window.localStorage` under the same key as before, so nothing changes there.

The two APIs do not share a store on every platform, and on the ones where they do the legacy API
prefixes its keys, so a session written by v2 is invisible to the new one. `initialize()` therefore
moves an existing session over to `SharedPreferencesAsync` the first time it runs and deletes the
legacy entry, so your users stay signed in. No code change is needed for this, and there is nothing
to migrate if you already pass your own `LocalStorage`.

What this does mean is that the SDK no longer holds up its end of a mixed setup, and mixing is
worse than it first looks. How the two APIs relate depends on the platform:

| Platform | Relationship between the two APIs |
| --- | --- |
| Windows, Linux | One `shared_preferences.json`, rewritten in full from each API's own cache, so a write through either one can drop what the other wrote |
| Android | Separate stores, `SharedPreferences` against DataStore, so a value written through one is invisible to the other |
| iOS, macOS, web | One store, but the legacy API prefixes its keys with `flutter.`, so a value written through one is invisible to the other |

Only the first row loses data, and it loses it in both directions. That is what made sessions go
missing in v2, and from v3 on the same collision runs the other way: a session write by the SDK can
drop preferences your own code wrote through the legacy API. So if your code still calls
`SharedPreferences.getInstance()`, this is the moment to
[migrate it to `SharedPreferencesAsync`](https://pub.dev/packages/shared_preferences#migrating-from-sharedpreferences-to-sharedpreferencesasync-or-sharedpreferenceswithcache)
as well. The snippet below is the way out if you cannot do that yet.

If you would rather keep the session in the legacy store for now, pass a `LocalStorage` that reads
and writes it. Supplying your own storage is also where the session key comes in: `initialize()`
derives it from your project URL for the default storage, so you only name the key when you
construct a `LocalStorage` yourself, and `defaultPersistSessionKey` hands you the same one.

```dart
class LegacySharedPreferencesLocalStorage extends LocalStorage {
  LegacySharedPreferencesLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;

  late final SharedPreferences _preferences;

  @override
  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  @override
  Future<bool> hasAccessToken() async =>
      _preferences.containsKey(persistSessionKey);

  @override
  Future<String?> accessToken() async =>
      _preferences.getString(persistSessionKey);

  @override
  Future<void> removePersistedSession() =>
      _preferences.remove(persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _preferences.setString(persistSessionKey, persistSessionString);
}

await Supabase.initialize(
  url: url,
  publishableKey: publishableKey,
  authOptions: FlutterAuthClientOptions(
    localStorage: LegacySharedPreferencesLocalStorage(
      persistSessionKey: defaultPersistSessionKey(url),
    ),
  ),
);
```

Widget tests that call `Supabase.initialize` need one more line of setup.
`SharedPreferences.setMockInitialValues()` only stands in for the legacy API, so on its own the new
storage throws `StateError: The SharedPreferencesAsyncPlatform instance must be set.` Register an
in-memory async store next to it:

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
`FlutterAuthClientOptions(localStorage: const EmptyLocalStorage())` instead skips storage in tests
altogether.

### `supabasePersistSessionKey` is gone

The constant existed for the v1 to v2 migration from Hive, which v3 no longer carries, and the SDK
itself never read it. The session is stored under the key you pass to `LocalStorage`, which for the
default storage is `sb-<project-ref>-auth-token`.

The `LocalStorage` examples in the README used the constant as their storage key, so if you copied
one of those, take the key as a parameter instead:

```dart
// Before
class MySecureStorage extends LocalStorage {
  @override
  Future<String?> accessToken() => storage.read(key: supabasePersistSessionKey);
  // ...
}

// After
class MySecureStorage extends LocalStorage {
  MySecureStorage({required this.persistSessionKey});

  final String persistSessionKey;

  @override
  Future<String?> accessToken() => storage.read(key: persistSessionKey);
  // ...
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
```

Passing the key you already store under keeps your users signed in; switching to a different key
signs them out once. To keep the old value, pass `'SUPABASE_PERSIST_SESSION_KEY'`, which is what the
constant held.

The `MigrationLocalStorage` and `HiveLocalStorage` snippets that migrated a v1 session out of
[hive](https://pub.dev/packages/hive) are gone from the README along with it. If you are still on
v1, upgrade to v2 first and let it migrate the session, then move to v3.

### Service exceptions share one base

`AuthException`, `PostgrestException`, `StorageException` and `FunctionException` each reimplemented
the same message plus status shape under different field names and types. They now extend a shared
`SupabaseException`, and the ones reporting a response from a service also mix in
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

So `statusCode` is a non-nullable `int` that exists exactly when a service answered, and a failure
the client raised on its own carries only a message and, where the client can name it, an
`errorCode`. Both types are re-exported from every package, so one catch handles a failure from any
service:

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

| Before | After |
| --- | --- |
| `AuthException.statusCode` (`String?`) | `AuthApiException.statusCode` (`int`) |
| `AuthException.code` | `AuthException.errorCode` |
| `StorageException.statusCode` (`String?`) | `StorageApiException.statusCode` (`int`) |
| `StorageException.error` | `errorCode` |
| `StorageException.fromJson(json, '404')` | `StorageApiException.fromJson(json, 404)` |
| `PostgrestException` | `PostgrestApiException` |
| `PostgrestException.code` | `PostgrestApiException.errorCode`, with the HTTP status in `statusCode` |
| `PostgrestException.fromJson(json, code: 409)` | `PostgrestApiException.fromJson(json, statusCode: 409)` |
| `PostgrestException.toJson()` key `code` | keys `statusCode` and `errorCode` |
| `FunctionsHttpException` | `FunctionsApiException` |
| `FunctionException.status` (`int`) | `FunctionsApiException.statusCode` |
| `FunctionException.reasonPhrase` | folded into `message` |
| `FunctionsFetchException.status == 0` | no status at all, no response reached the client |
| `FunctionResponse.status` | `FunctionResponse.statusCode` |

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

- `PostgrestException.code` no longer doubles as the status. It held the PostgREST or PostgreSQL
  code, except when the error body was not JSON, where it held the HTTP status instead. `errorCode`
  is now only ever the former and `statusCode` only ever the latter, so a duplicate key violation
  reads as `statusCode: 409, errorCode: '23505'`.
- `AuthSessionMissingException` and `AuthInvalidJwtException` report no status. The `400` they used
  to carry was invented by the client, which raises both without making a request. They report
  `errorCode` values of `session_missing` and `invalid_jwt` instead.
- `AuthRetryableFetchException` covers only the transport case now, where the request never reached
  the service. A retryable 5xx the service answered is an `AuthRetryableApiException`, which carries
  the status. Catching `AuthRetryableFetchException` still gets both.
- `FunctionException` gained a message. It had only `status`, `details` and `reasonPhrase`. The
  response's reason phrase becomes the message, falling back to a per-subtype default when the
  response carries none, as over HTTP/2. The response body is still in `details`.

`AuthUnknownException` also no longer reports a status of its own. It derived one from
`originalError`, which it still exposes, so read it from there when that is an `http.Response`.
`RealtimeSubscribeException` is not part of this hierarchy: it reports a channel subscription
outcome rather than a request failure, and carries a `RealtimeSubscribeStatus` instead of a message.

### The Iceberg exceptions join the same hierarchy

`IcebergException` used `0` as the status code when no response was received, so callers
had to know that `statusCode == 0` meant "no response" rather than a real status. The sealed
hierarchy now splits the same way as the other packages:

| | |
| --- | --- |
| `IcebergNetworkException` | no response was received from the catalog, so there is no status code and the outcome of the request is unknown |
| `IcebergApiException` | the catalog answered, so `statusCode` is a real, non-nullable status |

`IcebergApiException` is the sealed base for the response-backed subtypes, which are unchanged:
`IcebergNotFoundException`, `IcebergConflictException`,
`IcebergAuthenticationTimeoutException`, `IcebergCommitStateUnknownException`,
`IcebergServerException` and `IcebergUnknownException`.

| Before | After |
| --- | --- |
| `IcebergException.type` | `errorCode`, from `SupabaseException` |
| `IcebergException.statusCode` | `IcebergApiException.statusCode`; gone from the network case |
| `IcebergException.statusCode == 0` | catch `IcebergNetworkException`, or check `is SupabaseApiException` |
| `IcebergException.fromResponse` | `IcebergApiException.fromResponse` |

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

Exhaustive switches over the sealed hierarchy still compile with the same set of cases, since the
new base is sealed and every concrete subtype is unchanged.
