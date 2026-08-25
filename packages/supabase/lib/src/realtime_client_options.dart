import 'package:supabase_realtime/supabase_realtime.dart';

/// {@template realtime_client_options}
/// Options to pass to the RealtimeClient.
/// {@endtemplate}
class RealtimeClientOptions {
  /// {@macro realtime_client_options}
  const RealtimeClientOptions({
    this.logLevel,
    this.timeout,
    this.connectionCloseTimeout,
    this.heartbeatInterval,
    this.reconnectAfter,
    this.transport,
    this.disconnectOnEmptyChannelsAfter,
    this.encode,
    this.decode,
  });

  /// Level of realtime server logs to be logged
  final RealtimeLogLevel? logLevel;

  /// the timeout to trigger push timeouts
  final Duration? timeout;

  /// The timeout to wait for the connection to close before dismissing the
  /// result.
  final Duration? connectionCloseTimeout;

  /// The interval at which to send a heartbeat message.
  final Duration? heartbeatInterval;

  /// Returns the reconnect interval per attempt.
  ///
  /// Defaults to the stepped backoff of the RealtimeClient.
  final TimerCalculation? reconnectAfter;

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

  /// Serializes outgoing messages, for example on a background isolate so
  /// that a large payload does not block the event loop.
  ///
  /// Defaults to the built-in synchronous codec.
  ///
  /// ```dart
  /// final isolate = YAJsonIsolate();
  ///
  /// RealtimeClientOptions(
  ///   encode: (message) => isolate.encode(message.toJson()),
  ///   decode: (frame) async =>
  ///       RealtimeMessage.fromJson(await isolate.decode(frame as String)),
  /// );
  /// ```
  final RealtimeEncode? encode;

  /// Deserializes incoming frames, for example on a background isolate.
  ///
  /// Defaults to the built-in synchronous codec. See [encode] for an example.
  final RealtimeDecode? decode;
}
