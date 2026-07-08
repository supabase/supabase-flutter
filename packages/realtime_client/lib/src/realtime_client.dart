import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/constants.dart';
import 'package:realtime_client/src/message.dart';
import 'package:realtime_client/src/retry_timer.dart';
import 'package:realtime_client/src/serializer.dart';
import 'package:realtime_client/src/websocket/websocket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef WebSocketTransport =
    WebSocketChannel Function(
      String url,
      Map<String, String> headers,
    );

/// Serializes an outgoing message into the `String` or binary frame written to
/// the WebSocket.
typedef RealtimeEncode = Object Function(Map<String, dynamic> payload);

/// Deserializes a raw incoming WebSocket frame (`String` or binary) into a
/// message map.
typedef RealtimeDecode = Map<String, dynamic> Function(Object payload);

/// Event details for when the connection closed.
class RealtimeCloseEvent {
  /// Web socket protocol status codes for when a connection is closed.
  ///
  /// The full list can be found at the following:
  ///
  /// https://datatracker.ietf.org/doc/html/rfc6455#section-7.4
  final int code;

  /// Connection closed reason sent from the server
  ///
  /// https://datatracker.ietf.org/doc/html/rfc6455#section-7.1.6
  final String? reason;

  const RealtimeCloseEvent({
    required this.code,
    required this.reason,
  });

  @override
  String toString() {
    return 'RealtimeCloseEvent(code: $code, reason: $reason)';
  }
}

/// The lifecycle status of a heartbeat reported to [RealtimeClient.onHeartbeat].
enum RealtimeHeartbeatStatus {
  sent,
  ok,
  error,
  timeout,
}

/// Manages a persistent WebSocket connection to the Supabase Realtime server.
///
/// [RealtimeClient] is the central hub for all real-time communication. It owns
/// the WebSocket lifecycle — opening, closing, and reconnecting with exponential
/// backoff — and multiplexes multiple [RealtimeChannel] subscriptions over a
/// single connection.
///
/// **Responsibilities:**
/// - Establishes and maintains the WebSocket connection to [endPoint].
/// - Sends periodic heartbeat messages to detect stale connections and
///   reconnects automatically when a heartbeat goes unanswered.
/// - Encodes outgoing messages and decodes incoming messages (JSON by default).
/// - Manages a registry of [RealtimeChannel] instances, routing inbound
///   messages to the correct channel by topic.
/// - Refreshes the access token and propagates it to all joined channels so
///   that subscriptions remain authorized across token rotations.
///
/// **Key collaborators:**
/// - [RealtimeChannel] — created via [channel] and registered here; the client
///   dispatches server messages to each channel by topic.
/// - `RetryTimer` — drives the reconnect backoff strategy.
/// - [WebSocketTransport] — injectable transport layer used in tests.
///
/// **Lifecycle:**
/// 1. Construct with an endpoint URL and optional configuration.
/// 2. Call [connect] to open the WebSocket. The client begins heartbeating
///    immediately and reconnects on unexpected disconnections.
/// 3. Create channels with [channel], subscribe to events, and call
///    `RealtimeChannel.subscribe()` to join server-side topics.
/// 4. Call [disconnect] when real-time functionality is no longer needed; this
///    removes all channels and closes the underlying socket.
///
/// **Platform notes:**
/// - Works on all Dart platforms (Flutter mobile/desktop, web, server).
/// - On web, the underlying [WebSocketChannel] uses the browser WebSocket API.
class RealtimeClient {
  String? accessToken;
  List<RealtimeChannel> channels = [];
  final String endPoint;

  final Map<String, String> headers;
  final Map<String, dynamic> params;

  final RealtimeProtocolVersion version;
  final Duration connectionCloseTimeout;
  final Duration timeout;
  final WebSocketTransport transport;
  final Client? httpClient;
  final _log = Logger('supabase.realtime');
  int heartbeatIntervalMs = Constants.defaultHeartbeatIntervalMs;
  Timer? heartbeatTimer;

  /// reference ID of the most recently sent heartbeat.
  ///
  /// Used to keep track of whether the client is connected to the server.
  String? pendingHeartbeatRef;

