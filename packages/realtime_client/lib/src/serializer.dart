import 'dart:convert';
import 'dart:typed_data';

/// Encodes and decodes Realtime protocol `2.0.0` frames.
///
/// Text frames use the positional JSON array
/// `[joinRef, ref, topic, event, payload]` instead of the `1.0.0` object
/// layout. This lets the server skip part of the JSON encoding/decoding work,
/// lowering latency.
///
/// Broadcast messages whose user payload is binary are sent as binary
/// WebSocket frames so that raw bytes can be forwarded without JSON encoding.
/// Incoming binary broadcast frames are decoded back into the same map shape as
/// their JSON counterparts.
class Serializer {
  static const int headerLength = 1;
  static const int userBroadcastPushMetaLength = 6;

  /// Size bytes after the kind byte of a `userBroadcast` frame:
  /// topic size, user event size, metadata size and payload encoding.
  static const int userBroadcastMetaLength = 4;

  /// Binary frame sent by the client for a broadcast push.
  static const int kindUserBroadcastPush = 3;

  /// Binary frame received from the server for a broadcast.
  // ignore: avoid-duplicate-constant-values
  static const int kindUserBroadcast = 4;

  static const int binaryEncoding = 0;
  static const int jsonEncoding = 1;
  static const String broadcastEvent = 'broadcast';

  /// Keys of the broadcast payload that are forwarded as frame metadata when
  /// sending a binary broadcast push.
  final List<String> allowedMetadataKeys;

  const Serializer({List<String>? allowedMetadataKeys})
      : allowedMetadataKeys = allowedMetadataKeys ?? const [];

  /// Encodes a message map into the string or binary representation that is
  /// written to the WebSocket.
  ///
  /// [message] is expected to hold `join_ref`, `ref`, `topic`, `event` and
  /// `payload` keys, matching the output of `Message.toJson()`.
  Object encode(Map<String, dynamic> message) {
    final payload = message['payload'];
    if (message['event'] == broadcastEvent &&
        payload is Map &&
        payload['event'] is String &&
        _isBinary(payload['payload'])) {
      return _encodeBinaryUserBroadcastPush(message, payload);
    }

    return jsonEncode([
      message['join_ref'],
      message['ref'],
      message['topic'],
      message['event'],
      payload,
    ]);
  }

  /// Decodes a raw WebSocket frame into a message map with `join_ref`, `ref`,
  /// `topic`, `event` and `payload` keys.
  Map<String, dynamic> decode(Object rawPayload) {
    if (rawPayload is String) {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! List || decoded.length < 5) {
        throw FormatException('Invalid 2.0.0 text frame', rawPayload);
      }
      return {
        'join_ref': decoded[0],
        'ref': decoded[1],
        'topic': decoded[2],
        'event': decoded[3],
        'payload': decoded[4],
      };
    }

    final bytes = _asBytes(rawPayload);
    if (bytes != null) {
      return _binaryDecode(bytes);
    }

