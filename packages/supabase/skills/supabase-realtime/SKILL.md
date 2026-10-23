---
name: supabase-realtime
description: >-
  Builds realtime features with supabase v3: live lists of table rows with
  typed stream(), reacting to inserts, updates and deletes with
  onTableChanges, broadcast messages between clients, presence, and channel
  status and cleanup. Use when the user wants live updates, a chat, cursors,
  an online indicator or notifications of database changes.
---

# Realtime with supabase

## Choose the API

| Need                                                    | Use                                              |
| ------------------------------------------------------- | ------------------------------------------------ |
| The current rows of a table, kept up to date            | `table(X.table).stream(primaryKey: [...])`       |
| Only some columns of those rows                         | `table(X.table).streamOnly(...)`                 |
| Every insert, update or delete as an event              | `channel.onTableChanges(X.table)`                |
| Messages between clients that are not stored in a table | `channel.onBroadcast` and `sendBroadcastMessage` |
| Who is online                                           | `channel.track` and `onPresenceSync`             |

## Rules

- Every listener is a `Stream`. There are no `callback:` parameters.
- Create every `onTableChanges`, `onBroadcast` and presence stream before
  `channel.subscribe()`. A postgres changes listener added after it throws a
  `StateError`.
- Cancel the subscriptions and call `supabase.removeChannel(channel)` when the
  feature is closed. A forgotten channel keeps receiving messages.
- Use the typed table definitions from the generated schema, not table names
  as strings.
- Database changes only arrive for tables in the `supabase_realtime`
  publication, and only for rows the user may select under row level security.

## A live list of rows

`stream()` fetches the matching rows, then applies every change, and emits
the whole list each time:

```dart
final Stream<List<BooksRow>> books = supabase
    .table(Books.table)
    .stream(primaryKey: [Books.id])
    .filter(Books.authorId.eq(2))
    .order(Books.createdAt.desc())
    .limit(50);
```

`filter()` takes one operator: `eq`, `neq`, `lt`, `lte`, `gt`, `gte`,
`inFilter`, `like`, `ilike`, `matchRegex`, `imatchRegex`, `isNull`,
`isTrue`, `isFalse` or `isDistinct`, optionally negated with `not()`. A filter
composed with `&` or `|` throws an `ArgumentError`.

`order()` takes the same orderings as a query, `Books.title` or
`Books.createdAt.desc()`. A stream keeps `NULL`s last ascending and first
descending, so `.nullsFirst()`, `.nullsLast()`, or an ordering by anything but
a stored column, such as a computed field, throws an `ArgumentError`.

To receive only some columns:

```dart
final titles = supabase
    .table(Books.table)
    .streamOnly(primaryKey: [Books.id], columns: [Books.title])
    .map((rows) => [for (final row in rows) row.read(Books.title)]);
```

## Reacting to changes

```dart
final channel = supabase.channel('books-by-author-2');
final subscription = channel
    .onTableChanges(
      Books.table,
      event: PostgresChangeEvent.insert,
      filters: [Books.authorId.eq(2)],
    )
    .listen((change) {
      if (change case TypedPostgresInsert(:final newRow)) {
        print('New book: ${newRow.title}');
      }
    });
channel.subscribe();
```

Without `event`, the stream carries `TypedPostgresInsert`,
`TypedPostgresUpdate` and `TypedPostgresDelete`, so switch over all three.
The old row of an update or delete only carries the primary key, unless the
table has `replica identity full`. `onTableChangesOnly(…, columns: [...])`
asks the server for fewer columns.

## Broadcast

```dart
final channel = supabase.channel('room-1');
channel
    .onBroadcast(event: 'cursor')
    .listen((message) => print('Cursor at ${message['payload']['x']}'));
channel.subscribe();

await channel.sendBroadcastMessage(event: 'cursor', payload: {'x': 30});
```

Every `onBroadcast` message is a map with `type`, `event` and the sent data
under `payload`, whether it came from `sendBroadcastMessage`, `httpSend`,
the database or another Supabase client. Pass binary data such as a
`Uint8List` as the `payload` itself to send it as a binary frame.

Pass `RealtimeChannelConfig(self: true)` as `options` to `supabase.channel`
to receive your own broadcasts, and `private: true` for a channel guarded by
realtime authorization policies.

## Presence

```dart
final channel = supabase.channel('room-1');
channel.onPresenceSync.listen((_) {
  print('Online: ${channel.presenceState().length}');
});
channel.onStatusChange.listen((change) async {
  if (change.status == RealtimeSubscribeStatus.subscribed) {
    await channel.track({'user_id': 'user-1'});
  }
});
channel.subscribe();
```

Track only after the channel is subscribed, as above. `untrack()` removes the
current client's state.

## Status, errors and cleanup

`onStatusChange` reports the subscription status. A failure, such as a join
the server declined, is a `channelError` status that carries the
`RealtimeException` as `change.error`, not an error of the stream:

```dart
final channel = supabase.channel('room-1');
channel.onStatusChange.listen((change) {
  switch (change.status) {
    case RealtimeSubscribeStatus.channelError:
      print('Channel failed: ${change.error}');
    case RealtimeSubscribeStatus.timedOut:
      print('Channel timed out');
    case _:
      print('Channel is ${change.status.name}');
  }
});
channel.subscribe();

await supabase.removeChannel(channel);
```

`supabase.removeAllChannels()` closes every channel, for example on sign out.
A typed `stream()` reports its failures, including a `RealtimeException`, as
errors of the stream itself.
