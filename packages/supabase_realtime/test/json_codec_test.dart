import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:test/test.dart';

import 'socket_test_stubs.dart';

void main() {
  const socketEndpoint = 'wss://localhost:0/';

  late MockIOWebSocketChannel mockedChannel;
  late MockWebSocketSink mockedSink;
  late List<Object?> written;

  setUp(() {
    mockedChannel = MockIOWebSocketChannel();
    mockedSink = MockWebSocketSink();
    written = [];

    when(() => mockedChannel.sink).thenReturn(mockedSink);
    when(() => mockedChannel.ready).thenAnswer((_) => Future.value());
    when(() => mockedSink.close()).thenAnswer((_) => Future.value());
    when(() => mockedSink.add(any())).thenAnswer((invocation) {
      written.add(invocation.positionalArguments.first);
    });
  });

  RealtimeClient createClient({
    AsyncJsonCodec? jsonCodec,
    RealtimeEncode? encode,
    RealtimeDecode? decode,
    RealtimeProtocolVersion version = RealtimeProtocolVersion.v2,
  }) {
    final client = RealtimeClient(
      socketEndpoint,
      transport: (url, headers) => mockedChannel,
      jsonCodec: jsonCodec,
      encode: encode,
      decode: decode,
      version: version,
    );
    unawaited(client.connect());
    client.connectionState = SocketState.open;
    return client;
  }

  RealtimeMessage messageWithRef(String ref) => RealtimeMessage(
    topic: 'realtime:room',
    event: 'broadcast',
    payload: const {'type': 'broadcast', 'event': 'cursor'},
    ref: ref,
  );

  String frameWithRef(String ref) => jsonEncode([
    null,
    ref,
    'realtime:room',
    'broadcast',
    const {'type': 'broadcast', 'event': 'cursor'},
  ]);

  group('outgoing frames', () {
    test('are encoded by the codec', () async {
      final jsonCodec = _RecordingJsonCodec();
      final client = createClient(jsonCodec: jsonCodec);

      client.push(messageWithRef('1'));
      await pumpEventQueue();

      expect(written, [jsonEncode(messageWithRef('1').toJson())]);
      expect(jsonCodec.encoded, hasLength(1));
    });

    test('are encoded by the codec on the legacy protocol', () async {
      final jsonCodec = _RecordingJsonCodec();
      final client = createClient(
        jsonCodec: jsonCodec,
        version: RealtimeProtocolVersion.v1,
      );

      client.push(messageWithRef('1'));
      await pumpEventQueue();

      expect(written, [
        jsonEncode(messageWithRef('1').toJson(RealtimeProtocolVersion.v1)),
      ]);
      expect(jsonCodec.encoded, hasLength(1));
    });

    test('bypass the codec for a binary broadcast', () async {
      final jsonCodec = _RecordingJsonCodec();
      final client = createClient(jsonCodec: jsonCodec);

      client.push(
        RealtimeMessage(
          topic: 'realtime:room',
          event: 'broadcast',
          payload: {
            'type': 'broadcast',
            'event': 'cursor',
            'payload': Uint8List.fromList([1, 2, 3]),
          },
          ref: '1',
        ),
      );
      await pumpEventQueue();

      expect(written.single, isA<Uint8List>());
      expect(jsonCodec.encoded, isEmpty);
    });

    test('use a custom encode over the codec', () async {
      final jsonCodec = _RecordingJsonCodec();
      final client = createClient(
        jsonCodec: jsonCodec,
        encode: (message) async => 'custom-${message.ref}',
      );

      client.push(messageWithRef('1'));
      await pumpEventQueue();

      expect(written, ['custom-1']);
      expect(jsonCodec.encoded, isEmpty);
    });
  });

  group('incoming frames', () {
    test('are decoded by the codec', () async {
      final jsonCodec = _RecordingJsonCodec();
      final client = createClient(jsonCodec: jsonCodec);
      final received = <String?>[];
      client.onMessage.listen((message) => received.add(message.ref));

      client.onConnectionMessage(frameWithRef('1'));
      await pumpEventQueue();

      expect(received, ['1']);
      expect(jsonCodec.decoded, [frameWithRef('1')]);
    });

    test('are dispatched in arrival order', () async {
      final jsonCodec = _GatedJsonCodec();
      final client = createClient(jsonCodec: jsonCodec);
      final received = <String?>[];
      client.onMessage.listen((message) => received.add(message.ref));

      client.onConnectionMessage(frameWithRef('1'));
      client.onConnectionMessage(frameWithRef('2'));
      await pumpEventQueue();

      jsonCodec.completeDecode(frameWithRef('2'));
      await pumpEventQueue();

      expect(received, isEmpty);

      jsonCodec.completeDecode(frameWithRef('1'));
      await pumpEventQueue();

      expect(received, ['1', '2']);
    });

    test('use a custom decode over the codec', () async {
      final jsonCodec = _RecordingJsonCodec();
      final client = createClient(
        jsonCodec: jsonCodec,
        decode: (frame) async => messageWithRef('custom'),
      );
      final received = <String?>[];
      client.onMessage.listen((message) => received.add(message.ref));

      client.onConnectionMessage(frameWithRef('1'));
      await pumpEventQueue();

      expect(received, ['custom']);
      expect(jsonCodec.decoded, isEmpty);
    });
  });

  test('without a codec the built-in one writes without a microtask hop', () {
    final client = createClient();

    client.push(messageWithRef('1'));

    expect(written, hasLength(1));
  });
}

/// An [AsyncJsonCodec] that works inline and records what it processed.
class _RecordingJsonCodec implements AsyncJsonCodec {
  final List<Object?> encoded = [];
  final List<String> decoded = [];

  @override
  Future<dynamic> decode(String json) async {
    decoded.add(json);
    return jsonDecode(json);
  }

  @override
  Future<dynamic> decodeBytes(Uint8List encodedJson) =>
      decode(utf8.decode(encodedJson));

  @override
  Future<String> encode(Object? json) async {
    encoded.add(json);
    return jsonEncode(json);
  }

  @override
  Future<void> dispose() async {}
}

/// An [AsyncJsonCodec] whose decodes complete only when the test says so, so
/// that frames can be completed out of the order they arrived in.
class _GatedJsonCodec implements AsyncJsonCodec {
  final Map<String, Completer<dynamic>> _gates = {};

  void completeDecode(String json) {
    _gate(json).complete(jsonDecode(json));
  }

  Completer<dynamic> _gate(String json) =>
      _gates.putIfAbsent(json, Completer<dynamic>.new);

  @override
  Future<dynamic> decode(String json) => _gate(json).future;

  @override
  Future<dynamic> decodeBytes(Uint8List encodedJson) =>
      decode(utf8.decode(encodedJson));

  @override
  Future<String> encode(Object? json) async => jsonEncode(json);

  @override
  Future<void> dispose() async {}
}