  /// Unique reference ID for every heartbeat.
  int ref = 0;
  late RetryTimer reconnectTimer;
  void Function(String? kind, String? message, dynamic data)? logger;
  static final Serializer _serializer = Serializer();
  final RealtimeEncode encode;
  final RealtimeDecode decode;
  late TimerCalculation reconnectAfterMs;
  WebSocketChannel? conn;
  StreamSubscription? _connectionSubscription;
  List sendBuffer = [];
  Map<String, List<Function>> stateChangeCallbacks = {
    'open': [],
    'close': [],
    'error': [],
    'message': [],
  };

  final _heartbeatController =
      StreamController<RealtimeHeartbeatStatus>.broadcast();

  @Deprecated("No longer used. Will be removed in the next major version.")
  int longpollerTimeout = 20000;
  SocketStates? connState;
  Future<String?> Function()? customAccessToken;

  /// Initializes the Socket
  ///
  /// [endPoint] The string WebSocket endpoint, ie, "ws://example.com/socket", "wss://example.com", "/socket" (inherited host & protocol
  ///
  /// [transport] The Websocket Transport, for example WebSocket.
  ///
  /// [timeout] The default timeout to trigger push timeouts.
  ///
  /// [connectionCloseTimeout] The timeout to wait for the connection to close
  /// before dismissing the result. Defaults to 6 seconds.
  ///
  /// [params] The optional params to pass when connecting.
  ///
  /// [headers] The optional headers to pass when connecting.
  ///
  /// [heartbeatIntervalMs] The millisec interval to send a heartbeat message.
  ///
  /// [logger] The optional function for specialized logging, ie: logger: (kind, message, data) => { console.log(`$kind: $message`, data) }
  ///
  /// [encode] Overrides how outgoing messages are serialized, for example to
  /// use a faster JSON implementation. Defaults to the codec for [version].
  ///
  /// [decode] Overrides how incoming frames are deserialized. Defaults to the
  /// codec for [version].
  ///
  /// [reconnectAfterMs] The optional function that returns the millisec reconnect interval. Defaults to stepped backoff off.
  ///
  /// [logLevel] Specifies the log level for the connection on the server.
  ///
  /// [version] The Realtime protocol version. Defaults to
  /// [RealtimeProtocolVersion.v2]; pass [RealtimeProtocolVersion.v1] for the
  /// legacy object-shaped JSON frames.
  RealtimeClient(
    String endPoint, {
    WebSocketTransport? transport,
    this.timeout = Constants.defaultTimeout,
    this.connectionCloseTimeout = Constants.defaultConnectionCloseTimeout,
    this.heartbeatIntervalMs = Constants.defaultHeartbeatIntervalMs,
    this.logger,
    RealtimeEncode? encode,
    RealtimeDecode? decode,
    TimerCalculation? reconnectAfterMs,
    Map<String, String>? headers,
    this.params = const {},
    this.longpollerTimeout = 20000,
    RealtimeLogLevel? logLevel,
    this.httpClient,
    this.customAccessToken,
    this.version = RealtimeProtocolVersion.v2,
  }) : endPoint = Uri.parse('$endPoint/${Transports.websocket}')
           .replace(
             queryParameters: logLevel == null
                 ? null
                 : {'log_level': logLevel.name},
           )
           .toString(),
       headers = {
         ...Constants.defaultHeaders,
         ...?headers,
       },
       transport = transport ?? createWebSocketClient,
       encode =
           encode ??
           (version == RealtimeProtocolVersion.v1
               ? _encodeLegacy
               : _serializer.encode),
       decode =
           decode ??
           (version == RealtimeProtocolVersion.v1
               ? _decodeLegacy
               : _serializer.decode) {
    _log.config(
      'Initialize RealtimeClient with endpoint: $endPoint, timeout: $timeout, heartbeatIntervalMs: $heartbeatIntervalMs, logLevel: ${logLevel?.name}',
    );
    _log.finest('Initialize with headers: $headers, params: $params');
    final customJWT = this.headers['Authorization']?.split(' ').last;
    accessToken = customJWT ?? params['apikey'];

    this.reconnectAfterMs =
        reconnectAfterMs ?? RetryTimer.createRetryFunction();
    reconnectTimer = RetryTimer(
      () => unawaited(_reconnect()),
      this.reconnectAfterMs,
    );
  }

