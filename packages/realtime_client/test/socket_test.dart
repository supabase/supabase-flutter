import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mocktail/mocktail.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/constants.dart';
import 'package:realtime_client/src/message.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'socket_test_stubs.dart';

typedef WebSocketChannelClosure = WebSocketChannel Function(
  String url,
  Map<String, String> headers,
);

/// Generate a JWT token for testing purposes
///
/// [exp] in seconds since Epoch
String generateJwt([int? exp]) {
  final header = {'alg': 'HS256', 'typ': 'JWT'};

  final now = DateTime.now();
  final expiry = exp ??
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
  const int int64MaxValue = 9223372036854775807;

  const socketEndpoint = 'wss://localhost:0/';

  late HttpServer mockServer;

  setUp(() async {
    mockServer = await HttpServer.bind('localhost', 0);
    mockServer.transform(WebSocketTransformer()).listen((webSocket) {
      final channel = IOWebSocketChannel(webSocket);
      channel.stream.listen((request) {
        channel.sink.add(request);
      });
    });
  });

  tearDown(() async {
    await mockServer.close();
  });

  group('constructor', () {
    test('sets defaults', () async {
      final socket =
          RealtimeClient('wss://example.com/socket', params: {'apikey': '123'});
      expect(socket.channels.length, 0);
      expect(socket.sendBuffer.length, 0);
      expect(socket.ref, 0);
      expect(socket.endPoint, 'wss://example.com/socket/websocket');
      expect(socket.stateChangeCallbacks, {
        'open': [],
        'close': [],
        'error': [],
        'message': [],
      });
      expect(socket.timeout, const Duration(milliseconds: 10000));
      expect(socket.longpollerTimeout, 20000);
      expect(socket.heartbeatIntervalMs, 30000);
      expect(
        socket.logger is void Function(
          String? kind,
          String? msg,
          dynamic data,
        ),
        false,
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
        longpollerTimeout: 50000,
        heartbeatIntervalMs: 60000,
        // ignore: avoid_print
        logger: (kind, msg, data) => print('[$kind] $msg $data'),
        headers: {'X-Client-Info': 'supabase-dart/0.0.0'},
      );
      expect(socket.channels.length, 0);
      expect(socket.sendBuffer.length, 0);
      expect(socket.ref, 0);
      expect(socket.endPoint, 'wss://example.com/socket/websocket');
      expect(socket.stateChangeCallbacks, {
        'open': [],
        'close': [],
        'error': [],
        'message': [],
      });
      expect(socket.timeout, const Duration(milliseconds: 40000));
      expect(socket.longpollerTimeout, 50000);
      expect(socket.heartbeatIntervalMs, 60000);
      expect(
        socket.logger is void Function(
          String? kind,
          String? msg,
          dynamic data,
        ),
        true,
      );
      expect(socket.headers['X-Client-Info'], 'supabase-dart/0.0.0');
    });
  });

  group('endpointURL', () {
    test('returns endpoint for given full url', () {
      final socket = RealtimeClient('wss://example.org/chat');
      expect(
        socket.endPointURL,
        'wss://example.org/chat/websocket?vsn=1.0.0',
      );
    });

    test('returns endpoint with parameters', () {
      final socket =
          RealtimeClient('ws://example.org/chat', params: {'foo': 'bar'});
      expect(
        socket.endPointURL,
        'ws://example.org/chat/websocket?foo=bar&vsn=1.0.0',
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
        'ws://example.org/chat/websocket?apikey=123456789&vsn=1.0.0',
      );
    });
  });

  group('connect with Websocket', () {
    late RealtimeClient socket;

    setUp(() {
      socket = RealtimeClient('ws://localhost:${mockServer.port}');
    });

    tearDown(() {
      socket.disconnect();
    });

    test('establishes websocket connection with endpoint', () {
      socket.connect();

      final conn = socket.conn;

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

      socket.connect();
      await Future.delayed(const Duration(milliseconds: 200));
      expect(opens, 1);

      await socket.sendHeartbeat();
      // need to wait for event to trigger
      await Future.delayed(const Duration(seconds: 1));
      expect(lastMsg['event'], 'heartbeat');

      socket.disconnect();
      await Future.delayed(const Duration(seconds: 1));
      expect(closes, 1);
    });

    test('sets callback for errors', () {
      dynamic lastErr;
      final RealtimeClient erroneousSocket = RealtimeClient('badurl')
        ..onError((e) {
          lastErr = e;
        });

      erroneousSocket.connect();

      expect(lastErr, isA<WebSocketException>());
    });

    test('is idempotent', () {
      socket.connect();
      final conn = socket.conn;
      socket.connect();
      expect(socket.conn, conn);
    });
  });

  group('disconnect', () {
    late RealtimeClient socket;
    setUp(() {
      socket = RealtimeClient('ws://localhost:${mockServer.port}');
    });

    tearDown(() {
      socket.disconnect();
    });

    test('removes existing connection', () async {
      await socket.connect();
      await socket.disconnect();

      expect(socket.conn, null);
    });

    test('calls callback', () async {
      int closes = 0;
      socket.connect();
      socket.disconnect();
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
      when(() => mockedSink.close(any(), any()))
          .thenAnswer((_) => Future.value());

      const tCode = 12;
      const tReason = 'reason';

      mockedSocket.connect();
      mockedSocket.connState = SocketStates.open;
      await Future.delayed(const Duration(milliseconds: 200));
      mockedSocket.disconnect(code: tCode, reason: tReason);
      await Future.delayed(const Duration(milliseconds: 200));

      verify(
        () => mockedSink.close(
          captureAny(that: equals(tCode)),
          captureAny(that: equals(tReason)),
        ),
      ).called(1);
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

    tearDown(() {
      socket.disconnect();
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
          'presence': {'key': ''},
          'private': false,
        }
      });
    });

    test('adds channel to sockets channels list', () {
      expect(socket.channels.length, 0);

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
      mockedSocket.mockedChannelLooker.addAll(<String, RealtimeChannel>{
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
    final jsonData = json.encode({
      'topic': topic,
      'event': event.eventName(),
      'payload': payload,
      'ref': ref
    });

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
      mockedSocket.connect();
      mockedSocket.connState = SocketStates.open;

      final message =
          Message(topic: topic, payload: payload, event: event, ref: ref);
      mockedSocket.push(message);

      verify(() => mockedSink.add(captureAny(that: equals(jsonData))))
          .called(1);
    });

    test('buffers data when not connected', () async {
      mockedSocket.connect();
      mockedSocket.connState = SocketStates.connecting;

      expect(mockedSocket.sendBuffer.length, 0);

      final message =
          Message(topic: topic, payload: payload, event: event, ref: ref);
      mockedSocket.push(message);

      verifyNever(() => mockedSink.add(any()));
      expect(mockedSocket.sendBuffer.length, 1);

      final callback = mockedSocket.sendBuffer[0];
      callback();
      verify(() => mockedSink.add(captureAny(that: equals(jsonData))))
          .called(1);
    });
  });

  group('makeRef', () {
    late RealtimeClient socket;
    setUp(() {
      socket = RealtimeClient(socketEndpoint);
    });

    tearDown(() {
      socket.disconnect();
    });

    test('returns next message ref', () {
      expect(socket.ref, 0);
      expect(socket.makeRef(), '1');
      expect(socket.ref, 1);
      expect(socket.makeRef(), '2');
      expect(socket.ref, 2);
    });

    test('restarts for overflow', () {
      socket.ref = int64MaxValue;
      expect(socket.makeRef(), '0');
      expect(socket.ref, 0);
    });
  });

  group('setAuth', () {
    final token = generateJwt();
    final updateJoinPayload = {'access_token': token};
    final pushPayload = {'access_token': token};

    test(
        "sets access token, updates channels' join payload, and pushes token to channels",
        () async {
      final mockedChannel1 = MockChannel();
      when(() => mockedChannel1.joinedOnce).thenReturn(true);
      when(() => mockedChannel1.isJoined).thenReturn(true);
      when(() => mockedChannel1.push(ChannelEvents.accessToken, pushPayload))
          .thenReturn(MockPush());

      final mockedChannel2 = MockChannel();
      when(() => mockedChannel2.joinedOnce).thenReturn(true);
      when(() => mockedChannel2.isJoined).thenReturn(true);
      when(() => mockedChannel2.push(ChannelEvents.accessToken, pushPayload))
          .thenReturn(MockPush());

      const tTopic1 = 'topic-1';
      const tTopic2 = 'topic-2';

      final mockedSocket = SocketWithMockedChannel(socketEndpoint);
      mockedSocket.mockedChannelLooker.addAll(<String, RealtimeChannel>{
        tTopic1: mockedChannel1,
        tTopic2: mockedChannel2,
      });

      final channel1 = mockedSocket.channel(tTopic1);
      final channel2 = mockedSocket.channel(tTopic2);

      await mockedSocket.setAuth(token);

      expect(mockedSocket.accessToken, token);

      verify(() => channel1.updateJoinPayload(updateJoinPayload)).called(1);
      verify(() => channel2.updateJoinPayload(updateJoinPayload)).called(1);
      verify(() => channel1.push(ChannelEvents.accessToken, pushPayload))
          .called(1);
      verify(() => channel2.push(ChannelEvents.accessToken, pushPayload))
          .called(1);
    });

    test(
        "sets access token, updates channels' join payload, and pushes token to channels if is not a jwt",
        () async {
      final mockedChannel1 = MockChannel();
      final mockedChannel2 = MockChannel();
      final mockedChannel3 = MockChannel();

      when(() => mockedChannel1.joinedOnce).thenReturn(true);
      when(() => mockedChannel1.isJoined).thenReturn(true);
      when(() => mockedChannel1.push(ChannelEvents.accessToken, any()))
          .thenReturn(MockPush());

      when(() => mockedChannel2.joinedOnce).thenReturn(false);
      when(() => mockedChannel2.isJoined).thenReturn(false);
      when(() => mockedChannel2.push(ChannelEvents.accessToken, any()))
          .thenReturn(MockPush());

      when(() => mockedChannel3.joinedOnce).thenReturn(true);
      when(() => mockedChannel3.isJoined).thenReturn(true);
      when(() => mockedChannel3.push(ChannelEvents.accessToken, any()))
          .thenReturn(MockPush());

      const tTopic1 = 'test-topic1';
      const tTopic2 = 'test-topic2';
      const tTopic3 = 'test-topic3';

      final mockedSocket = SocketWithMockedChannel(socketEndpoint);
      mockedSocket.mockedChannelLooker.addAll(<String, RealtimeChannel>{
        tTopic1: mockedChannel1,
        tTopic2: mockedChannel2,
        tTopic3: mockedChannel3,
      });

      final channel1 = mockedSocket.channel(tTopic1);
      final channel2 = mockedSocket.channel(tTopic2);
      final channel3 = mockedSocket.channel(tTopic3);

      const token = 'sb-key';
      final pushPayload = {'access_token': token};
      final updateJoinPayload = {'access_token': token};

      await mockedSocket.setAuth(token);

      expect(mockedSocket.accessToken, token);

      verify(() => channel1.updateJoinPayload(updateJoinPayload)).called(1);
      verify(() => channel2.updateJoinPayload(updateJoinPayload)).called(1);
      verify(() => channel3.updateJoinPayload(updateJoinPayload)).called(1);

      verify(() => channel1.push(ChannelEvents.accessToken, pushPayload))
          .called(1);
      verifyNever(() => channel2.push(ChannelEvents.accessToken, pushPayload));
      verify(() => channel3.push(ChannelEvents.accessToken, pushPayload))
          .called(1);
    });
  });

  group('sendHeartbeat', () {
    IOWebSocketChannel mockedSocketChannel;
    late RealtimeClient mockedSocket;
    late WebSocketSink mockedSink;
    final data = json.encode({
      'topic': 'phoenix',
      'event': 'heartbeat',
      'payload': {},
      'ref': '1',
    });

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

      mockedSocket.connect();
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
}
