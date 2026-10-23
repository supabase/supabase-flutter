import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'supabase_schema.g.dart';

/// A single realtime channel for the room, wrapping the three realtime features
/// this example demonstrates:
///
/// * **Postgres Changes** stream inserts and deletes on the `messages` table,
///   so the chat log stays in sync while the channel is joined.
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
    // Postgres Changes: inserts and deletes on the `messages` table, decoded
    // into the generated row type.
    onMessageChanges = _channel.onTableChanges(Messages.table);

    // Broadcast: transient "typing" pings. Our own pings are filtered out.
    onTyping = _channel
        .onBroadcast(event: _typingEvent)
        .expand((message) => [?_typingUsername(message)])
        .where((name) => name != username);

    // Presence: fires whenever the roster changes. Read the full state back
    // and map it to the connected users.
    onlineUsers = _channel.onPresenceSync.map((_) => _currentUsers());

    onReplicationReady = _channel.onSystemEvents.where(
      (system) => system.extension == 'system' && system.status == 'ok',
    );
  }

  final SupabaseClient _client;
  final RealtimeChannel _channel;

  /// Name shared with the other clients through broadcast and presence.
  final String username;

  /// The channel topic. Every client that joins the same room name shares its
  /// messages, typing pings and presence.
  final String roomName;

  /// A message someone added to or removed from the room (from Postgres
  /// Changes). Switch over the sealed [TypedPostgresChange] to tell an insert,
  /// carrying the new row, from a delete, carrying the old row.
  late final Stream<TypedPostgresChange<MessagesRow, MessagesRow>>
  onMessageChanges;

  /// The username of another client that is currently typing (from a broadcast
  /// event).
  late final Stream<String> onTyping;

  /// The current room roster (recomputed on every presence sync event).
  late final Stream<List<OnlineUser>> onlineUsers;

  /// Fires each time Postgres Changes replication is live: once after
  /// [subscribe], and again after every rejoin, for example when the app
  /// comes back from the background or the network returns. Changes made
  /// while the channel was away are not streamed afterwards, so this is the
  /// moment to load the table.
  late final Stream<void> onReplicationReady;

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
      } else if (change.status == RealtimeSubscribeStatus.closed &&
          !ready.isCompleted) {
        ready.completeError(
          StateError('channel closed before the subscription completed'),
        );
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

  /// Reads the sender from a typing ping. Clients still on supabase_flutter v2
  /// send the data next to `type` and `event` instead of under `payload`, and
  /// a ping without a username is skipped instead of failing the stream.
  static String? _typingUsername(Map<String, dynamic> message) {
    return switch (message) {
      {'payload': {'username': final String name}} => name,
      {'username': final String name} => name,
      _ => null,
    };
  }

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
