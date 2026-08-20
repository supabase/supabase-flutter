# Migration Guides

This document describes the breaking changes you need to be aware of when upgrading between major
versions of the Supabase Flutter SDK, together with the steps required to migrate your code.

All packages in this repository are released together for a major version, so a single section
covers `supabase_flutter`, `supabase`, `supabase_auth`, `postgrest`, `supabase_realtime`,
`supabase_storage`, `iceberg` and `supabase_functions`. Every symbol mentioned here is re-exported from
`supabase_flutter`, so the snippets apply whether you depend on the individual package or on the
Flutter one.

## Migrating from v2 to v3

> [!NOTE]
> v3 has not been released yet. This section is updated as breaking changes land on `main`, so
> treat it as the running list rather than the final one.

### The `gotrue` package is now `supabase_auth`

The service this package talks to has been called Supabase Auth for years, and `gotrue` is a name
users no longer recognize. The package is published as `supabase_auth` from v3 onwards, and the
`gotrue` package is discontinued on pub.dev when v3 ships.

If you depend on `supabase_flutter` or `supabase` you do not need to change your dependencies,
both pull in `supabase_auth` for you and re-export it. You do need to rename the types below.

If you depend on the auth client directly, rename the dependency and the import:

```yaml
# Before
dependencies:
  gotrue: ^2.27.1

# After
dependencies:
  supabase_auth: ^3.0.0
```

```dart
// Before
import 'package:gotrue/gotrue.dart';

// After
import 'package:supabase_auth/supabase_auth.dart';
```

The types that carried the old name in their own name are renamed to the `Auth` prefix the rest of
the package already uses:

| Before | After |
| --- | --- |
| `GoTrueClient` | `AuthClient` |
| `GoTrueAdminApi` | `AuthAdminApi` |
| `GoTrueAdminCustomProvidersApi` | `AuthAdminCustomProvidersApi` |
| `GoTrueAdminMFAApi` | `AuthAdminMFAApi` |
| `GoTrueAdminOAuthApi` | `AuthAdminOAuthApi` |
| `GoTrueAdminPasskeyApi` | `AuthAdminPasskeyApi` |
| `GoTrueMFAApi` | `AuthMFAApi` |
| `GoTrueOAuthApi` | `AuthOAuthApi` |
| `GoTruePasskeyApi` | `AuthPasskeyApi` |
| `GotrueAsyncStorage` | `AuthAsyncStorage` |
| `SharedPreferencesGotrueAsyncStorage` | `SharedPreferencesAuthAsyncStorage` |

```dart
// Before
final GoTrueClient auth = supabase.auth;

// After
final AuthClient auth = supabase.auth;
```

Two extensions `supabase_flutter` adds to the auth client follow the same rename:
`GoTrueClientSignInProvider` becomes `AuthClientSignInProvider` and `GoTrueClientPasskey` becomes
`AuthClientPasskey`. You only name these if you were referring to the extension explicitly, for
example to hide it in an import.

Nothing about the wire format changes. The `X-Client-Info` header still identifies this client as
`gotrue-dart`, and the `gotrue_meta_security` field in captcha payloads is unchanged.

### `AuthClient.getSSOSignInUrl` returns a `Uri`

`getSSOSignInUrl()` now returns a `Future<Uri>` rather than a `Future<String>`.

```dart
// Before
final String ssoUrl = await supabase.auth.getSSOSignInUrl(domain: 'company.com');

// After
final Uri ssoUrl = await supabase.auth.getSSOSignInUrl(domain: 'company.com');
```

If you need the URL string, use `ssoUrl.toString()`.

### `OAuthResponse.url` is a `Uri`

`OAuthResponse.url` is a `Uri` rather than a `String`, so `getOAuthSignInUrl()` and
`getLinkIdentityUrl()` now hand back the same type `getSSOSignInUrl()` does.

```dart
// Before
final response = await supabase.auth.getOAuthSignInUrl(
  provider: OAuthProvider.google,
);
final String url = response.url;

// After
final response = await supabase.auth.getOAuthSignInUrl(
  provider: OAuthProvider.google,
);
final Uri url = response.url;
```

