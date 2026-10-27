import 'package:meta/meta.dart';

/// The connection state of a [RealtimeClient]'s underlying socket.
enum SocketState {
  /// Client attempting to establish a connection
  connecting,

  /// Connection is live and connected
  open,

  /// Socket is closing by the user
  disconnecting,

  /// Socket being close not by the user. Realtime should attempt to reconnect.
  closed,

  /// Socket being closed by the user
  disconnected,
}

/// The state of a [RealtimeChannel], read through [RealtimeChannel.state].
enum ChannelState {
  /// The channel is not joined, either because it was never subscribed or
  /// because it left.
  closed,

  /// The join failed or the connection dropped, and the channel will try to
  /// rejoin.
  errored,

  /// The channel is joined and receiving events.
  joined,

  /// A join request is in flight.
  joining,

  /// A leave request is in flight.
  leaving,
}

@internal
enum ChannelEvent {
  close,
  error,
  join,
  reply,
  leave,
  heartbeat,
  accessToken,
  broadcast,
  presence,
  postgresChanges;

  static ChannelEvent fromValue(String type) {
    for (final event in ChannelEvent.values) {
      if (event.name == type || event.eventName() == type) {
        return event;
      }
    }
    throw ArgumentError.value(type, 'type', 'No such channel event');
  }

  String eventName() => switch (this) {
    ChannelEvent.accessToken => 'access_token',
    ChannelEvent.postgresChanges => 'postgres_changes',
    ChannelEvent.broadcast => 'broadcast',
    ChannelEvent.presence => 'presence',
    ChannelEvent.close ||
    ChannelEvent.error ||
    ChannelEvent.join ||
    ChannelEvent.reply ||
    ChannelEvent.leave ||
    ChannelEvent.heartbeat => 'phx_$name',
  };
}

/// The verbosity of logging the Realtime server does for a connection, sent
/// as the `log_level` connection parameter.
enum RealtimeLogLevel {
  /// Most verbose.
  info,

  /// More verbose than [warn].
  debug,

  /// More verbose than [error].
  warn,

  /// Least verbose.
  error,
}
