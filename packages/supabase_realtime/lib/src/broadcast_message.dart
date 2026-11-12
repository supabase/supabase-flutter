import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:supabase_realtime/supabase_realtime.dart';

/// A message sent to a channel with broadcast, emitted by
/// [RealtimeChannel.onBroadcast].
///
/// ```dart
/// channel.onBroadcast(event: 'cursor').listen((message) {
///   if (message.payload case JsonBroadcastPayload(
///     value: {'x': final num x},
///   )) {
///     print('cursor moved to $x');
///   }
/// });
/// ```
class BroadcastMessage {
  /// Creates a [BroadcastMessage].
  const BroadcastMessage({
    required this.event,
    required this.payload,
    this.id,
    this.isReplayed = false,
  });

  /// The event name the sender chose.
  final String event;

  /// The data the sender broadcast.
  final BroadcastPayload payload;

  /// The id the server gave the message, set on messages broadcast from the
  /// database.
  final String? id;

  /// Whether the server replayed this message from its history when the
  /// channel joined, as requested with [RealtimeChannelConfig.replay].
  final bool isReplayed;

  @override
  bool operator ==(Object other) =>
      other is BroadcastMessage &&
      other.event == event &&
      other.payload == payload &&
      other.id == id &&
      other.isReplayed == isReplayed;

  @override
  int get hashCode => Object.hash(event, payload, id, isReplayed);

  @override
  String toString() =>
      'BroadcastMessage(event: $event, payload: $payload, id: $id, '
      'isReplayed: $isReplayed)';
}

/// The data of a [BroadcastMessage], either JSON or raw bytes.
sealed class BroadcastPayload {
  const BroadcastPayload._();

  @override
  String toString() => switch (this) {
    JsonBroadcastPayload(:final value) => 'JsonBroadcastPayload($value)',
    BinaryBroadcastPayload(:final bytes) =>
      'BinaryBroadcastPayload(${bytes.length} bytes)',
  };
}

/// A JSON payload.
///
/// Messages sent with [RealtimeChannel.sendBroadcastMessage] or
/// [RealtimeChannel.httpSend] carry a map, but other clients can broadcast any
/// JSON value.
final class JsonBroadcastPayload extends BroadcastPayload {
  /// Creates a [JsonBroadcastPayload] holding [value].
  const JsonBroadcastPayload(this.value) : super._();

  /// The decoded JSON value.
  final Object? value;

  @override
  bool operator ==(Object other) =>
      other is JsonBroadcastPayload &&
      const DeepCollectionEquality().equals(other.value, value);

  @override
  int get hashCode => const DeepCollectionEquality().hash(value);
}

/// A binary payload, sent with [RealtimeChannel.sendBinaryBroadcastMessage]
/// or [RealtimeChannel.httpSendBinary].
final class BinaryBroadcastPayload extends BroadcastPayload {
  /// Creates a [BinaryBroadcastPayload] holding [bytes].
  const BinaryBroadcastPayload(this.bytes) : super._();

  /// The bytes the sender broadcast.
  final Uint8List bytes;

  @override
  bool operator ==(Object other) =>
      other is BinaryBroadcastPayload &&
      const ListEquality<int>().equals(other.bytes, bytes);

  @override
  int get hashCode => const ListEquality<int>().hash(bytes);
}