If you need the URL string, use `response.url.toString()`. Callers that were parsing it
themselves can drop the `Uri.parse()`.

The URL the server receives is unchanged, only the Dart type differs.

### The `functions_client` package is now `supabase_functions`

`functions_client` says nothing about Supabase and does not match how the rest of the packages are
named. The package is published as `supabase_functions` from v3 onwards, and the `functions_client`
package is discontinued on pub.dev when v3 ships.

If you depend on `supabase_flutter` or `supabase` you do not need to change anything, both pull in
`supabase_functions` for you and re-export it.

If you depend on the functions client directly, rename the dependency and the import:

```yaml
# Before
dependencies:
  functions_client: ^2.7.1

# After
dependencies:
  supabase_functions: ^3.0.0
```

```dart
// Before
import 'package:functions_client/functions_client.dart';

// After
import 'package:supabase_functions/supabase_functions.dart';
```

No types are renamed, `FunctionsClient` and everything around it keep their names. Nothing about
the wire format changes either: the `X-Client-Info` header still identifies this client as
`functions-dart`.

### The `realtime_client` package is now `supabase_realtime`

`realtime_client` says nothing about Supabase and does not match how the rest of the packages are
named. The package is published as `supabase_realtime` from v3 onwards, and the `realtime_client`
package is discontinued on pub.dev when v3 ships.

If you depend on `supabase_flutter` or `supabase` you do not need to change anything, both pull in
`supabase_realtime` for you and re-export it.

If you depend on the realtime client directly, rename the dependency and the import:

```yaml
# Before
dependencies:
  realtime_client: ^2.13.0

# After
dependencies:
  supabase_realtime: ^3.0.0
```

```dart
// Before
import 'package:realtime_client/realtime_client.dart';

// After
import 'package:supabase_realtime/supabase_realtime.dart';
```

The rename does not touch any type names. `RealtimeClient`, `RealtimeChannel` and the rest keep
their names, and the `X-Client-Info` header still identifies this client as `realtime-dart`.

### The `storage_client` package is now `supabase_storage`

`storage_client` says nothing about Supabase and does not match how the rest of the packages are
named. The package is published as `supabase_storage` from v3 onwards, and the `storage_client`
package is discontinued on pub.dev when v3 ships.

If you depend on `supabase_flutter` or `supabase` you do not need to change anything, both pull in
`supabase_storage` for you and re-export it.

If you depend on the storage client directly, rename the dependency and the import:

```yaml
# Before
dependencies:
  storage_client: ^2.8.0

# After
dependencies:
  supabase_storage: ^3.0.0
```

```dart
// Before
import 'package:storage_client/storage_client.dart';

// After
import 'package:supabase_storage/supabase_storage.dart';
```

The rename does not touch any type names. `SupabaseStorageClient`, `StorageFileApi` and the rest
keep their names, and the `X-Client-Info` header still identifies this client as `storage-dart`.

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

On `RealtimeClient`, the four connection callbacks are replaced by two broadcast streams:
`onStatusChange` for the connection lifecycle and `onMessage` for every decoded frame. Connection
errors are emitted as stream errors on `onStatusChange`, so they arrive through the `onError`
handler of `listen`:

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

Four separate streams for one connection was a different shape than the channel, where all of
open, closed and error already arrive on a single `RealtimeChannel.onStatusChange`. Since a stream
needs `listen` and a cancelled subscription to clean up, one status stream is also less
bookkeeping than three.

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

### `Binding` and `BindingCallback` are internal

`Binding` and `BindingCallback` were the raw registration primitives underneath the channel
listeners, exported by accident: their only consumers, `RealtimeChannel.onEvents` and
`RealtimeChannel.off`, have always been internal. They are no longer exported. Use the typed
channel streams (`onPostgresChanges`, `onBroadcast`, `onPresenceSync`, `onPresenceJoin`,
`onPresenceLeave`, `onSystemEvents`) instead.

### `RealtimePresence` is internal

