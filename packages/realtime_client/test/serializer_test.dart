import 'dart:convert';
import 'dart:typed_data';

import 'package:realtime_client/src/serializer.dart';
import 'package:test/test.dart';

/// Builds a `kind = userBroadcast` (4) binary frame the same way the server
/// does, so the decoder can be exercised in isolation.
Uint8List buildUserBroadcastFrame({
  required String topic,
  required String event,
  required Uint8List payload,
  required int encoding,
  String metadata = '',
}) {
  final topicBytes = utf8.encode(topic);
  final eventBytes = utf8.encode(event);
  final metadataBytes = utf8.encode(metadata);

  final header = <int>[
    Serializer.kindUserBroadcast,
    topicBytes.length,
    eventBytes.length,
    metadataBytes.length,
    encoding,
  ];

  return Uint8List.fromList([
    ...header,
    ...topicBytes,
    ...eventBytes,
    ...metadataBytes,
    ...payload,
  ]);
}

void main() {
  late Serializer serializer;

  setUp(() {
    serializer = Serializer();
  });

  group('encode text frames', () {
    test('encodes a message as a positional JSON array', () {
      final result = serializer.encode({
        'join_ref': '1',
        'ref': '2',
        'topic': 'realtime:room',
        'event': 'phx_join',
        'payload': {'foo': 'bar'},
      });

      expect(result, isA<String>());
      expect(
        jsonDecode(result as String),
        equals([
          '1',
          '2',
          'realtime:room',
          'phx_join',
          {'foo': 'bar'},
        ]),
      );
    });

    test('preserves null join_ref and ref positionally', () {
      final result = serializer.encode({
        'topic': 'phoenix',
        'event': 'heartbeat',
        'payload': <String, dynamic>{},
      });

      expect(
        jsonDecode(result as String),
        equals([null, null, 'phoenix', 'heartbeat', <String, dynamic>{}]),
      );
    });

    test('encodes a non-binary broadcast as a text frame', () {
      final result = serializer.encode({
        'join_ref': '1',
        'ref': '2',
        'topic': 'realtime:room',
        'event': 'broadcast',
        'payload': {'event': 'cursor', 'type': 'broadcast', 'x': 1},
      });

      expect(result, isA<String>());
      expect((jsonDecode(result as String) as List)[3], 'broadcast');
    });
  });

  group('decode text frames', () {
    test('decodes a positional JSON array into a message map', () {
      final result = serializer.decode(
        jsonEncode([
          '1',
          '2',
          'realtime:room',
          'phx_reply',
          {'status': 'ok'}
        ]),
      );

      expect(result, {
        'join_ref': '1',
        'ref': '2',
        'topic': 'realtime:room',
        'event': 'phx_reply',
        'payload': {'status': 'ok'},
      });
    });
  });

  group('decode binary frames', () {
    test('decodes a JSON-encoded user broadcast', () {
      final frame = buildUserBroadcastFrame(
        topic: 'realtime:room',
        event: 'cursor',
        payload: Uint8List.fromList(utf8.encode(jsonEncode({'x': 1, 'y': 2}))),
        encoding: Serializer.jsonEncoding,
        metadata: jsonEncode({'replayed': true}),
      );

      final result = serializer.decode(frame);

      expect(result['join_ref'], isNull);
      expect(result['ref'], isNull);
      expect(result['topic'], 'realtime:room');
      expect(result['event'], 'broadcast');
      expect(result['payload'], {
        'type': 'broadcast',
        'event': 'cursor',
        'payload': {'x': 1, 'y': 2},
        'meta': {'replayed': true},
      });
    });

    test('decodes a binary user broadcast payload as raw bytes', () {
      final rawPayload = Uint8List.fromList([1, 2, 3, 4, 255]);
      final frame = buildUserBroadcastFrame(
        topic: 'realtime:room',
        event: 'file',
        payload: rawPayload,
        encoding: Serializer.binaryEncoding,
      );

      final result = serializer.decode(frame);
      final payload = result['payload'] as Map<String, dynamic>;

      expect(payload['event'], 'file');
      expect(payload['payload'], rawPayload);
      expect(payload.containsKey('meta'), isFalse);
    });

    test('returns an empty map for unknown binary kinds', () {
      final result = serializer.decode(Uint8List.fromList([99, 0, 0]));
      expect(result, <String, dynamic>{});
    });
  });

  group('encode binary broadcast push', () {
    test('encodes a broadcast with a binary payload as a binary frame', () {
      final payload = Uint8List.fromList([10, 20, 30]);
      final result = serializer.encode({
        'join_ref': '7',
        'ref': '8',
        'topic': 'realtime:room',
        'event': 'broadcast',
        'payload': {
          'type': 'broadcast',
          'event': 'file',
          'payload': payload,
        },
      });

      expect(result, isA<Uint8List>());
      final bytes = result as Uint8List;

      expect(bytes[0], Serializer.kindUserBroadcastPush);
      expect(bytes[1], '7'.length); // joinRef length
      expect(bytes[2], '8'.length); // ref length
      expect(bytes[3], 'realtime:room'.length); // topic length
      expect(bytes[4], 'file'.length); // userEvent length
      expect(bytes[5], 0); // metadata length (no allowed keys)
      expect(bytes[6], Serializer.binaryEncoding); // encoding

      // The user payload is appended verbatim at the end of the frame.
      expect(bytes.sublist(bytes.length - payload.length), payload);
    });

    test('forwards allowed metadata keys', () {
      final serializerWithMeta = Serializer(allowedMetadataKeys: ['trace_id']);
      final result = serializerWithMeta.encode({
        'topic': 'realtime:room',
        'event': 'broadcast',
        'payload': {
          'type': 'broadcast',
          'event': 'file',
          'trace_id': 'abc',
          'ignored': 'nope',
          'payload': Uint8List.fromList([1]),
        },
      });

      final bytes = result as Uint8List;
      final metadataLength = bytes[5];
      expect(metadataLength, greaterThan(0));

      // metadata sits after the header and the joinRef/ref/topic/event strings.
      final metadataStart = Serializer.headerLength +
          Serializer.userBroadcastPushMetaLength +
          0 + // joinRef
          0 + // ref
          'realtime:room'.length +
          'file'.length;
      final metadata = utf8
          .decode(bytes.sublist(metadataStart, metadataStart + metadataLength));
      expect(jsonDecode(metadata), {'trace_id': 'abc'});
    });

    test('throws when a frame field exceeds 255 bytes', () {
      final longTopic = 'a' * 256;
      expect(
        () => serializer.encode({
          'topic': longTopic,
          'event': 'broadcast',
          'payload': {
            'type': 'broadcast',
            'event': 'file',
            'payload': Uint8List.fromList([1]),
          },
        }),
        throwsArgumentError,
      );
    });
  });
}
