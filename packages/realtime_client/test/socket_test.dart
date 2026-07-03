import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/constants.dart';
import 'package:realtime_client/src/message.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'socket_test_stubs.dart';

typedef WebSocketChannelClosure =
    WebSocketChannel Function(
      String url,
      Map<String, String> headers,
    );

/// Generate a JWT token for testing purposes
///
/// [exp] in seconds since Epoch
String generateJwt([int? exp]) {
  final header = {'alg': 'HS256', 'typ': 'JWT'};

  final now = DateTime.now();
  final expiry =
      exp ??
      (now.add(Duration(hours: 1)).millisecondsSinceEpoch / 1000).floor();

  final payload = {'exp': expiry};

  final key = 'your-256-bit-secret';

  final encodedHeader = base64Url.encode(utf8.encode(json.encode(header)));
  final encodedPayload = base64Url.encode(utf8.encode(json.encode(payload)));

  final signatureInput = '$encodedHeader.$encodedPayload';
  final hmac = Hmac(sha256, utf8.encode(key));
  final digest = hmac.convert(utf8.encode(signatureInput));
  final signature = base64Url.encode(digest.bytes);

  return '$encodedHeader.$encodedPayload.$signature';
}

void main() {
  const socketEndpoint = 'wss://localhost:0/';

  late HttpServer mockServer;

  setUp(() async {
    mockServer = await HttpServer.bind('localhost', 0);
    WebSocketChannel? channel;

    mockServer
        .transform(WebSocketTransformer())
        .listen(
          (webSocket) {
            channel = IOWebSocketChannel(webSocket);
            channel!.stream.listen((request) {
              channel!.sink.add(request);
            });
          },
          onDone: () {
            unawaited(channel?.sink.close());
          },
        );
  });

  tearDown(() async {
    await mockServer.close();
  });

  group('constructor', () {
    test('sets defaults', () async {
      final socket = RealtimeClient(
        'wss://example.com/socket',
        params: {'apikey': '123'},
      );
      expect(socket.channels, isEmpty);
      expect(socket.sendBuffer, isEmpty);
      expect(socket.ref, 0);
      expect(socket.endPoint, 'wss://example.com/socket/websocket');
      expect(socket.stateChangeCallbacks, {
        'open': [],
        'close': [],
        'error': [],
        'message': [],
      });
      expect(socket.timeout, const Duration(milliseconds: 10000));
      expect(socket.heartbeatIntervalMs, Constants.defaultHeartbeatIntervalMs);
      expect(
        socket.logger
            is void Function(
              String? kind,
              String? msg,
              dynamic data,
            ),
        isFalse,
      );
      expect(
        socket.headers['X-Client-Info']!.split('/').first,
        'realtime-dart',
      );
      expect(socket.accessToken, '123');
    });

    test('overrides some defaults with options', () async {
      final socket = RealtimeClient(
        'wss://example.com/socket',
        timeout: const Duration(milliseconds: 40000),
        heartbeatIntervalMs: 60000,
        // ignore: avoid_print
        logger: (kind, msg, data) => print('[$kind] $msg $data'),
        headers: {'X-Client-Info': 'supabase-dart/0.0.0'},
      );
      expect(socket.channels, isEmpty);
      expect(socket.sendBuffer, isEmpty);
      expect(socket.ref, 0);
      expect(socket.endPoint, 'wss://example.com/socket/websocket');
      expect(socket.stateChangeCallbacks, {
        'open': [],
        'close': [],
        'error': [],
        'message': [],
      });
      expect(socket.timeout, const Duration(milliseconds: 40000));
      expect(socket.heartbeatIntervalMs, 60000);
      expect(
        socket.logger
            is void Function(
              String? kind,
              String? msg,
              dynamic data,
            ),
        isTrue,
      );
      expect(socket.headers['X-Client-Info'], 'supabase-dart/0.0.0');
    });
  });

  group('endpointURL', () {
    test('returns endpoint for given full url', () {
      final socket = RealtimeClient('wss://example.org/chat');
      expect(
        socket.endPointURL,
        'wss://example.org/chat/websocket?vsn=2.0.0',
      );
    });

    test('returns endpoint with parameters', () {
      final socket = RealtimeClient(
        'ws://example.org/chat',
        params: {'foo': 'bar'},
      );
      expect(
        socket.endPointURL,
        'ws://example.org/chat/websocket?foo=bar&vsn=2.0.0',
      );
    });

    test('returns endpoint with apikey', () {
      final socket = RealtimeClient(
        'ws://example.org/chat',
        params: {
          'apikey': '123456789',
        },
      );
      expect(
        socket.endPointURL,
        'ws://example.org/chat/websocket?apikey=123456789&vsn=2.0.0',
      );
    });

    test('uses the legacy vsn when version is v1', () {
      final socket = RealtimeClient(
        'wss://example.org/chat',
        version: RealtimeProtocolVersion.v1,
      );
      expect(
        socket.endPointURL,
        'wss://example.org/chat/websocket?vsn=1.0.0',
      );
    });
  });

  group('connect with Websocket', () {
    late RealtimeClient socket;

    setUp(() {
      socket = RealtimeClient('ws://localhost:${mockServer.port}');
    });

    tearDown(() async {
      await socket.disconnect();
    });

    test('establishes websocket connection with endpoint', () async {
      final connFuture = socket.connect();
      expect(socket.connState, SocketStates.connecting);

      final conn = socket.conn;

      await connFuture;
      expect(socket.connState, SocketStates.open);

      expect(conn, isA<IOWebSocketChannel>());
      //! Not verifying connection url
    });

    test('sets callbacks for connection', () async {
      int opens = 0;
      socket.onOpen(() {
        opens += 1;
      });
      int closes = 0;
      socket.onClose((_) {
        closes += 1;
      });
      late dynamic lastMsg;
      socket.onMessage((m) {
        lastMsg = m;
      });

      await socket.connect();
      await Future.delayed(const Duration(milliseconds: 200));
      expect(opens, 1);

      await socket.sendHeartbeat();
      // need to wait for event to trigger
      await Future.delayed(const Duration(seconds: 1));
      expect(lastMsg['event'], 'heartbeat');

      await socket.disconnect();
      await Future.delayed(const Duration(seconds: 1));
      expect(closes, 1);
    });

    test('sets callback for errors', () {
      dynamic lastErr;
      final RealtimeClient erroneousSocket = RealtimeClient('badurl')
        ..onError((e) {
          lastErr = e;
        });

      unawaited(erroneousSocket.connect());

      expect(lastErr, isA<WebSocketException>());
    });

    test('is idempotent', () {
      unawaited(socket.connect());
      final conn = socket.conn;
      unawaited(socket.connect());
      expect(socket.conn, conn);
    });
  });

  group('disconnect', () {
    late RealtimeClient socket;
    setUp(() {
      socket = RealtimeClient('ws://localhost:${mockServer.port}');
    });

    tearDown(() async {
      await socket.disconnect();
    });

    test('removes existing connection', () async {
      await socket.connect();

      expect(socket.conn, isNotNull);
      await socket.disconnect();

      expect(socket.conn, isNull);
    });

    test('calls callback', () async {
      int closes = 0;
      unawaited(socket.connect());
      unawaited(socket.disconnect());
      closes += 1;

      expect(closes, 1);
    });

    test('calls connection close callback', () async {
      final mockedSocketChannel = MockIOWebSocketChannel();
      final mockedSocket = RealtimeClient(
        socketEndpoint,
        transport: (url, headers) {
          return mockedSocketChannel;
        },
      );
      final mockedSink = MockWebSocketSink();

      when(() => mockedSocketChannel.sink).thenReturn(mockedSink);
      when(
        () => mockedSink.close(any(), any()),
      ).thenAnswer((_) => Future.value());

      const tCode = 12;
      const tReason = 'reason';

      await mockedSocket.connect();
      mockedSocket.connState = SocketStates.open;
      await Future.delayed(const Duration(milliseconds: 200));
      await mockedSocket.disconnect(code: tCode, reason: tReason);
      await Future.delayed(const Duration(milliseconds: 200));

      verify(
        () => mockedSink.close(
          captureAny(that: equals(tCode)),
          captureAny(that: equals(tReason)),
        ),
      ).called(1);
    });

    test('disconnecting a closed connections stays closed', () async {
      await socket.connect();
      expect(socket.connState, SocketStates.open);
      await mockServer.close();
      await Future.delayed(const Duration(milliseconds: 200));
      expect(socket.connState, SocketStates.closed);
      expect(socket.conn, isNotNull);

      final disconnectFuture = socket.disconnect();

      // `connState` stays `closed` during disconnect
      expect(socket.connState, SocketStates.closed);
      await disconnectFuture;
      expect(socket.connState, SocketStates.closed);
      expect(socket.conn, isNull);
    });

    test('cancels a pending reconnect after an unexpected drop', () async {
      final streamController = StreamController<dynamic>();
      final mockedSocketChannel = MockIOWebSocketChannel();
      final mockedSink = MockWebSocketSink();
      var connectCount = 0;

      when(() => mockedSocketChannel.ready).thenAnswer((_) => Future.value());
      when(() => mockedSocketChannel.sink).thenReturn(mockedSink);
      when(
        () => mockedSocketChannel.stream,
      ).thenAnswer((_) => streamController.stream);
      when(
        () => mockedSink.close(any(), any()),
      ).thenAnswer((_) => Future.value());
      when(() => mockedSink.close()).thenAnswer((_) => Future.value());

      final mockedSocket = RealtimeClient(
        socketEndpoint,
        // Reconnect almost immediately so the test doesn't wait for the
        // default backoff.
        reconnectAfterMs: (tries) => 20,
        transport: (url, headers) {
          connectCount++;
          return mockedSocketChannel;
        },
      );

      await mockedSocket.connect();
      expect(connectCount, 1);

      // Simulate the server dropping the connection: `onDone` fires, the socket
      // is marked closed and a reconnect is scheduled.
      await streamController.close();
      await Future.delayed(const Duration(milliseconds: 5));
      expect(mockedSocket.connState, SocketStates.closed);

      // The user disconnects explicitly while the socket is already closed.
      await mockedSocket.disconnect();

      // Wait past the reconnect delay; the scheduled reconnect must be canceled.
      await Future.delayed(const Duration(milliseconds: 60));
      expect(
        connectCount,
        1,
        reason: 'must not reopen after a user disconnect',
      );
    });

    test('reconnects on a manual connect() after an unexpected drop', () async {
      final firstController = StreamController<dynamic>();
      final firstChannel = MockIOWebSocketChannel();
      final firstSink = MockWebSocketSink();
      when(() => firstChannel.ready).thenAnswer((_) => Future.value());
      when(() => firstChannel.sink).thenReturn(firstSink);
      when(() => firstChannel.stream).thenAnswer((_) => firstController.stream);
      when(
        () => firstSink.close(any(), any()),
      ).thenAnswer((_) => Future.value());
      when(() => firstSink.close()).thenAnswer((_) => Future.value());

      final secondController = StreamController<dynamic>();
      addTearDown(secondController.close);
      final secondChannel = MockIOWebSocketChannel();
      final secondSink = MockWebSocketSink();
      when(() => secondChannel.ready).thenAnswer((_) => Future.value());
      when(() => secondChannel.sink).thenReturn(secondSink);
      when(
        () => secondChannel.stream,
      ).thenAnswer((_) => secondController.stream);
      when(
        () => secondSink.close(any(), any()),
      ).thenAnswer((_) => Future.value());
      when(() => secondSink.close()).thenAnswer((_) => Future.value());

      var connectCount = 0;
      final mockedSocket = RealtimeClient(
        socketEndpoint,
        // Large delay so the automatic reconnect stays dormant during the
        // test and the manual reconnect below is what reopens the socket.
        reconnectAfterMs: (tries) => 100000,
        transport: (url, headers) {
          connectCount++;
          return connectCount == 1 ? firstChannel : secondChannel;
        },
      );

      await mockedSocket.connect();
      expect(connectCount, 1);
      expect(mockedSocket.connState, SocketStates.open);

      // Simulate the server dropping the connection.
      await firstController.close();
      await Future.delayed(const Duration(milliseconds: 5));
      expect(mockedSocket.connState, SocketStates.closed);

      // A manual reconnect must open a fresh connection instead of being a
      // no-op because `conn` still references the dropped socket.
      await mockedSocket.connect();
      expect(
        connectCount,
        2,
        reason: 'manual connect() must reconnect after a drop',
      );
      expect(mockedSocket.connState, SocketStates.open);

      await mockedSocket.disconnect();
    });

    test('grows the reconnect backoff across failed attempts', () async {
      final triesSeen = <int>[];
      var attempt = 0;

      final failingChannel = MockIOWebSocketChannel();
      final failingSink = MockWebSocketSink();
      when(
        () => failingChannel.ready,
      ).thenAnswer((_) => Future.error(Exception('unavailable')));
      when(() => failingChannel.sink).thenReturn(failingSink);
      when(
        () => failingSink.close(any(), any()),
      ).thenAnswer((_) => Future.value());
      when(() => failingSink.close()).thenAnswer((_) => Future.value());

      final successController = StreamController<dynamic>();
      addTearDown(successController.close);
      final successChannel = MockIOWebSocketChannel();
      final successSink = MockWebSocketSink();
      when(() => successChannel.ready).thenAnswer((_) => Future.value());
      when(() => successChannel.sink).thenReturn(successSink);
      when(
        () => successChannel.stream,
      ).thenAnswer((_) => successController.stream);
      when(
        () => successSink.close(any(), any()),
      ).thenAnswer((_) => Future.value());
      when(() => successSink.close()).thenAnswer((_) => Future.value());

      final mockedSocket = RealtimeClient(
        socketEndpoint,
        reconnectAfterMs: (tries) {
          triesSeen.add(tries);
          return 10;
        },
        transport: (url, headers) {
          attempt++;
          // Fail the first attempts so the client keeps retrying, then let it
          // connect so the reconnect loop stops.
          return attempt <= 3 ? failingChannel : successChannel;
        },
      );

      await mockedSocket.connect();

      // Wait for the failing attempts to cycle and the fourth to connect.
      await Future.delayed(const Duration(milliseconds: 100));

      // The retry counter must grow (1, 2, 3, ...) across reconnect attempts
      // instead of being reset to 1 on every `disconnect()` in `_reconnect`.
      expect(triesSeen.take(3), [1, 2, 3]);
      expect(mockedSocket.connState, SocketStates.open);

      await mockedSocket.disconnect();
    });

    test('disconnecting an open connection', () async {
      await socket.connect();
      expect(socket.connState, SocketStates.open);

      final disconnectFuture = socket.disconnect();

      // `connState` stays `closed` during disconnect
      expect(socket.connState, SocketStates.disconnecting);
      await disconnectFuture;
      expect(socket.connState, SocketStates.disconnected);
      expect(socket.conn, isNull);
    });

    test('does not throw when no connection', () {
      expect(() => socket.disconnect(), returnsNormally);
    });
  });

  //! Note: not checking connection states since it is based on an enum.

  group('channel', () {
    const tTopic = 'topic';
    const tParams = RealtimeChannelConfig();
    late RealtimeClient socket;
    setUp(() {
      socket = RealtimeClient(socketEndpoint);
    });

    tearDown(() async {
      await socket.disconnect();
    });

    test('returns channel with given topic and params', () {
      final channel = socket.channel(
        tTopic,
        tParams,
      );

      expect(channel.socket, socket);
      expect(channel.topic, 'realtime:topic');
      expect(channel.params, {
        'config': {
          'broadcast': {'ack': false, 'self': false},
          'presence': {'key': '', 'enabled': false},
          'private': false,
        },
      });
    });

    test('adds channel to sockets channels list', () {
      expect(socket.channels, isEmpty);

      final channel = socket.channel(
        tTopic,
        tParams,
      );

      expect(socket.channels.length, 1);

      final foundChannel = socket.channels[0];
      expect(foundChannel, channel);
    });
  });

  group('remove', () {
    test('removes given channel from channels', () {
      final mockedChannel1 = MockChannel();
      when(() => mockedChannel1.joinRef).thenReturn('1');

      final mockedChannel2 = MockChannel();
      when(() => mockedChannel2.joinRef).thenReturn('2');

      const tTopic1 = 'topic-1';
      const tTopic2 = 'topic-2';

      final mockedSocket = SocketWithMockedChannel(socketEndpoint);
      mockedSocket.mockedChannelLooker.addAll({
        tTopic1: mockedChannel1,
        tTopic2: mockedChannel2,
      });

      final channel1 = mockedSocket.channel(tTopic1);
      final channel2 = mockedSocket.channel(tTopic2);

      mockedSocket.remove(channel1);
      expect(mockedSocket.channels.length, 1);

      final foundChannel = mockedSocket.channels[0];
      expect(foundChannel, channel2);
    });
  });

  group('push', () {
    const topic = 'topic';
    const event = ChannelEvents.join;
    const payload = 'payload';
    const ref = 'ref';
    // Protocol 2.0.0 text frames are positional arrays:
    // [join_ref, ref, topic, event, payload].
    final jsonData = json.encode([
      null,
      ref,
      topic,
      event.eventName(),
      payload,
    ]);

    IOWebSocketChannel mockedSocketChannel;
    late RealtimeClient mockedSocket;
    late WebSocketSink mockedSink;

    setUp(() {
      mockedSocketChannel = MockIOWebSocketChannel();
      mockedSocket = RealtimeClient(
        socketEndpoint,
        transport: (url, headers) {
          return mockedSocketChannel;
        },
      );
      mockedSink = MockWebSocketSink();

      when(() => mockedSocketChannel.sink).thenReturn(mockedSink);
      when(() => mockedSocketChannel.ready).thenAnswer((_) => Future.value());
      when(() => mockedSink.close()).thenAnswer((_) => Future.value());
    });

    test('sends data to connection when connected', () {
      unawaited(mockedSocket.connect());
      mockedSocket.connState = SocketStates.open;

      final message = Message(
        topic: topic,
        payload: payload,
        event: event,
        ref: ref,
      );
      mockedSocket.push(message);

      verify(
        () => mockedSink.add(captureAny(that: equals(jsonData))),
      ).called(1);
    });

    test('buffers data when not connected', () async {
      unawaited(mockedSocket.connect());
      mockedSocket.connState = SocketStates.connecting;

      expect(mockedSocket.sendBuffer, isEmpty);

      final message = Message(
        topic: topic,
        payload: payload,
        event: event,
        ref: ref,
      );
      mockedSocket.push(message);

      verifyNever(() => mockedSink.add(any()));
      expect(mockedSocket.sendBuffer.length, 1);

      final callback = mockedSocket.sendBuffer[0];
      callback();
      verify(
        () => mockedSink.add(captureAny(that: equals(jsonData))),
      ).called(1);
    });

    test('sends a broadcast with a binary payload as a binary frame', () {
      unawaited(mockedSocket.connect());
      mockedSocket.connState = SocketStates.open;

      final binaryPayload = Uint8List.fromList([1, 2, 3]);
      final message = Message(
        topic: 'realtime:room',
        event: ChannelEvents.broadcast,
        payload: {
          'type': 'broadcast',
          'event': 'file',
          'payload': binaryPayload,
        },
      );
      mockedSocket.push(message);

      verify(
        () => mockedSink.add(captureAny(that: isA<Uint8List>())),
      ).called(1);
    });

    test('encodes with the legacy object format when version is v1', () {
      final legacyChannel = MockIOWebSocketChannel();
      final legacySink = MockWebSocketSink();
      when(() => legacyChannel.sink).thenReturn(legacySink);
      when(() => legacyChannel.ready).thenAnswer((_) => Future.value());
      when(() => legacySink.close()).thenAnswer((_) => Future.value());

      final legacySocket = RealtimeClient(
        socketEndpoint,
        transport: (url, headers) => legacyChannel,
        version: RealtimeProtocolVersion.v1,
      );
      unawaited(legacySocket.connect());
      legacySocket.connState = SocketStates.open;

      final legacyData = json.encode({
        'topic': topic,
        'event': event.eventName(),
        'payload': payload,
        'ref': ref,
      });

      final message = Message(
        topic: topic,
        payload: payload,
        event: event,
        ref: ref,
      );
      legacySocket.push(message);

      verify(
        () => legacySink.add(captureAny(that: equals(legacyData))),
      ).called(1);
    });

    test('uses a custom encode override when provided', () {
      final customChannel = MockIOWebSocketChannel();
      final customSink = MockWebSocketSink();
      when(() => customChannel.sink).thenReturn(customSink);
      when(() => customChannel.ready).thenAnswer((_) => Future.value());
      when(() => customSink.close()).thenAnswer((_) => Future.value());

      final customSocket = RealtimeClient(
        socketEndpoint,
        transport: (url, headers) => customChannel,
        encode: (_) => 'custom-frame',
      );
      unawaited(customSocket.connect());
      customSocket.connState = SocketStates.open;

      customSocket.push(
        Message(topic: topic, payload: payload, event: event, ref: ref),
      );

      verify(
        () => customSink.add(captureAny(that: equals('custom-frame'))),
      ).called(1);
    });
  });

  group('onConnMessage', () {
    test('drops a malformed frame without throwing', () {
      final socket = RealtimeClient(socketEndpoint);
      expect(
        () => socket.onConnMessage('{"not": "an array"}'),
        returnsNormally,
      );
    });

    test('dispatches a received binary broadcast to onBroadcast', () {
      final socket = RealtimeClient(socketEndpoint);
      final channel = socket.channel('room');

      Map<String, dynamic>? received;
      channel.onBroadcast(
        event: 'cursor',
        callback: (payload) => received = payload,
      );

      final topic = utf8.encode('realtime:room');
      final event = utf8.encode('cursor');
      final payload = utf8.encode(json.encode({'x': 1}));
      final frame = Uint8List.fromList([
        4, // kind: userBroadcast
        topic.length,
        event.length,
        0, // metadata size
        1, // payload encoding: json
        ...topic,
        ...event,
        ...payload,
      ]);

      socket.onConnMessage(frame);

      expect(received, {
        'type': 'broadcast',
        'event': 'cursor',
        'payload': {'x': 1},
      });
    });

    test(
      'decodes a legacy object frame and dispatches it when version is v1',
      () {
        final socket = RealtimeClient(
          socketEndpoint,
          version: RealtimeProtocolVersion.v1,
        );
        final channel = socket.channel('room');

        Map<String, dynamic>? received;
        channel.onBroadcast(
          event: 'cursor',
          callback: (payload) => received = payload,
        );

        socket.onConnMessage(
          json.encode({
            'topic': 'realtime:room',
            'event': 'broadcast',
            'payload': {
              'type': 'broadcast',
              'event': 'cursor',
              'payload': {'x': 1},
            },
            'ref': null,
          }),
        );

        expect(received, {
          'type': 'broadcast',
          'event': 'cursor',
          'payload': {'x': 1},
        });
      },
    );
  });

  group('makeRef', () {
    late RealtimeClient socket;
    setUp(() {
      socket = RealtimeClient(socketEndpoint);
    });

    tearDown(() async {
      await socket.disconnect();
    });

    test('returns next message ref', () {
      expect(socket.ref, 0);
      expect(socket.makeRef(), '1');
      expect(socket.ref, 1);
      expect(socket.makeRef(), '2');
      expect(socket.ref, 2);
    });

    test('restarts for overflow', () {
      socket.ref = 9223372036854775807;
      expect(socket.makeRef(), '0');
      expect(socket.ref, 0);
    });
  });

  group('setAuth', () {
    final token = generateJwt();
    final updateJoinPayload = {
      'access_token': token,
      'version': Constants.defaultHeaders['X-Client-Info'],
    };
    final pushPayload = {'access_token': token};

    test(
      "sets access token, updates channels' join payload, and pushes token to channels",
      () async {
        final mockedChannel1 = MockChannel();
        when(() => mockedChannel1.joinedOnce).thenReturn(true);
        when(() => mockedChannel1.isJoined).thenReturn(true);
        when(
          () => mockedChannel1.push(ChannelEvents.accessToken, pushPayload),
        ).thenReturn(MockPush());

        final mockedChannel2 = MockChannel();
        when(() => mockedChannel2.joinedOnce).thenReturn(true);
        when(() => mockedChannel2.isJoined).thenReturn(true);
        when(
          () => mockedChannel2.push(ChannelEvents.accessToken, pushPayload),
        ).thenReturn(MockPush());

        const tTopic1 = 'topic-1';
        const tTopic2 = 'topic-2';

        final mockedSocket = SocketWithMockedChannel(socketEndpoint);
        mockedSocket.mockedChannelLooker.addAll({
          tTopic1: mockedChannel1,
          tTopic2: mockedChannel2,
        });

        final channel1 = mockedSocket.channel(tTopic1);
        final channel2 = mockedSocket.channel(tTopic2);

        await mockedSocket.setAuth(token);

        expect(mockedSocket.accessToken, token);

        verify(() => channel1.updateJoinPayload(updateJoinPayload)).called(1);
        verify(() => channel2.updateJoinPayload(updateJoinPayload)).called(1);
        verify(
          () => channel1.push(ChannelEvents.accessToken, pushPayload),
        ).called(1);
        verify(
          () => channel2.push(ChannelEvents.accessToken, pushPayload),
        ).called(1);
      },
    );

    test(
      "sets access token, updates channels' join payload, and pushes token to channels if is not a jwt",
      () async {
        final mockedChannel1 = MockChannel();
        final mockedChannel2 = MockChannel();
        final mockedChannel3 = MockChannel();

        when(() => mockedChannel1.joinedOnce).thenReturn(true);
        when(() => mockedChannel1.isJoined).thenReturn(true);
        when(
          () => mockedChannel1.push(ChannelEvents.accessToken, any()),
        ).thenReturn(MockPush());

        when(() => mockedChannel2.joinedOnce).thenReturn(false);
        when(() => mockedChannel2.isJoined).thenReturn(false);
        when(
          () => mockedChannel2.push(ChannelEvents.accessToken, any()),
        ).thenReturn(MockPush());

        when(() => mockedChannel3.joinedOnce).thenReturn(true);
        when(() => mockedChannel3.isJoined).thenReturn(true);
        when(
          () => mockedChannel3.push(ChannelEvents.accessToken, any()),
        ).thenReturn(MockPush());

        const tTopic1 = 'test-topic1';
        const tTopic2 = 'test-topic2';
        const tTopic3 = 'test-topic3';

        final mockedSocket = SocketWithMockedChannel(socketEndpoint);
        mockedSocket.mockedChannelLooker.addAll({
          tTopic1: mockedChannel1,
          tTopic2: mockedChannel2,
          tTopic3: mockedChannel3,
        });

        final channel1 = mockedSocket.channel(tTopic1);
        final channel2 = mockedSocket.channel(tTopic2);
        final channel3 = mockedSocket.channel(tTopic3);

        const authToken = 'sb-key';
        final expectedPushPayload = {'access_token': authToken};
        final expectedUpdateJoinPayload = {
          'access_token': authToken,
          'version': Constants.defaultHeaders['X-Client-Info'],
        };

        await mockedSocket.setAuth(authToken);

        expect(mockedSocket.accessToken, authToken);

        verify(
          () => channel1.updateJoinPayload(expectedUpdateJoinPayload),
        ).called(1);
        verify(
          () => channel2.updateJoinPayload(expectedUpdateJoinPayload),
        ).called(1);
        verify(
          () => channel3.updateJoinPayload(expectedUpdateJoinPayload),
        ).called(1);

        verify(
          () => channel1.push(ChannelEvents.accessToken, expectedPushPayload),
        ).called(1);
        verifyNever(
          () => channel2.push(ChannelEvents.accessToken, expectedPushPayload),
        );
        verify(
          () => channel3.push(ChannelEvents.accessToken, expectedPushPayload),
        ).called(1);
      },
    );
  });

  group('sendHeartbeat', () {
    IOWebSocketChannel mockedSocketChannel;
    late RealtimeClient mockedSocket;
    late WebSocketSink mockedSink;
    final data = json.encode([null, '1', 'phoenix', 'heartbeat', {}]);

    setUp(() {
      mockedSocketChannel = MockIOWebSocketChannel();
      mockedSocket = RealtimeClient(
        socketEndpoint,
        transport: (url, headers) {
          return mockedSocketChannel;
        },
      );
      mockedSink = MockWebSocketSink();

      when(() => mockedSocketChannel.sink).thenReturn(mockedSink);
      when(() => mockedSink.close()).thenAnswer((_) => Future.value());
      when(() => mockedSocketChannel.ready).thenAnswer((_) => Future.value());

      unawaited(mockedSocket.connect());
    });

    //! Unimplemented Test: closes socket when heartbeat is not ack'd within heartbeat window

    test('pushes heartbeat data when connected', () async {
      mockedSocket.connState = SocketStates.open;

      await mockedSocket.sendHeartbeat();

      verify(() => mockedSink.add(captureAny(that: equals(data)))).called(1);
    });

    test('no ops when not connected', () async {
      mockedSocket.connState = SocketStates.connecting;

      await mockedSocket.sendHeartbeat();
      verifyNever(() => mockedSink.add(any()));
    });
  });

  group('connect/disconnect race condition', () {
    test(
      'connect does not crash if disconnect nullifies connection during await ready',
      () async {
        final readyCompleter = Completer<void>();
        final mockedSocketChannel = MockIOWebSocketChannel();
        final mockedSink = MockWebSocketSink();

        when(
          () => mockedSocketChannel.ready,
        ).thenAnswer((_) => readyCompleter.future);
        when(() => mockedSocketChannel.sink).thenReturn(mockedSink);
        when(
          () => mockedSink.close(any(), any()),
        ).thenAnswer((_) => Future.value());
        when(() => mockedSink.close()).thenAnswer((_) => Future.value());

        final socket = RealtimeClient(
          socketEndpoint,
          transport: (url, headers) => mockedSocketChannel,
        );

        // Start connect — it will suspend at await ready
        final connectFuture = socket.connect();

        // Start disconnect (also suspends on ready since state is connecting)
        final disconnectFuture = socket.disconnect();

        // Now complete the ready future — both connect and disconnect can proceed
        readyCompleter.complete();
        await disconnectFuture;
        await connectFuture;

        // Should NOT have transitioned to open because disconnect nullified connection
        expect(socket.connState, isNot(SocketStates.open));
        expect(socket.conn, isNull);
      },
    );

    test(
      'connect bails out when connState changes during await ready',
      () async {
        final readyCompleter = Completer<void>();
        final mockedSocketChannel = MockIOWebSocketChannel();
        final mockedSink = MockWebSocketSink();

        when(
          () => mockedSocketChannel.ready,
        ).thenAnswer((_) => readyCompleter.future);
        when(() => mockedSocketChannel.sink).thenReturn(mockedSink);
        when(
          () => mockedSink.close(any(), any()),
        ).thenAnswer((_) => Future.value());
        when(() => mockedSink.close()).thenAnswer((_) => Future.value());

        final socket = RealtimeClient(
          socketEndpoint,
          transport: (url, headers) => mockedSocketChannel,
        );

        // Start connect
        final connectFuture = socket.connect();

        // Start disconnect — also awaits ready
        final disconnectFuture = socket.disconnect();

        // Complete ready — both proceed
        readyCompleter.complete();
        await disconnectFuture;
        await connectFuture;

        expect(socket.connState, isNot(SocketStates.open));
      },
    );

    test('rapid connect-disconnect-connect cycle does not crash', () async {
      final readyCompleter1 = Completer<void>();
      final mockedSocketChannel1 = MockIOWebSocketChannel();
      final mockedSink1 = MockWebSocketSink();

      when(
        () => mockedSocketChannel1.ready,
      ).thenAnswer((_) => readyCompleter1.future);
      when(() => mockedSocketChannel1.sink).thenReturn(mockedSink1);
      when(
        () => mockedSink1.close(any(), any()),
      ).thenAnswer((_) => Future.value());
      when(() => mockedSink1.close()).thenAnswer((_) => Future.value());

      final readyCompleter2 = Completer<void>();
      final mockedSocketChannel2 = MockIOWebSocketChannel();
      final mockedSink2 = MockWebSocketSink();
      final streamController2 = StreamController<dynamic>.broadcast();

      when(
        () => mockedSocketChannel2.ready,
      ).thenAnswer((_) => readyCompleter2.future);
      when(() => mockedSocketChannel2.sink).thenReturn(mockedSink2);
      when(
        () => mockedSocketChannel2.stream,
      ).thenAnswer((_) => streamController2.stream);
      when(
        () => mockedSink2.close(any(), any()),
      ).thenAnswer((_) => Future.value());
      when(() => mockedSink2.close()).thenAnswer((_) => Future.value());

      var callCount = 0;
      final socket = RealtimeClient(
        socketEndpoint,
        transport: (url, headers) {
          callCount++;
          if (callCount == 1) return mockedSocketChannel1;
          return mockedSocketChannel2;
        },
      );

      // First connect — suspends at await ready
      final connectFuture1 = socket.connect();

      // Start disconnect (also suspends on ready)
      final disconnectFuture = socket.disconnect();

      // Complete the first ready — both proceed, connect bails out
      readyCompleter1.complete();
      await disconnectFuture;
      await connectFuture1;

      // Second connect with a fresh mock
      readyCompleter2.complete();
      await socket.connect();

      expect(socket.connState, SocketStates.open);
      expect(socket.conn, mockedSocketChannel2);

      await socket.disconnect();
      await streamController2.close();
    });
  });
}