`RealtimePresence` and its helper types (`PresenceOpts`, `PresenceEvents`, `PresenceChooser`,
`PresenceOnJoinCallback`, `PresenceOnLeaveCallback`) are now `@internal`, along with the
`RealtimeChannel.presence` field. They were presence bookkeeping that leaked into the public API,
and registering a callback through `channel.presence.onJoin(...)` silently disabled the channel's
own presence events, because the channel's forwarders occupied the same single callback slot.

Everything the class offered is available on the channel:

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

`presenceState()` is not a drop-in replacement for `presence.state`: it returns a
`List<SinglePresenceState>` rather than a map, so a presence key is read from
`SinglePresenceState.key` and its payloads from `SinglePresenceState.presences`. When code depended
on the map, rebuild it from the list:

```dart
final byKey = {
  for (final state in channel.presenceState()) state.key: state.presences,
};
```

The `Presence` payload class is unchanged and stays public.

### Plural enum names singularized

A Dart enum type names one value rather than the set, so its name should be singular. Five enums
carried plural names instead, and one more turned up in storage.
Three of them were never reachable from outside the package and are now marked `@internal`; the
ones below are the renames you can actually hit.

| Before | After | Package |
| --- | --- | --- |
| `SocketStates` | `SocketState` | `supabase_realtime` |
| `PostgresTypes` | `PostgresType` | `supabase_realtime` |
| `AuthenticatorAssuranceLevels` | `AuthenticatorAssuranceLevel` | `supabase_auth` |
| `LoadTableSnapshots` | `TableSnapshotScope` | `supabase_storage` |

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
| `AuthChangeEvent.userDeleted` | none, it was never emitted | `supabase_auth` |
| `OAuthProvider.snakeCase` | `OAuthProvider.name` | `supabase_auth` |
| `User.confirmedAt` | `User.emailConfirmedAt` | `supabase_auth` |
| `ReturningOption` | none, it was unused | `postgrest` |
| `PostgrestClient.auth()` | none, pass an `Authorization` header instead | `postgrest` |
| `RealtimeClient.longpollerTimeout` | none, there is no longpoll transport | `supabase_realtime` |
| `ChannelResponse.rateLimited` | none, it was never returned | `supabase_realtime` |
| `FileObject.lastAccessedAt`, `FileObjectV2.lastAccessedAt` | none, the server does not populate it | `supabase_storage` |
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

`supabase_functions` and `postgrest` each declared their own `HttpMethod`. There is now one, shaped
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

`SharedPreferencesLocalStorage` and `SharedPreferencesAuthAsyncStorage`, the storage
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

### `FunctionException` is sealed

`FunctionException` is now a `sealed class`, so a switch over it is exhaustive at compile time and
adding a failure mode in a later version is a compile error rather than a case that silently falls
through:

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

`sealed` implies `abstract`, so a bare `FunctionException` can no longer be constructed, and code
outside `supabase_functions` can no longer extend or implement it. Name one of the three subtypes
instead, which is what the client throws in every case.

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

### The Iceberg catalog moved to its own package

`IcebergRestCatalog`, the exceptions above and the table and namespace types now live in
`iceberg`, mirroring the split between `storage-js` and `iceberg-js`. `supabase_storage`
depends on it and re-exports the whole surface, so importing
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

### Abbreviations in the public API are spelled out

Public identifiers that still used abbreviations are spelled out, continuing the precedent set by
`conn` to `connection` above. The wire format is unchanged throughout: where a JSON key, query
parameter or URL path matched the abbreviation, only the Dart identifier is renamed.

Across every package:

| Before | After |
| --- | --- |
| `RealtimeClient.setAuth()` | `RealtimeClient.setAccessToken()` |
| `queryParams:` | `queryParameters:` |
| `opts:` | `options:` |
| `PresenceOpts` | `PresenceOptions` |
| `appendSearchParams` | `appendSearchParameters` |
| `overrideSearchParams` | `overrideSearchParameters` |
| `toQueryParams` | `toQueryParameters` |

`realtime_client`:

| Before | After |
| --- | --- |
| `RealtimeClient.params` | `RealtimeClient.parameters` |
| `RealtimeClient.endPoint` | `RealtimeClient.endpoint` |
| `RealtimeClient.endPointURL` | `RealtimeClient.endpointUrl` |
| `RealtimeConstants.wsCloseNormal` | `RealtimeConstants.webSocketCloseNormal` |
| `RealtimeProtocolVersion.vsn` | `RealtimeProtocolVersion.wireVersion` |
| `RealtimeChannel(topic, socket, params: …)` | `RealtimeChannel(topic, socket, config: …)` |
| `Presence.presenceRef` | `Presence.presenceReference` |

