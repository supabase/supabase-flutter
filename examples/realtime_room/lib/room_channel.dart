import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// A single realtime channel for the room, wrapping the three realtime features
/// this example demonstrates:
///
/// * **Postgres Changes** stream inserts and deletes on the `messages` table,
///   so the chat log stays in sync without re-fetching.
/// * **Broadcast** relays ephemeral "typing" pings that are never written to
///   the database, only forwarded to the other connected clients.
/// * **Presence** tracks who is currently in the room and exposes the live
///   roster.
///
/// The channel is created but not connected in the constructor; call
/// [subscribe] to join and [dispose] to leave, which also closes the streams.
class RoomChannel {
  RoomChannel({
    required SupabaseClient client,
    required this.username,
    this.roomName = 'public-room',
  }) : _client = client,
       _channel = client.channel(
         roomName,
         // `self: true` echoes our own broadcast and presence events back to
         // us, so this client also shows up in its own roster.
         //
         // `replicationReady: true` asks the server to emit a system event once
         // the replication backing Postgres Changes is live. Without it, a row
         // inserted right after joining can be missed, because replication is
         // set up asynchronously after the join is confirmed.
         options: const RealtimeChannelConfig(
           self: true,
           replicationReady: true,
         ),
       ) {
    // Postgres Changes: new rows in the `messages` table.
    onMessageInserted = _channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
        )
        .map((payload) => Message.fromJson(payload.newRecord));

    // Postgres Changes: deleted rows. The delete payload carries the removed
    // row under `oldRecord`.
    onMessageDeleted = _channel
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
        )
        .map((payload) => payload.oldRecord['id'] as String);

    // Broadcast: transient "typing" pings. Our own pings are filtered out.
    onTyping = _channel
        .onBroadcast(event: _typingEvent)
        .map((payload) => payload['username'] as String)
        .where((name) => name != username);

    // Presence: fires whenever the roster changes. Read the full state back
    // and map it to the connected users.
    onlineUsers = _channel.onPresenceSync.map((_) => _currentUsers());
  }

  final SupabaseClient _client;
  final RealtimeChannel _channel;

  /// Name shared with the other clients through broadcast and presence.
  final String username;

  /// The channel topic. Every client that joins the same room name shares its
  /// messages, typing pings and presence.
  final String roomName;

  /// A message someone added to the room (from a Postgres Changes insert
  /// event).
  late final Stream<Message> onMessageInserted;

  /// The id of a message someone removed (from a Postgres Changes delete
  /// event).
  late final Stream<String> onMessageDeleted;

  /// The username of another client that is currently typing (from a broadcast
  /// event).
  late final Stream<String> onTyping;

  /// The current room roster (recomputed on every presence sync event).
  late final Stream<List<OnlineUser>> onlineUsers;

  static const _typingEvent = 'typing';

  /// Joins the channel. Completes once the server confirms both the
  /// subscription and that Postgres Changes replication is live, so a message
  /// sent right afterwards is guaranteed to stream back.
  Future<void> subscribe() {
    final ready = Completer<void>();

    // The replication-ready signal requested with `replicationReady: true`.
    // It arrives after the join, once Postgres Changes is actually streaming,
    // so this is what completes [subscribe].
    _channel.onSystemEvents.listen((system) {
      if (system.extension != 'system' || ready.isCompleted) return;
      if (system.status == 'ok') {
        ready.complete();
      } else {
        ready.completeError(Exception(system.message));
      }
    });

    _channel.onStatusChange.listen((change) {
      if (change.status == RealtimeSubscribeStatus.subscribed) {
        // Announce ourselves to the room now that we're connected. The
        // payload is arbitrary JSON the other clients read back as presence.
        unawaited(
          _channel.track({
            'username': username,
            'online_at': DateTime.now().toIso8601String(),
          }),
        );
      } else if (change.error != null && !ready.isCompleted) {
        ready.completeError(change.error!);
      }
    });

    _channel.subscribe();

    return ready.future;
  }

  /// Broadcasts a "typing" ping to the other clients. This never touches the
  /// database, which is what makes broadcast the right fit for high-frequency,
  /// throwaway signals.
  Future<void> sendTyping() => _channel.sendBroadcastMessage(
    event: _typingEvent,
    payload: {'username': username},
  );

  /// Flattens the presence state into one [OnlineUser] per connected client.
  List<OnlineUser> _currentUsers() {
    return _channel
        .presenceState()
        .expand((state) => state.presences)
        .map((presence) => OnlineUser.fromPresence(presence.payload))
        .toList();
  }

  /// Leaves the room (which also untracks our presence). Closing the channel
  /// also closes all of its streams.
  Future<void> dispose() async {
    await _client.removeChannel(_channel);
  }
}
