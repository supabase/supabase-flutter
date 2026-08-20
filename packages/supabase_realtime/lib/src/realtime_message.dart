import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:supabase_realtime/src/constants.dart';
import 'package:supabase_realtime/src/types.dart';

/// A message as it travels over the Realtime WebSocket connection.
///
/// This is what a custom `RealtimeEncode` is handed and what a custom
/// `RealtimeDecode` returns. [toJson] and [RealtimeMessage.fromJson] convert
/// between a message and its shape on the wire for a protocol version, so a
/// codec only has to turn that shape into bytes and back:
///
/// ```dart
/// RealtimeClient(
///   url,
///   encode: (message) => isolate.encode(message.toJson()),
///   decode: (frame) async =>
///       RealtimeMessage.fromJson(await isolate.decode(frame as String)),
/// );
/// ```
class RealtimeMessage {
  /// Reference of the channel join this message belongs to.
  ///
  /// `null` for messages that are not tied to a join, such as heartbeats.
  final String? joinRef;

  /// Reference tying a reply to the message that triggered it.
  final String? ref;

  /// Topic the message belongs to, for example `realtime:room`.
  final String topic;

  /// Event name as it appears on the wire, for example `phx_join`.
  final String event;

  /// Body of the message, `null` when the event carries none.
  final Object? payload;

  const RealtimeMessage({
    required this.topic,
    required this.event,
    this.payload,
    this.ref,
    this.joinRef,
  });

  /// Builds an outgoing message for a channel [event].
  ///
  /// [Binding]s in the payload are replaced by their serializable shape, both
  /// because they hold a callback that cannot be encoded and because a codec
  /// running on a background isolate cannot be handed a closure.
  @internal
  static RealtimeMessage outgoing({
    required String topic,
    required ChannelEvent event,
    required Object? payload,
    String? ref,
    String? joinRef,
  }) {
    return RealtimeMessage(
      topic: topic,
      // The heartbeat is the one event the server does not expect a `phx_`
      // prefix on.
      event: event == ChannelEvent.heartbeat ? 'heartbeat' : event.eventName(),
      payload: _withoutBindings(payload),
      ref: ref,
      joinRef: joinRef,
    );
  }

  /// Reads a message from the JSON structure of a [version] frame.
  ///
  /// Throws a [FormatException] when [json] does not have the shape [version]
  /// prescribes.
  factory RealtimeMessage.fromJson(
    Object? json, [
    RealtimeProtocolVersion version = RealtimeProtocolVersion.v2,
  ]) {
    return switch (version) {
      RealtimeProtocolVersion.v1 => _fromObject(json),
      RealtimeProtocolVersion.v2 => _fromArray(json),
    };
  }

  /// The JSON structure of this message for [version].
  ///
  /// Protocol `2.0.0` puts the fields in a positional array, the legacy
  /// `1.0.0` protocol uses an object and leaves out the references it has none
  /// of.
  Object toJson([
    RealtimeProtocolVersion version = RealtimeProtocolVersion.v2,
  ]) {
    return switch (version) {
      RealtimeProtocolVersion.v1 => {
        'topic': topic,
        'event': event,
        'payload': payload,
        'ref': ?ref,
        'join_ref': ?joinRef,
      },
      RealtimeProtocolVersion.v2 => [joinRef, ref, topic, event, payload],
    };
  }

  static RealtimeMessage _fromObject(Object? json) {
    if (json is! Map) {
      throw FormatException('Invalid 1.0.0 message', json);
    }
    final topic = json['topic'];
    final event = json['event'];
    final ref = json['ref'];
    final joinRef = json['join_ref'];
    if (topic is! String ||
        event is! String ||
        ref is! String? ||
        joinRef is! String?) {
      throw FormatException('Invalid 1.0.0 message', json);
    }
    return RealtimeMessage(
      topic: topic,
      event: event,
      payload: json['payload'],
      ref: ref,
      joinRef: joinRef,
    );
  }

  static RealtimeMessage _fromArray(Object? json) {
    if (json is! List || json.length < 5) {
      throw FormatException('Invalid 2.0.0 message', json);
    }
    final joinRef = json[0];
    final ref = json[1];
    final topic = json[2];
    final event = json[3];
    if (joinRef is! String? ||
        ref is! String? ||
        topic is! String ||
        event is! String) {
      throw FormatException('Invalid 2.0.0 message', json);
    }
    return RealtimeMessage(
      joinRef: joinRef,
      ref: ref,
      topic: topic,
      event: event,
      payload: json[4],
    );
  }

  static Object? _withoutBindings(Object? payload) {
    if (payload is! Map) {
      return payload;
    }
    return {
      for (final entry in payload.entries)
        entry.key: entry.value is Map
            ? {
                for (final inner in (entry.value as Map).entries)
                  inner.key: inner.value is Binding
                      ? {
                          'type': (inner.value as Binding).type,
                          'filter': (inner.value as Binding).filter,
                        }
                      : inner.value,
              }
            : entry.value,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is RealtimeMessage &&
        other.joinRef == joinRef &&
        other.ref == ref &&
        other.topic == topic &&
        other.event == event &&
        const DeepCollectionEquality().equals(other.payload, payload);
  }

  @override
  int get hashCode => Object.hash(
    joinRef,
    ref,
    topic,
    event,
    const DeepCollectionEquality().hash(payload),
  );

  @override
  String toString() {
    return 'RealtimeMessage(joinRef: $joinRef, ref: $ref, topic: $topic, '
        'event: $event, payload: $payload)';
  }
}