`supabase_auth`:

| Before | After |
| --- | --- |
| `JwtPayload.iss/sub/aud/exp/nbf/iat/jti` | `issuer`, `subject`, `audience`, `expiresAt`, `notBefore`, `issuedAt`, `jwtId` |
| `JwtHeader.alg/kid/typ` | `algorithm`, `keyId`, `type` |
| `JWK.kty/keyOps/alg/kid` | `keyType`, `keyOperations`, `algorithm`, `keyId` |
| `User.aud` | `User.audience` |
| `CreateOAuthClientParams` / `UpdateOAuthClientParams` | `…Options` |
| `CreateCustomProviderParams` / `UpdateCustomProviderParams` | `…Options` |
| `authorizationParams` | `authorizationParameters` |
| `supportedIdTokenSigningAlgs` | `supportedIdTokenSigningAlgorithms` |
| `tokenEndpointAuthMethod` | `tokenEndpointAuthenticationMethod` |
| `userinfoEndpoint` / `userinfoUrl` | `userInfoEndpoint` / `userInfoUrl` |
| `validateExp(int? exp)` | `validateExpiration(int? expiresAt)` |
| `AMRMethod` / `AMREntry` | `AuthenticationMethodReference` / `…Entry` |
| `AuthChangeEvent.jsName` | `AuthChangeEvent.value` |
| `AuthenticationMethodReference.code` | `AuthenticationMethodReference.value` |
| `GenerateLinkType.fromString` | `GenerateLinkType.fromValue` |
| `OAuthClientType.fromString` | `OAuthClientType.fromValue` |
| `OAuthClientRegistrationType.fromString` | `OAuthClientRegistrationType.fromValue` |
| `CustomProviderType.fromString` | `CustomProviderType.fromValue` |

`storage_client`:

| Before | After |
| --- | --- |
| `StorageFileApi.info()` | `StorageFileApi.getMetadata()` |
| `VectorBucketEncryption.sseType` | `serverSideEncryptionType` |
| `PartitionSpec` and the Iceberg `spec` cluster | `PartitionSpecification`, `…Specification…` |
| `TableMetadata.refs` | `TableMetadata.references` |
| `TableField.doc` | `TableField.documentation` |
| `TableSnapshotScope.value` | `TableSnapshotScope.name` |

These renames also change a type:

| Before | After |
| --- | --- |
| `RealtimeClient.heartbeatIntervalMs` (`int`) | `heartbeatInterval` (`Duration`) |
| `RealtimeConstants.defaultHeartbeatIntervalMs` (`int`) | `defaultHeartbeatInterval` (`Duration`) |
| `RealtimeClient.reconnectAfterMs` (`int` return) | `reconnectAfter` (`Duration` return) |
| `SnapshotReference.maxReferenceAgeMs` / `maxSnapshotAgeMs` (`int?`) | `maxReferenceAge` / `maxSnapshotAge` (`Duration?`) |
| `Snapshot.timestampMs` / `TableMetadata.lastUpdatedMs` (`int`) | `timestamp` / `lastUpdated` (`DateTime`, UTC) |

### Every client takes one `SupabaseRetryOptions`

Retry used to be configured differently in every client: PostgREST took three
separate parameters, storage took an `int`, and the auth token refresh had no
knobs at all. All three take the same `SupabaseRetryOptions` now, which carries
`enabled`, `count`, `initialDelay`, `maxDelay` and `randomizationFactor`. What
counts as a retryable failure stays with each client, since those are not
interchangeable: PostgREST repeats a read that answered with `503` or `520`,
storage repeats an upload that hit a network error, and auth repeats a token
refresh that never reached the service.