  /// Connects the socket.
  @internal
  Future<void> connect() async {
    if (conn != null) {
      if (connState != SocketStates.closed) {
        return;
      }
      await disconnect();
    }

    try {
      log('transport', 'connecting to $endPointURL', null);
      log('transport', 'connecting', null, Level.FINE);
      connState = SocketStates.connecting;
      final WebSocketChannel localConn = transport(endPointURL, headers);
      conn = localConn;

      try {
        await localConn.ready;
      } catch (error) {
        // Bail out if disconnect() ran or a new connect() started during await
        if (conn != localConn) {
          return;
        }
        // Don't schedule a reconnect and emit error if connection has been
        // closed by the user or [disconnect] waits for the connection to be
        // ready before closing it.
        if (connState != SocketStates.disconnected &&
            connState != SocketStates.disconnecting) {
          connState = SocketStates.closed;
          _onConnError(error);
          reconnectTimer.scheduleTimeout();
        }
        return;
      }

      // Guard: bail out if disconnect() ran during the await
      if (conn != localConn || connState != SocketStates.connecting) {
        return;
      }

      connState = SocketStates.open;

      _onConnOpen();
      _connectionSubscription = localConn.stream.listen(
        (message) => onConnMessage(message),
        onError: _onConnError,
        onDone: () {
          // communication has been closed
          if (connState != SocketStates.disconnected &&
              connState != SocketStates.disconnecting) {
            connState = SocketStates.closed;
          }
          _onConnClose();
        },
      );
    } catch (e) {
      /// General error handling
      _onConnError(e);
    }
  }

  Future<void> _reconnect() async {
    await disconnect();
    await connect();
  }

  /// Disconnects the socket with status [code] and [reason] for the disconnect
  Future<void> disconnect({int? code, String? reason}) async {
    final conn = this.conn;
    if (conn != null) {
      final oldState = connState;
      final shouldCloseSink =
          oldState == SocketStates.open || oldState == SocketStates.connecting;
      if (shouldCloseSink) {
        // Don't set the state to `disconnecting` if the connection is already closed.
        connState = SocketStates.disconnecting;
        log('transport', 'disconnecting', {
          'code': code,
          'reason': reason,
        }, Level.FINE);
      }

      if (shouldCloseSink) {
        onTimeout() {
          log(
            'transport',
            'timeout while closing connection',
            null,
            Level.FINE,
          );
          // Handle as the connection would have been closed successfully, to
          // avoid hanging the client. This is done by mimicking the onDone
          // callback of the connection stream. By canceling the subscription,
          // we avoid calling the onDone too.
          connState = SocketStates.disconnected;
          _onConnClose();
        }

        if (code != null) {
          // Add a timeout to close the sink to avoid hanging in case something
          // is wrong with the connection.
          // The Dart SDK has a timeout of 5 seconds for closing the IO WebSocket connection, so we set a timeout of 6 seconds here to avoid hanging indefinitely.
          await conn.sink
              .close(code, reason ?? '')
              .timeout(connectionCloseTimeout, onTimeout: onTimeout);
        } else {
          await conn.sink.close().timeout(
            connectionCloseTimeout,
            onTimeout: onTimeout,
          );
        }
        connState = SocketStates.disconnected;
        log('transport', 'disconnected', null, Level.FINE);
      }

      // Cancel any reconnect scheduled by `_onConnClose`. When the socket has
      // already dropped (`connState == closed`) the block above is skipped, so
      // without this an armed backoff timer would fire after the user
      // explicitly disconnected and silently reopen the connection.
      reconnectTimer.cancel();

      this.conn = null;
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;

      // remove open handles
      if (heartbeatTimer != null) heartbeatTimer?.cancel();
    }
  }

  List<RealtimeChannel> getChannels() {
    return channels;
  }

  Future<String> removeChannel(RealtimeChannel channel) async {
    final status = await channel.unsubscribe();
    if (channels.isEmpty) {
      unawaited(disconnect());
    }
    return status;
  }

  Future<List<String>> removeAllChannels() async {
    final values = await Future.wait(
      channels.map((channel) => channel.unsubscribe()),
    );
    unawaited(disconnect());
    return values;
  }

  /// Logs the message. Override `this.logger` for specialized logging.
  ///
  /// [level] must be [Level.FINEST] for sensitive data
  void log([
    String? kind,
    String? message,
    dynamic data,
    Level level = Level.FINEST,
  ]) {
    _log.log(level, '$kind: $message', data);
    logger?.call(kind, message, data);
  }

