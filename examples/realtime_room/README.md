# Realtime: Postgres Changes, Broadcast and Presence

A live chat room that shows all three of Supabase Realtime's features working
together on a single channel:

- **Postgres Changes** stream inserts and deletes on the `messages` table, so the
  chat log stays in sync across every open window without re-fetching
  (`onPostgresChanges`).
- **Broadcast** relays ephemeral "typing" pings that are never written to the
  database, only forwarded to the other clients (`sendBroadcastMessage`,
  `onBroadcast`).
- **Presence** tracks who is currently in the room and surfaces the live roster
  (`track`, `onPresenceSync`, `presenceState`).

The realtime subscription lives in
[`lib/room_channel.dart`](lib/room_channel.dart), which wraps a single
`supabase.channel(...)` and exposes the three features as plain Dart streams. The
database reads and writes live in
[`lib/room_repository.dart`](lib/room_repository.dart). Both are kept separate
from the UI so they are easy to read and to drive from an integration test.

To keep the focus on the Supabase calls, the UI uses plain `setState`. A larger
app would typically reach for a state management solution (for example Riverpod,
Bloc or Provider) instead.

The `messages` table, its realtime publication and the sample data come from the
shared Supabase config in [`../supabase`](../supabase): schema in
`migrations/20240602000000_realtime_room_example.sql`, seed rows in `seed.sql`.
Realtime itself is part of the always-on local stack, so no `config.toml` change
is needed.

## Running

From the `examples` directory, run the launcher and pick `realtime_room`:

```bash
./run.sh
```

Open the printed URL in a second browser window (or run it again on another
device) with a different display name to watch messages, typing indicators and
the online roster update live between them.

Or run it directly against any project:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## Integration test

[`integration_test/room_test.dart`](integration_test/room_test.dart) is an
end-to-end test that drives the app widgets against the local stack: it joins the
room, posts a message through the composer and asserts it appears (Postgres
Changes), checks the roster (Presence) and the typing indicator (Broadcast) using
a second client as another user, then deletes a message through the UI.

With the local stack running, pass the same defines the app uses and run it on a
device (integration tests need one, so `-d macos`, an emulator or a real device):

```bash
flutter test integration_test/room_test.dart -d macos \
  --dart-define=SUPABASE_URL=http://localhost:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_LOCAL_PUBLISHABLE_KEY
```
