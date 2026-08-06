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
