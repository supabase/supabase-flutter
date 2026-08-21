import 'package:supabase_realtime/supabase_realtime.dart';

/// {@template realtime_client_options}
/// Options to pass to the RealtimeClient.
/// {@endtemplate}
class RealtimeClientOptions {
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

  /// Serializes outgoing messages into the frames written to the socket.
  ///
  /// The JSON of a frame already goes through the `jsonCodec` of
  /// `SupabaseClient`, which keeps a large payload off the calling isolate, so
  /// this is only needed to put something other than the Realtime wire format
  /// on the socket, for example a different serialization format altogether.
  ///
  /// ```dart
  /// RealtimeClientOptions(
  ///   encode: (message) async => myFormat.serialize(message.toJson()),
  ///   decode: (frame) async =>
  ///       RealtimeMessage.fromJson(myFormat.deserialize(frame)),
  /// );
  /// ```
  ///
  /// Takes precedence over the codec, so a message passed here is not handed
  /// to it.
  final RealtimeEncode? encode;

  /// Deserializes incoming frames into messages.
  ///
  /// See [encode], which describes when to reach for this and what it takes
  /// precedence over.
  final RealtimeDecode? decode;

  /// {@macro realtime_client_options}
  const RealtimeClientOptions({
    this.logLevel,
    this.timeout,
    this.connectionCloseTimeout,
    this.transport,
    this.disconnectOnEmptyChannelsAfter,
    this.encode,
    this.decode,
  });
}
