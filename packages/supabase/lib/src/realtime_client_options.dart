import 'package:realtime_client/realtime_client.dart';

/// {@template realtime_client_options}
/// Options to pass to the RealtimeClient.
/// {@endtemplate}
class RealtimeClientOptions {
  /// How many events the RealtimeClient can push in a second
  ///
  /// Defaults to 10 events per second
  @Deprecated(
    'Client side rate limit has been removed. This option will be ignored.',
  )
  final int? eventsPerSecond;

  /// Level of realtime server logs to be logged
  final RealtimeLogLevel? logLevel;

  /// the timeout to trigger push timeouts
  final Duration? timeout;

  /// The timeout to wait for the connection to close before dismissing the
  /// result.
  final Duration? connectionCloseTimeout;

  /// Custom WebSocket transport factory for the RealtimeClient.
  final WebSocketTransport? transport;

  /// The delay before the socket is disconnected once the last channel is
  /// removed.
  ///
  /// If a new channel is created before the delay elapses, the pending
  /// disconnect is cancelled and the open socket is reused. Pass
  /// [Duration.zero] to disconnect immediately. Defaults to twice the
  /// heartbeat interval.
  final Duration? disconnectOnEmptyChannelsAfter;

  /// {@macro realtime_client_options}
  const RealtimeClientOptions({
    this.eventsPerSecond,
    this.logLevel,
    this.timeout,
    this.connectionCloseTimeout,
    this.transport,
    this.disconnectOnEmptyChannelsAfter,
  });
}
