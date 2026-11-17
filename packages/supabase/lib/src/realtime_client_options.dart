import 'package:supabase_realtime/supabase_realtime.dart';

/// Options to pass to the RealtimeClient.
class RealtimeClientOptions {
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
    this.networkReachability,
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

  /// Returns the socket reconnect delay per attempt, starting at attempt 1.
  ///
  /// Defaults to a random delay between zero and
  /// `min(30 s, 1 s × 2^(attempt − 1))`.
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

  /// Reports from a platform network monitor whether the device can reach
  /// the network, starting with the current state.
  ///
  /// While the socket waits out a reconnect backoff, a `true` report cuts the
  /// wait short and reconnects, no sooner than 2 seconds after the previous
  /// attempt started. The first report and `false` reports are ignored, and
  /// the socket never waits for a report before connecting.
  ///
  /// The stream is listened to once, when the client is created, so it must
  /// be a broadcast stream when anything else listens to it as well.
  final Stream<bool>? networkReachability;

  /// Returns a copy with the given fields replaced.
  RealtimeClientOptions copyWith({
    RealtimeLogLevel? logLevel,
    Duration? timeout,
    Duration? connectionCloseTimeout,
    Duration? heartbeatInterval,
    TimerCalculation? reconnectAfter,
    WebSocketTransport? transport,
    Duration? disconnectOnEmptyChannelsAfter,
    RealtimeEncode? encode,
    RealtimeDecode? decode,
    Stream<bool>? networkReachability,
  }) {
    return RealtimeClientOptions(
      logLevel: logLevel ?? this.logLevel,
      timeout: timeout ?? this.timeout,
      connectionCloseTimeout:
          connectionCloseTimeout ?? this.connectionCloseTimeout,
      heartbeatInterval: heartbeatInterval ?? this.heartbeatInterval,
      reconnectAfter: reconnectAfter ?? this.reconnectAfter,
      transport: transport ?? this.transport,
      disconnectOnEmptyChannelsAfter:
          disconnectOnEmptyChannelsAfter ?? this.disconnectOnEmptyChannelsAfter,
      encode: encode ?? this.encode,
      decode: decode ?? this.decode,
      networkReachability: networkReachability ?? this.networkReachability,
    );
  }
}
