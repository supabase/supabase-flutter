import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_realtime/src/constants.dart';
import 'package:supabase_realtime/src/message.dart';
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
        parameters: {'apikey': '123'},
      );
      expect(socket.channels, isEmpty);
      expect(socket.sendBuffer, isEmpty);
      expect(socket.ref, 0);
      expect(socket.endpoint, 'wss://example.com/socket/websocket');
      expect(socket.timeout, const Duration(milliseconds: 10000));
      expect(
        socket.heartbeatInterval,
        RealtimeConstants.defaultHeartbeatInterval,
      );
      expect(
        socket.logger
            is void Function(
              String? kind,
              String? message,
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
        heartbeatInterval: const Duration(seconds: 60),
        // ignore: avoid_print
        logger: (kind, message, data) => print('[$kind] $message $data'),
        headers: {'X-Client-Info': 'supabase-dart/0.0.0'},
      );
      expect(socket.channels, isEmpty);
      expect(socket.sendBuffer, isEmpty);
      expect(socket.ref, 0);
      expect(socket.endpoint, 'wss://example.com/socket/websocket');
      expect(socket.timeout, const Duration(milliseconds: 40000));
      expect(socket.heartbeatInterval, const Duration(seconds: 60));
      expect(
        socket.logger
            is void Function(
              String? kind,
              String? message,
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
        socket.endpointUrl,
        'wss://example.org/chat/websocket?vsn=2.0.0',
      );
    });

    test('returns endpoint with parameters', () {
      final socket = RealtimeClient(
        'ws://example.org/chat',
        parameters: {'foo': 'bar'},
      );
      expect(
        socket.endpointUrl,
        'ws://example.org/chat/websocket?foo=bar&vsn=2.0.0',
      );
    });

    test('returns endpoint with apikey', () {
      final socket = RealtimeClient(
        'ws://example.org/chat',
        parameters: {
          'apikey': '123456789',
        },
      );
      expect(
        socket.endpointUrl,
        'ws://example.org/chat/websocket?apikey=123456789&vsn=2.0.0',
      );
    });

    test('uses the legacy vsn when version is v1', () {
      final socket = RealtimeClient(
        'wss://example.org/chat',
        version: RealtimeProtocolVersion.v1,
      );
      expect(
        socket.endpointUrl,
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
      final connectFuture = socket.connect();
      expect(socket.connectionState, SocketState.connecting);

      final connection = socket.connection;

      await connectFuture;
      expect(socket.connectionState, SocketState.open);

      expect(connection, isA<IOWebSocketChannel>());
      //! Not verifying connection url
    });

    test('emits connection state events on the streams', () async {
      final statuses = <RealtimeConnectionStatus>[];
      socket.onStatusChange.listen((change) {
        statuses.add(change.status);
      });
      late dynamic lastMessage;
      socket.onMessage.listen((message) {
        lastMessage = message;
      });

      await socket.connect();
      await Future.delayed(const Duration(milliseconds: 200));
      expect(statuses, [RealtimeConnectionStatus.open]);

      await socket.sendHeartbeat();
      // need to wait for event to trigger
      await Future.delayed(const Duration(seconds: 1));
      expect(lastMessage['event'], 'heartbeat');

      await socket.disconnect();
      await Future.delayed(const Duration(seconds: 1));
      expect(statuses, [
        RealtimeConnectionStatus.open,
        RealtimeConnectionStatus.closed,
      ]);
    });

    test('emits errors on the onStatusChange stream', () async {
      final RealtimeClient erroneousSocket = RealtimeClient('badurl');
      final errorFuture = erroneousSocket.onStatusChange.first;

      unawaited(erroneousSocket.connect());

      await expectLater(errorFuture, throwsA(isA<WebSocketException>()));
    });

    test('reports the close code and reason with the closed status', () async {
      final mockedSocketChannel = MockIOWebSocketChannel();
      final mockedSink = MockWebSocketSink();
      final streamController = StreamController<dynamic>();
      final mockedSocket = RealtimeClient(
        socketEndpoint,
        reconnectAfter: (tries) => const Duration(seconds: 100),
        transport: (url, headers) => mockedSocketChannel,
      );
      when(() => mockedSocketChannel.ready).thenAnswer((_) => Future.value());
      when(() => mockedSocketChannel.sink).thenReturn(mockedSink);
      when(
        () => mockedSocketChannel.stream,
      ).thenAnswer((_) => streamController.stream);
      when(() => mockedSocketChannel.closeCode).thenReturn(1011);
      when(() => mockedSocketChannel.closeReason).thenReturn('server error');
      when(() => mockedSink.close()).thenAnswer((_) => Future.value());

      final closed = mockedSocket.onStatusChange.firstWhere(
        (change) => change.status == RealtimeConnectionStatus.closed,
      );

      await mockedSocket.connect();
      await streamController.close();

      final change = await closed;
      expect(change.closeEvent?.code, 1011);
      expect(change.closeEvent?.reason, 'server error');

      await mockedSocket.disconnect();
    });

    test('is idempotent', () {
      unawaited(socket.connect());
      final connection = socket.connection;
      unawaited(socket.connect());
      expect(socket.connection, connection);
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

      expect(socket.connection, isNotNull);
      await socket.disconnect();

      expect(socket.connection, isNull);
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
      mockedSocket.connectionState = SocketState.open;
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
      expect(socket.connectionState, SocketState.open);
      await mockServer.close();
      await Future.delayed(const Duration(milliseconds: 200));
      expect(socket.connectionState, SocketState.closed);
      expect(socket.connection, isNotNull);

      final disconnectFuture = socket.disconnect();

      // `connectionState` stays `closed` during disconnect
      expect(socket.connectionState, SocketState.closed);
      await disconnectFuture;
      expect(socket.connectionState, SocketState.closed);
      expect(socket.connection, isNull);
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
        reconnectAfter: (tries) => const Duration(milliseconds: 20),
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
      expect(mockedSocket.connectionState, SocketState.closed);

      // The user disconnects explicitly while the socket is already closed.
      await mockedSocket.disconnect();

      // Wait past the reconnect delay; the scheduled reconnect must be
      // canceled.
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
        reconnectAfter: (tries) => const Duration(seconds: 100),
        transport: (url, headers) {
          connectCount++;
          return connectCount == 1 ? firstChannel : secondChannel;
        },
      );

      await mockedSocket.connect();
      expect(connectCount, 1);
      expect(mockedSocket.connectionState, SocketState.open);

      // Simulate the server dropping the connection.
      await firstController.close();
      await Future.delayed(const Duration(milliseconds: 5));
      expect(mockedSocket.connectionState, SocketState.closed);

      // A manual reconnect must open a fresh connection instead of being a
      // no-op because `connection` still references the dropped socket.
      await mockedSocket.connect();
      expect(
        connectCount,
        2,
        reason: 'manual connect() must reconnect after a drop',
      );
      expect(mockedSocket.connectionState, SocketState.open);

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
        reconnectAfter: (tries) {
          triesSeen.add(tries);
          return const Duration(milliseconds: 10);
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
      expect(mockedSocket.connectionState, SocketState.open);

      await mockedSocket.disconnect();
    });

    test('disconnecting an open connection', () async {
      await socket.connect();
      expect(socket.connectionState, SocketState.open);

      final disconnectFuture = socket.disconnect();

      // `connectionState` stays `closed` during disconnect
      expect(socket.connectionState, SocketState.disconnecting);
      await disconnectFuture;
      expect(socket.connectionState, SocketState.disconnected);
      expect(socket.connection, isNull);
    });

    test('does not throw when no connection', () {
      expect(() => socket.disconnect(), returnsNormally);
    });

    test('times out and finalizes disconnect when sink.close hangs', () async {
      final mockedSocketChannel = MockIOWebSocketChannel();
      final mockedSink = MockWebSocketSink();
      final streamController = StreamController<dynamic>.broadcast();
      final closeCompleter = Completer<void>();
      final mockedSocket = RealtimeClient(
        socketEndpoint,
        transport: (url, headers) => mockedSocketChannel,
      );
      var closeEvents = 0;
      mockedSocket.onStatusChange
          .where((change) => change.status == RealtimeConnectionStatus.closed)
          .listen((_) => closeEvents += 1);

      when(() => mockedSocketChannel.ready).thenAnswer((_) => Future.value());
      when(() => mockedSocketChannel.sink).thenReturn(mockedSink);
      when(
        () => mockedSocketChannel.stream,
      ).thenAnswer((_) => streamController.stream);
      when(() => mockedSink.close()).thenAnswer((_) => closeCompleter.future);

      await mockedSocket.connect();
      expect(mockedSocket.connectionState, SocketState.open);

      await mockedSocket.disconnect();
      // Wait for the async stream delivery of the close event.
      await Future<void>.delayed(Duration.zero);
      expect(mockedSocket.connectionState, SocketState.disconnected);
      expect(mockedSocket.connection, isNull);
      expect(closeEvents, 1);
      verify(() => mockedSink.close()).called(1);

      await streamController.close();
    });
  });

  //! Note: not checking connection states since it is based on an enum.

  group('channel', () {
    const tTopic = 'topic';
    const channelConfig = RealtimeChannelConfig();
    late RealtimeClient socket;
    setUp(() {
      socket = RealtimeClient(socketEndpoint);
    });

    tearDown(() async {
      await socket.disconnect();
    });

    test('returns channel with given topic and parameters', () {
      final channel = socket.channel(
        tTopic,
        channelConfig,
      );

      expect(channel.socket, socket);
      expect(channel.topic, 'realtime:topic');
      expect(channel.parameters, {
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
        channelConfig,
      );

      expect(socket.channels, hasLength(1));

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
      expect(mockedSocket.channels, hasLength(1));

      final foundChannel = mockedSocket.channels[0];
      expect(foundChannel, channel2);
    });

    test('keeps the other channels when none of them have joined', () {
      // Channels that have never subscribed all share the empty join ref, so
      // matching on it removed every one of them at once.
      final socket = RealtimeClient(socketEndpoint);
      final channel1 = socket.channel('topic-1');
      socket.channel('topic-2');
      socket.channel('topic-3');

      socket.remove(channel1);

      expect(
        socket.channels.map((channel) => channel.topic),
        ['realtime:topic-2', 'realtime:topic-3'],
      );
    });

    test('removes only the given channel when topics are duplicated', () {
      final socket = RealtimeClient(socketEndpoint);
      final channel1 = socket.channel('topic');
      final channel2 = socket.channel('topic');

      socket.remove(channel1);

      expect(socket.channels, [channel2]);
    });
  });

  group('deferred disconnect', () {
    test('defaults to twice the heartbeat interval', () {
      final socket = RealtimeClient(socketEndpoint);
      expect(
        socket.disconnectOnEmptyChannelsAfter,
        RealtimeConstants.defaultHeartbeatInterval * 2,
      );

      final customSocket = RealtimeClient(
        socketEndpoint,
        heartbeatInterval: const Duration(seconds: 5),
      );
      expect(
        customSocket.disconnectOnEmptyChannelsAfter,
        const Duration(milliseconds: 10000),
      );

      final explicitSocket = RealtimeClient(
        socketEndpoint,
        disconnectOnEmptyChannelsAfter: const Duration(milliseconds: 1234),
      );
      expect(
        explicitSocket.disconnectOnEmptyChannelsAfter,
        const Duration(milliseconds: 1234),
      );
    });

    test(
      'does not disconnect immediately when the last channel is removed',
      () async {
        final socket = RealtimeClient(
          'ws://localhost:${mockServer.port}',
          disconnectOnEmptyChannelsAfter: const Duration(milliseconds: 200),
        );
        await socket.connect();
        expect(socket.isConnected, isTrue);

        final channel = socket.channel('topic');
        socket.remove(channel);

        expect(socket.isConnected, isTrue);
        await socket.disconnect();
      },
    );

    test('disconnects after the delay when channels stay empty', () async {
      final socket = RealtimeClient(
        'ws://localhost:${mockServer.port}',
        disconnectOnEmptyChannelsAfter: const Duration(milliseconds: 200),
      );
      await socket.connect();

      final channel = socket.channel('topic');
      socket.remove(channel);

      expect(socket.isConnected, isTrue);
      await Future.delayed(const Duration(milliseconds: 400));
      expect(socket.isConnected, isFalse);
    });

    test(
      'cancels the pending disconnect when a new channel is created',
      () async {
        final socket = RealtimeClient(
          'ws://localhost:${mockServer.port}',
          disconnectOnEmptyChannelsAfter: const Duration(milliseconds: 200),
        );
        await socket.connect();

        final channel = socket.channel('topic');
        socket.remove(channel);
        socket.channel('new-topic');

        await Future.delayed(const Duration(milliseconds: 400));
        expect(socket.isConnected, isTrue);
        await socket.disconnect();
      },
    );

    test(
      'disconnects immediately when disconnectOnEmptyChannelsAfter is zero',
      () async {
        final socket = RealtimeClient(
          'ws://localhost:${mockServer.port}',
          disconnectOnEmptyChannelsAfter: Duration.zero,
        );
        await socket.connect();

        final channel = socket.channel('topic');
        socket.remove(channel);

        await Future.delayed(const Duration(milliseconds: 100));
        expect(socket.isConnected, isFalse);
      },
    );

    test('disconnect cancels a pending deferred disconnect', () async {
      final socket = RealtimeClient(
        'ws://localhost:${mockServer.port}',
        disconnectOnEmptyChannelsAfter: const Duration(milliseconds: 200),
      );
      await socket.connect();

      final channel = socket.channel('topic');
      socket.remove(channel);
      await socket.disconnect();

      await socket.connect();
      socket.channel('topic-2');
      await Future.delayed(const Duration(milliseconds: 400));
      expect(socket.isConnected, isTrue);
      await socket.disconnect();
    });

    test(
      'removeChannel schedules a deferred disconnect for the last channel',
      () async {
        final socket = RealtimeClient(
          'ws://localhost:${mockServer.port}',
          disconnectOnEmptyChannelsAfter: const Duration(milliseconds: 200),
        );
        await socket.connect();

        final channel = socket.channel('topic');
        await socket.removeChannel(channel);

        expect(socket.isConnected, isTrue);
        await Future.delayed(const Duration(milliseconds: 400));
        expect(socket.isConnected, isFalse);
      },
    );

    test('channel.unsubscribe schedules a deferred disconnect', () async {
      final socket = RealtimeClient(
        'ws://localhost:${mockServer.port}',
        disconnectOnEmptyChannelsAfter: const Duration(milliseconds: 200),
      );
      await socket.connect();

      final channel = socket.channel('topic');
      await channel.unsubscribe();

      expect(socket.isConnected, isTrue);
      await Future.delayed(const Duration(milliseconds: 400));
      expect(socket.isConnected, isFalse);
    });

    test('removeAllChannels disconnects immediately', () async {
      final socket = RealtimeClient(
        'ws://localhost:${mockServer.port}',
        disconnectOnEmptyChannelsAfter: const Duration(milliseconds: 10000),
      );
      await socket.connect();
      expect(socket.isConnected, isTrue);

      socket.channel('channel-1');
      socket.channel('channel-2');

      await socket.removeAllChannels();
      expect(socket.isConnected, isFalse);
    });
  });

  group('push', () {
    const topic = 'topic';
    const event = ChannelEvent.join;
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
      mockedSocket.connectionState = SocketState.open;

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
      mockedSocket.connectionState = SocketState.connecting;

      expect(mockedSocket.sendBuffer, isEmpty);

      final message = Message(
        topic: topic,
        payload: payload,
        event: event,
        ref: ref,
      );
      mockedSocket.push(message);

      verifyNever(() => mockedSink.add(any()));
      expect(mockedSocket.sendBuffer, hasLength(1));

      final callback = mockedSocket.sendBuffer[0];
      callback();
      verify(
        () => mockedSink.add(captureAny(that: equals(jsonData))),
      ).called(1);
    });

    test('sends a broadcast with a binary payload as a binary frame', () {
      unawaited(mockedSocket.connect());
      mockedSocket.connectionState = SocketState.open;

      final binaryPayload = Uint8List.fromList([1, 2, 3]);
      final message = Message(
        topic: 'realtime:room',
        event: ChannelEvent.broadcast,
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
      legacySocket.connectionState = SocketState.open;

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
      customSocket.connectionState = SocketState.open;

      customSocket.push(
        Message(topic: topic, payload: payload, event: event, ref: ref),
      );

      verify(
        () => customSink.add(captureAny(that: equals('custom-frame'))),
      ).called(1);
    });
  });

  group('onConnectionMessage', () {
    test('drops a malformed frame without throwing', () {
      final socket = RealtimeClient(socketEndpoint);
      expect(
        () => socket.onConnectionMessage('{"not": "an array"}'),
        returnsNormally,
      );
    });

    test('dispatches a received binary broadcast to onBroadcast', () async {
      final socket = RealtimeClient(socketEndpoint);
      final channel = socket.channel('room');

      Map<String, dynamic>? received;
      channel.onBroadcast(event: 'cursor').listen((payload) {
        received = payload;
      });

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

      socket.onConnectionMessage(frame);
      // Wait for the async stream delivery of the broadcast event.
      await Future<void>.delayed(Duration.zero);

      expect(received, {
        'type': 'broadcast',
        'event': 'cursor',
        'payload': {'x': 1},
      });
    });

    test(
      'decodes a legacy object frame and dispatches it when version is v1',
      () async {
        final socket = RealtimeClient(
          socketEndpoint,
          version: RealtimeProtocolVersion.v1,
        );
        final channel = socket.channel('room');

        Map<String, dynamic>? received;
        channel.onBroadcast(event: 'cursor').listen((payload) {
          received = payload;
        });

        socket.onConnectionMessage(
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
        // Wait for the async stream delivery of the broadcast event.
        await Future<void>.delayed(Duration.zero);

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

  group('setAccessToken', () {
    final token = generateJwt();
    final updateJoinPayload = {
      'access_token': token,
      'version': RealtimeConstants.defaultHeaders['X-Client-Info'],
    };
    final pushPayload = {'access_token': token};

    test(
      "sets access token, updates channels' join payload, and pushes token to "
      "channels",
      () async {
        final mockedChannel1 = MockChannel();
        when(() => mockedChannel1.joinedOnce).thenReturn(true);
        when(() => mockedChannel1.isJoined).thenReturn(true);
        when(
          () => mockedChannel1.push(ChannelEvent.accessToken, pushPayload),
        ).thenReturn(MockPush());

        final mockedChannel2 = MockChannel();
        when(() => mockedChannel2.joinedOnce).thenReturn(true);
        when(() => mockedChannel2.isJoined).thenReturn(true);
        when(
          () => mockedChannel2.push(ChannelEvent.accessToken, pushPayload),
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

        await mockedSocket.setAccessToken(token);

        expect(mockedSocket.accessToken, token);

        verify(() => channel1.updateJoinPayload(updateJoinPayload)).called(1);
        verify(() => channel2.updateJoinPayload(updateJoinPayload)).called(1);
        verify(
          () => channel1.push(ChannelEvent.accessToken, pushPayload),
        ).called(1);
        verify(
          () => channel2.push(ChannelEvent.accessToken, pushPayload),
        ).called(1);
      },
    );

    test(
      "sets access token, updates channels' join payload, and pushes token to "
      "channels if is not a jwt",
      () async {
        final mockedChannel1 = MockChannel();
        final mockedChannel2 = MockChannel();
        final mockedChannel3 = MockChannel();

        when(() => mockedChannel1.joinedOnce).thenReturn(true);
        when(() => mockedChannel1.isJoined).thenReturn(true);
        when(
          () => mockedChannel1.push(ChannelEvent.accessToken, any()),
        ).thenReturn(MockPush());

        when(() => mockedChannel2.joinedOnce).thenReturn(false);
        when(() => mockedChannel2.isJoined).thenReturn(false);
        when(
          () => mockedChannel2.push(ChannelEvent.accessToken, any()),
        ).thenReturn(MockPush());

        when(() => mockedChannel3.joinedOnce).thenReturn(true);
        when(() => mockedChannel3.isJoined).thenReturn(true);
        when(
          () => mockedChannel3.push(ChannelEvent.accessToken, any()),
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
          'version': RealtimeConstants.defaultHeaders['X-Client-Info'],
        };

        await mockedSocket.setAccessToken(authToken);

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
          () => channel1.push(ChannelEvent.accessToken, expectedPushPayload),
        ).called(1);
        verifyNever(
          () => channel2.push(ChannelEvent.accessToken, expectedPushPayload),
        );
        verify(
          () => channel3.push(ChannelEvent.accessToken, expectedPushPayload),
        ).called(1);
      },
    );
  });

  group('on connection open', () {
    test('rejoins only errored channels', () async {
      final mockedSocketChannel = MockIOWebSocketChannel();
      final mockedSink = MockWebSocketSink();
      final streamController = StreamController<dynamic>.broadcast();
      final erroredChannel = MockChannel();
      final healthyChannel = MockChannel();
      final socket = RealtimeClient(
        socketEndpoint,
        transport: (url, headers) => mockedSocketChannel,
      );
      var opens = 0;
      socket.onStatusChange
          .where((change) => change.status == RealtimeConnectionStatus.open)
          .listen((_) => opens += 1);

      when(() => mockedSocketChannel.ready).thenAnswer((_) => Future.value());
      when(() => mockedSocketChannel.sink).thenReturn(mockedSink);
      when(
        () => mockedSocketChannel.stream,
      ).thenAnswer((_) => streamController.stream);
      when(() => mockedSink.close()).thenAnswer((_) => Future.value());
      when(() => erroredChannel.isErrored).thenReturn(true);
      when(() => healthyChannel.isErrored).thenReturn(false);
      when(() => erroredChannel.rejoin()).thenReturn(null);

      socket.channels.addAll([erroredChannel, healthyChannel]);
      await socket.connect();

      verify(() => erroredChannel.rejoin()).called(1);
      verifyNever(() => healthyChannel.rejoin());
      // Wait for the async stream delivery of the open event.
      await Future<void>.delayed(Duration.zero);
      expect(opens, 1);
      expect(socket.connectionState, SocketState.open);

      await socket.disconnect();
      await streamController.close();
    });
  });

  group('access token on connect', () {
    test(
      'resolves the token and patches buffered join payloads before flushing',
      () async {
        final token = generateJwt();
        var tokenCallbackCalls = 0;

        final streamController = StreamController<dynamic>.broadcast();
        final readyCompleter = Completer<void>();
        final capturedMessages = <String>[];
        final joinSent = Completer<Map<dynamic, dynamic>>();

        final mockedChannel = MockIOWebSocketChannel();
        final mockedSink = MockWebSocketSink();
        when(() => mockedChannel.sink).thenReturn(mockedSink);
        when(
          () => mockedChannel.ready,
        ).thenAnswer((_) => readyCompleter.future);
        when(
          () => mockedChannel.stream,
        ).thenAnswer((_) => streamController.stream);
        when(
          () => mockedSink.close(any(), any()),
        ).thenAnswer((_) => Future.value());
        when(() => mockedSink.close()).thenAnswer((_) => Future.value());
        when(() => mockedSink.add(any())).thenAnswer((invocation) {
          final raw = invocation.positionalArguments.first as String;
          capturedMessages.add(raw);
          final frame = json.decode(raw) as List;
          if (frame[3] == ChannelEvent.join.eventName() &&
              !joinSent.isCompleted) {
            joinSent.complete(frame[4] as Map);
          }
        });

        final socket = RealtimeClient(
          socketEndpoint,
          transport: (url, headers) => mockedChannel,
          customAccessToken: () async {
            tokenCallbackCalls++;
            return token;
          },
        );

        final channel = socket.channel('realtime:test');
        channel.subscribe();

        // The join is buffered while the socket is still connecting and the
        // token has not resolved yet, so it carries no access_token.
        expect(socket.sendBuffer, isNotEmpty);
        expect(capturedMessages, isEmpty);

        // Once the connection is ready the token is resolved and the buffered
        // join is re-sent with the token patched into its payload.
        readyCompleter.complete();
        final joinPayload = await joinSent.future.timeout(
          const Duration(seconds: 5),
        );

        expect(tokenCallbackCalls, greaterThan(0));
        expect(socket.accessToken, token);
        expect(joinPayload['access_token'], token);

        await socket.disconnect();
        await streamController.close();
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

    //! Unimplemented Test: closes socket when heartbeat is not ack'd within
    //! heartbeat window

    test('pushes heartbeat data when connected', () async {
      mockedSocket.connectionState = SocketState.open;

      await mockedSocket.sendHeartbeat();

      verify(() => mockedSink.add(captureAny(that: equals(data)))).called(1);
    });

    test('no ops when not connected', () async {
      mockedSocket.connectionState = SocketState.connecting;

      await mockedSocket.sendHeartbeat();
      verifyNever(() => mockedSink.add(any()));
    });
  });

  group('connect/disconnect race condition', () {
    test(
      'connect does not crash if disconnect nullifies connection during await '
      'ready',
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

        // Now complete the ready future — both connect and disconnect can
        // proceed
        readyCompleter.complete();
        await disconnectFuture;
        await connectFuture;

        // Should NOT have transitioned to open because disconnect nullified
        // connection
        expect(socket.connectionState, isNot(SocketState.open));
        expect(socket.connection, isNull);
      },
    );

    test(
      'connect bails out when connectionState changes during await ready',
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

        expect(socket.connectionState, isNot(SocketState.open));
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

      expect(socket.connectionState, SocketState.open);
      expect(socket.connection, mockedSocketChannel2);

      await socket.disconnect();
      await streamController2.close();
    });
  });
}