  /// Registers callbacks for connection state change events
  ///
  /// Examples
  /// socket.onOpen(() {print("Socket opened.");});
  ///
  void onOpen(void Function() callback) {
    stateChangeCallbacks['open']!.add(callback);
  }

  /// Registers a callbacks for connection state change events.
  void onClose(void Function(dynamic) callback) {
    stateChangeCallbacks['close']!.add(callback);
  }

  /// Registers a callbacks for connection state change events.
  void onError(void Function(dynamic) callback) {
    stateChangeCallbacks['error']!.add(callback);
  }

  /// Calls a function any time a message is received.
  void onMessage(void Function(dynamic) callback) {
    stateChangeCallbacks['message']!.add(callback);
  }

  /// Emits a status whenever a heartbeat is sent, acknowledged, or times out.
  Stream<RealtimeHeartbeatStatus> get onHeartbeat =>
      _heartbeatController.stream;

  /// Returns the current state of the socket.
  String get connectionState {
    switch (connState) {
      case SocketStates.connecting:
        return 'connecting';
      case SocketStates.open:
        return 'open';
      case SocketStates.disconnecting:
        return 'disconnecting';
      case SocketStates.disconnected:
        return 'disconnected';
      case SocketStates.closed:
      case null:
        return 'closed';
    }
  }

  /// Returns `true` is the connection is open.
  bool get isConnected => connState == SocketStates.open;

  /// Removes a subscription from the socket.
  @internal
  void remove(RealtimeChannel channel) {
    channels = channels.where((c) => c.joinRef != channel.joinRef).toList();
  }

  RealtimeChannel channel(
    String topic, [
    RealtimeChannelConfig config = const RealtimeChannelConfig(),
  ]) {
    final newChannel = RealtimeChannel('realtime:$topic', this, params: config);
    channels.add(newChannel);
    return newChannel;
  }

  /// Push out a message if the socket is connected.
  ///
  /// If the socket is not connected, the message gets enqueued within a local buffer, and sent out when a connection is next established.
  // ignore: function-always-returns-null
  String? push(Message message) {
    void callback() {
      conn?.sink.add(encode(message.toJson()));
    }

    log(
      'push',
      '${message.topic} ${message.event.name} (${message.ref})',
      message.payload,
    );

    if (isConnected) {
      callback();
    } else {
      sendBuffer.add(callback);
    }
    return null;
  }

  void onConnMessage(Object rawMessage) {
    final Map<String, dynamic> message;
    try {
      message = decode(rawMessage);
    } catch (error) {
      log('transport', 'failed to decode message', error);
      return;
    }

    final topic = message['topic'] as String;
    final event = message['event'] as String;
    final payload = message['payload'];
    final messageRef = message['ref'] as String?;
    if (messageRef != null && messageRef == pendingHeartbeatRef) {
      pendingHeartbeatRef = null;
      final heartbeatStatus = payload is Map ? payload['status'] : null;
      _heartbeatController.add(
        heartbeatStatus == 'ok'
            ? RealtimeHeartbeatStatus.ok
            : RealtimeHeartbeatStatus.error,
      );
    }

    final status = payload is Map ? (payload['status'] ?? '') : '';
    log(
      'receive',
      "$status $topic $event ${messageRef != null ? '($messageRef)' : ''}",
      payload,
    );

    channels
        .where((channel) => channel.isMember(topic))
        .forEach(
          (channel) => channel.trigger(
            event,
            payload,
            messageRef,
          ),
        );
    for (final callback in stateChangeCallbacks['message']!) {
      callback(message);
    }
  }

  static Object _encodeLegacy(Map<String, dynamic> message) =>
      jsonEncode(message);

  static Map<String, dynamic> _decodeLegacy(Object rawMessage) =>
      Map.from(jsonDecode(rawMessage as String) as Map);

  /// Returns the URL of the websocket.
  String get endPointURL {
    final queryParameters = Map<String, String>.from(params);
    queryParameters['vsn'] = version.vsn;
    return _appendParams(endPoint, queryParameters);
  }

  /// Return the next message ref, accounting for overflows
  String makeRef() {
    final int newRef = ref + 1;
    if (newRef < 0) {
      ref = 0;
    } else {
      ref = newRef;
    }
    return ref.toString();
  }