| Before | After |
| --- | --- |
| `PostgrestClient(retryEnabled: …, retryCount: …)` | `PostgrestClient(retryOptions: …)` |
| `PostgrestClientOptions(retryEnabled: …, retryCount: …)` | `PostgrestClientOptions(retryOptions: …)` |
| `PostgrestBuilder`, `PostgrestQueryBuilder` and `PostgrestRpcBuilder` constructors, same parameters | `retryOptions: …` |
| `SupabaseStorageClient(retryAttempts: 5)` | `SupabaseStorageClient(retryOptions: SupabaseRetryOptions(count: 5))` |
| `StorageClientOptions(retryAttempts: 5)` | `StorageClientOptions(retryOptions: SupabaseRetryOptions(count: 5))` |
| `upload(…, retryAttempts: 5)` and the same parameter on `uploadBinary`, `uploadToSignedUrl`, `uploadBinaryToSignedUrl`, `update` and `updateBinary` | `retryOptions: SupabaseRetryOptions(count: 5)` |

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

`count` is the number of retries after the first attempt, so `count: 0` sends a
request exactly once. The old storage `retryAttempts` counted the same way, so
the number carries over unchanged.

The auth token refresh is configurable for the first time, through
`AuthClientOptions.retryOptions` and `AuthClient(retryOptions: …)`. The refresh
still stops retrying once the next backoff would fall after the next refresh
tick, so the count only caps how many attempts a short backoff can squeeze into
that window.

The per-request `PostgrestBuilder.retry()` override is unchanged.

### The retry backoff defaults are the same in every client

One curve is used everywhere now: the first retry waits 400 ms, every retry
after that waits twice as long up to 30 seconds, and each delay is randomized
by up to 25% so that many clients do not retry in lockstep. Only how many
retries are made differs, and only where it has to.

| Client | Before | After |
| --- | --- | --- |
| `postgrest` | 3 retries, 1s doubling to 30s, no jitter | 3 retries on the shared curve |
| `supabase_storage` | opt-in, 400ms doubling to 30s, 25% jitter | unchanged, still opt-in with `count: 0` |
| `supabase_auth` | 400ms doubling to 10s, no jitter | shared curve, bounded by the refresh tick as before |

PostgREST reads therefore back off sooner than they did, and with jitter. Pass
your own `SupabaseRetryOptions` to keep the old curve:

```dart
postgrestOptions: const PostgrestClientOptions(
  retryOptions: SupabaseRetryOptions(
    initialDelay: Duration(seconds: 1),
    randomizationFactor: 0,
  ),
),
```

### The retried status codes are no longer configurable

`503 Service Unavailable` and `520 Unknown Error` are the only responses worth
repeating, so the set of retried status codes is fixed. Retrying anything else,
a `500` from a failing query for example, only multiplies the load without a
chance of a different answer.

| Before | After |
| --- | --- |
| `PostgrestClient(retryableStatusCodes: …)` | removed |
| `PostgrestClientOptions(retryableStatusCodes: …)` | removed |
| `PostgrestClient.defaultRetryableStatusCodes` | `PostgrestClient.retryableStatusCodes` |

If you retried a status code outside that set, catch the exception and decide
what to do with it yourself:

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

Despite the name, these three pinned a token rather than kept one in sync. `SupabaseClient` gives
the rest, storage and functions clients an HTTP client that attaches the current session token to
every request, but only when the request does not already carry an `Authorization` header. A token
set through `setAccessToken` did carry one, so it won, and nothing ever cleared it: it kept
overriding the session token across refreshes and sign-outs for the rest of the client's life.

If you never called them, nothing changes. If you did, the replacement depends on what you were
after.

To authenticate as the signed-in user, do nothing. `SupabaseClient` already resolves that token on
every request.

On a client you construct yourself, pass an `accessToken` callback. It is resolved before every
request, so a token that rotates is picked up without you pushing the new value anywhere. This is
the closest replacement for the old setter, and unlike it, it does not go stale:

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

`PostgrestClient` and `SupabaseStorageClient` take the same callback. If the token never changes,
a constructor header is still enough:

```dart
final functions = FunctionsClient(functionsUrl, {
  'apikey': anonKey,
  'Authorization': 'Bearer $jwt',
});
```

Passing both an `Authorization` header and `accessToken` asserts, because the header would win on
every request and the callback would never be used.