    return {};
  }

  Uint8List _encodeBinaryUserBroadcastPush(
    Map<String, dynamic> message,
    Map<dynamic, dynamic> payload,
  ) {
    final topic = (message['topic'] ?? '') as String;
    final ref = (message['ref'] ?? '') as String;
    final joinRef = (message['join_ref'] ?? '') as String;
    final userEvent = payload['event'] as String;
    final encodedPayload = _asBytes(payload['payload'])!;

    final rest = allowedMetadataKeys.isEmpty
        ? const <String, dynamic>{}
        : _pick(payload, allowedMetadataKeys);
    final metadata = rest.isEmpty ? '' : jsonEncode(rest);

    _checkLength('joinRef', joinRef.length);
    _checkLength('ref', ref.length);
    _checkLength('topic', topic.length);
    _checkLength('userEvent', userEvent.length);
    _checkLength('metadata', metadata.length);

    final metaLength = userBroadcastPushMetaLength +
        joinRef.length +
        ref.length +
        topic.length +
        userEvent.length +
        metadata.length;

    final frame = Uint8List(headerLength + metaLength + encodedPayload.length);
    var offset = 0;
    frame[offset++] = kindUserBroadcastPush;
    frame[offset++] = joinRef.length;
    frame[offset++] = ref.length;
    frame[offset++] = topic.length;
    frame[offset++] = userEvent.length;
    frame[offset++] = metadata.length;
    frame[offset++] = binaryEncoding;
    offset = _writeString(frame, offset, joinRef);
    offset = _writeString(frame, offset, ref);
    offset = _writeString(frame, offset, topic);
    offset = _writeString(frame, offset, userEvent);
    offset = _writeString(frame, offset, metadata);

    frame.setAll(offset, encodedPayload);
    return frame;
  }

  Map<String, dynamic> _binaryDecode(Uint8List buffer) {
    final view = ByteData.sublistView(buffer);
    final kind = view.getUint8(0);
    switch (kind) {
      case kindUserBroadcast:
        return _decodeUserBroadcast(buffer, view);
      default:
        return {};
    }
  }

  Map<String, dynamic> _decodeUserBroadcast(Uint8List buffer, ByteData view) {
    final topicSize = view.getUint8(1);
    final userEventSize = view.getUint8(2);
    final metadataSize = view.getUint8(3);
    final payloadEncoding = view.getUint8(4);

    var offset = headerLength + userBroadcastMetaLength;
    final topic =
        utf8.decode(Uint8List.sublistView(buffer, offset, offset + topicSize));
    offset += topicSize;
    final userEvent = utf8
        .decode(Uint8List.sublistView(buffer, offset, offset + userEventSize));
    offset += userEventSize;
    final metadata = metadataSize > 0
        ? utf8.decode(
            Uint8List.sublistView(buffer, offset, offset + metadataSize))
        : '';
    offset += metadataSize;

    final payloadBytes = Uint8List.sublistView(buffer, offset);
    final dynamic parsedPayload = payloadEncoding == jsonEncoding
        ? jsonDecode(utf8.decode(payloadBytes))
        : payloadBytes;

    final data = {
      'type': broadcastEvent,
      'event': userEvent,
      'payload': parsedPayload,
    };
    if (metadataSize > 0) {
      data['meta'] = jsonDecode(metadata);
    }

    return {
      'join_ref': null,
      'ref': null,
      'topic': topic,
      'event': broadcastEvent,
      'payload': data,
    };
  }

  void _checkLength(String field, int length) {
    if (length > 255) {
      throw ArgumentError('$field length $length exceeds maximum of 255');
    }
  }

  // Writes one byte per UTF-16 code unit, matching the size byte (which is the
  // code-unit count). Frame string fields (joinRef, ref, topic, userEvent,
  // metadata) are therefore assumed to be ASCII; non-ASCII characters would be
  // truncated and not round-trip through the utf8 decode on the other side.
  int _writeString(Uint8List buffer, int offset, String value) {
    for (final unit in value.codeUnits) {
      buffer[offset++] = unit & 0xFF;
    }
    return offset;
  }

  bool _isBinary(dynamic value) {
    return value is Uint8List || value is ByteBuffer || value is TypedData;
  }

  Uint8List? _asBytes(dynamic value) {
    if (value is Uint8List) {
      return value;
    }
    if (value is ByteBuffer) {
      return value.asUint8List();
    }
    if (value is TypedData) {
      return value.buffer.asUint8List(value.offsetInBytes, value.lengthInBytes);
    }
    if (value is List<int>) {
      return Uint8List.fromList(value);
    }
    return null;
  }

  Map<String, dynamic> _pick(Map<dynamic, dynamic> source, List<String> keys) {
    return {
      for (final key in keys)
        if (source.containsKey(key)) key: source[key],
    };
  }
}