  /// Sets the JWT access token used for channel subscription authorization and Realtime RLS.
  ///
  /// `token` A JWT strings.
  Future<void> setAuth(String? token) async {
    final tokenToSend =
        token ?? (await customAccessToken?.call()) ?? accessToken;

    if (accessToken == tokenToSend) {
      return;
    }

    accessToken = tokenToSend;

    for (final channel in channels) {
      if (tokenToSend != null) {
        channel.updateJoinPayload({
          'access_token': tokenToSend,
          'version': Constants.defaultHeaders['X-Client-Info'],
        });
      }
      if (channel.joinedOnce && channel.isJoined) {
        channel.push(ChannelEvents.accessToken, {'access_token': tokenToSend});
      }
    }
  }

  /// Unsubscribe from joined or joining channels with the specified topic.
  @internal
  void leaveOpenTopic(String topic) {
    final dupChannel = channels.firstWhereOrNull(
      (c) => c.topic == topic && (c.isJoined || c.isJoining),
    );
    if (dupChannel != null) {
      log('transport', 'leaving duplicate topic "$topic"');
      unawaited(dupChannel.unsubscribe());
    }
  }

  void _onConnOpen() {
    log('transport', 'connected to $endPointURL');
    log('transport', 'connected', null, Level.FINE);
    _flushSendBuffer();
    reconnectTimer.reset();
    if (heartbeatTimer != null) heartbeatTimer!.cancel();
    heartbeatTimer = Timer.periodic(
      Duration(milliseconds: heartbeatIntervalMs),
      (Timer t) => unawaited(sendHeartbeat()),
    );

    try {
      for (final channel in channels) {
        if (channel.isErrored) {
          channel.rejoin();
        }
      }
    } catch (e) {
      log('transport', 'error while rejoining channels', e, Level.WARNING);
    }

    for (final callback in stateChangeCallbacks['open']!) {
      callback();
    }
  }

  /// communication has been closed
  void _onConnClose() {
    final statusCode = conn?.closeCode;
    RealtimeCloseEvent? event;
    if (statusCode != null) {
      event = RealtimeCloseEvent(code: statusCode, reason: conn?.closeReason);
    }
    log('transport', 'close', event, Level.FINE);

    /// SocketStates.disconnected: by user with socket.disconnect()
    /// SocketStates.closed: NOT by user, should try to reconnect
    if (connState == SocketStates.closed) {
      _triggerChanError(event);
      reconnectTimer.scheduleTimeout();
    }
    if (heartbeatTimer != null) heartbeatTimer!.cancel();
    for (final callback in stateChangeCallbacks['close']!) {
      callback(event);
    }
  }

  void _onConnError(dynamic error) {
    log('transport', error.toString());
    _triggerChanError(error);
    for (final callback in stateChangeCallbacks['error']!) {
      callback(error);
    }
  }

  void _triggerChanError([dynamic error]) {
    for (final channel in channels) {
      channel.trigger(ChannelEvents.error.eventName(), error);
    }
  }

  String _appendParams(String url, Map<String, String> queryParameters) {
    if (queryParameters.keys.isEmpty) {
      return url;
    }

    var endpoint = Uri.parse(url);
    endpoint = endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        ...queryParameters,
      },
    );

    return endpoint.toString();
  }

  void _flushSendBuffer() {
    if (isConnected && sendBuffer.isNotEmpty) {
      for (final callback in sendBuffer) {
        callback();
      }
      sendBuffer = [];
    }
  }

  @internal
  Future<void> sendHeartbeat() async {
    if (!isConnected) {
      return;
    }

    // If the previous heartbeat hasn't received a reply, close the connection.
    if (pendingHeartbeatRef != null) {
      pendingHeartbeatRef = null;
      log(
        'transport',
        'heartbeat timeout. Attempting to re-establish conn',
      );
      _heartbeatController.add(RealtimeHeartbeatStatus.timeout);
      unawaited(conn?.sink.close(Constants.wsCloseNormal, 'heartbeat timeout'));
      return;
    }
    pendingHeartbeatRef = makeRef();
    push(
      Message(
        topic: 'phoenix',
        event: ChannelEvents.heartbeat,
        payload: {},
        ref: pendingHeartbeatRef!,
      ),
    );
    _heartbeatController.add(RealtimeHeartbeatStatus.sent);
    await setAuth(accessToken);
  }
}