To use a different token for a single call, pass it to that call:

```dart
await functions.invoke('hello', headers: {'Authorization': 'Bearer $jwt'});
await postgrest.from('countries').select().setHeader('Authorization', 'Bearer $jwt');
```

To pin a token on a client you got from `SupabaseClient`, set the header yourself. `SupabaseClient`
builds its sub-clients, so there is no `accessToken` callback to pass:

```dart
supabase.storage.setHeader('Authorization', 'Bearer $jwt');
supabase.functions.headers['Authorization'] = 'Bearer $jwt';
```

The rest client is stateless and its header map unmodifiable (see
[the stateless rest client](#the-rest-client-and-its-builders-are-stateless)), so a pinned token is
passed per request there, or client-wide through the `headers` setter of `SupabaseClient`:

```dart
await supabase.from('countries').select().setHeader('Authorization', 'Bearer $jwt');
supabase.headers = {...supabase.headers, 'Authorization': 'Bearer $jwt'};
```

That shadows the session token exactly as the old setter did, so remove the header again once the
pinned token should no longer apply.

Realtime keeps its setter because it holds a live socket and has to push a new token over it rather
than attach one per request.

### The rest client and its builders are stateless

`PostgrestClient` no longer holds any mutable state, and the query builder is no longer awaitable
before a table operation has been chosen.

| Before | After |
| --- | --- |
| `supabase.rest.headers['X-Foo'] = 'bar'` | `supabase.headers = {...supabase.headers, 'X-Foo': 'bar'}` |
| `postgrest.headers['X-Foo'] = 'bar'` | pass the header to the `PostgrestClient` constructor, or use `setHeader()` per request |
| `await supabase.from('countries')` compiled and threw an `ArgumentError` at runtime | does not compile |
| `SupabaseQuerySchema(headers: …)` | removed, the headers of the `rest` client are used |
| `PostgrestQueryBuilder(method: …, abortSignal: …)` and `PostgrestRpcBuilder(abortSignal: …)` | removed, both belong to the executable builder returned by a table operation |
| `PostgrestBuilder.appendSearchParameters()` and `PostgrestBuilder.overrideSearchParameters()` | removed, they were internal URL helpers that leaked into the public API |

`PostgrestClient.headers` is now an unmodifiable map. The client never changes after construction,
which makes it safe to share across requests and removes a class of bugs where one call site's
header mutation leaked into every later request. Set headers where they belong instead: on the
constructor for all requests, or with `setHeader()` on a builder for a single request.

On `SupabaseClient`, `rest` is no longer a mutable singleton for the same reason. Assigning
`supabase.headers` replaces the rest client with one carrying the new headers, so reads through
`supabase.rest.headers` stay correct, but in-place mutation of that map now throws an
`UnsupportedError`. `supabase.rpc()` used to permanently merge the client headers into the rest
client on every call; that mutation is gone along with the state it leaked into.

A query builder that has not chosen a table operation is meaningless as a request, so
`supabase.from('countries')` by itself no longer implements `Future` and cannot be awaited,
converted with `withConverter()`, or given an `abortSignal()`. Call `select()`, `insert()`,
`upsert()`, `update()`, `delete()` or `count()` first; everything after that point is unchanged.
`setHeader()` and `retry()` remain available before the operation, since they configure whichever
request follows:

```dart
// Before: compiled, but threw an ArgumentError at runtime.
await supabase.from('countries');

// After: does not compile. Choose an operation first.
await supabase.from('countries').select();
```

`Supabase.initialize` no longer takes a `debug` flag and never prints anything to the console. All
packages still emit their records through [`package:logging`](https://pub.dev/packages/logging)
under the `supabase` logger hierarchy, but whether, where, and at which level those records are
handled is now entirely up to the application.

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

| Before | After |
| --- | --- |
| `supabase.supabase` | `supabase.dart` |
| `supabase.supabase_flutter` | `supabase.flutter` |

### `RealtimeClient.logger` and `RealtimeClient.log` are gone

The realtime client had a second logging path next to `package:logging`: a `logger` callback
constructor parameter and a public `log` method. Both are removed. Realtime diagnostics are
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
