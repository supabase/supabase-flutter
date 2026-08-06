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

