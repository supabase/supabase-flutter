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
