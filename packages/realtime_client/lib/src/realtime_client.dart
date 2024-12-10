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
import 'package:realtime_client/src/websocket/websocket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef WebSocketTransport = WebSocketChannel Function(
  String url,
  Map<String, String> headers,
);

typedef RealtimeEncode = void Function(
  dynamic payload,
  void Function(String result) callback,
);

typedef RealtimeDecode = void Function(
  String payload,
  void Function(dynamic result) callback,
);

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

class RealtimeClient {
  // This is named `accessTokenValue` in supabase-js
  String? accessToken;
  List<RealtimeChannel> channels = [];
  final String endPoint;

  final Map<String, String> headers;
  final Map<String, dynamic> params;
  final Duration timeout;
  final WebSocketTransport transport;
  final Client? httpClient;
  final _log = Logger('supabase.realtime');
  int heartbeatIntervalMs = 30000;
  Timer? heartbeatTimer;

  /// reference ID of the most recently sent heartbeat.
  ///
  /// Used to keep track of whether the client is connected to the server.
  String? pendingHeartbeatRef;

  /// Unique reference ID for every heartbeat.
  int ref = 0;
  late RetryTimer reconnectTimer;
  void Function(String? kind, String? msg, dynamic data)? logger;
  late RealtimeEncode encode;
  late RealtimeDecode decode;
  late TimerCalculation reconnectAfterMs;
  WebSocketChannel? conn;
  List sendBuffer = [];
  Map<String, List<Function>> stateChangeCallbacks = {
    'open': [],
    'close': [],
    'error': [],
    'message': []
  };
  int longpollerTimeout = 20000;
  SocketStates? connState;
  // This is called `accessToken` in realtime-js
  Future<String> Function()? customAccessToken;

  /// Initializes the Socket
  ///
  /// [endPoint] The string WebSocket endpoint, ie, "ws://example.com/socket", "wss://example.com", "/socket" (inherited host & protocol
  ///
  /// [transport] The Websocket Transport, for example WebSocket.
  ///
  /// [timeout] The default timeout in milliseconds to trigger push timeouts.
  ///
  /// [params] The optional params to pass when connecting.
  ///
  /// [headers] The optional headers to pass when connecting.
  ///
  /// [heartbeatIntervalMs] The millisec interval to send a heartbeat message.
  ///
  /// [logger] The optional function for specialized logging, ie: logger: (kind, msg, data) => { console.log(`$kind: $msg`, data) }
  ///
  /// [encode] The function to encode outgoing messages. Defaults to JSON: (payload, callback) => callback(JSON.stringify(payload))
  ///
  /// [decode] The function to decode incoming messages. Defaults to JSON: (payload, callback) => callback(JSON.parse(payload))
  ///
  /// [longpollerTimeout] The maximum timeout of a long poll AJAX request. Defaults to 20s (double the server long poll timer).
  ///
  /// [reconnectAfterMs] The optional function that returns the millsec reconnect interval. Defaults to stepped backoff off.
  ///
  /// [logLevel] Specifies the log level for the connection on the server.
  RealtimeClient(
    String endPoint, {
    WebSocketTransport? transport,
    this.timeout = Constants.defaultTimeout,
    this.heartbeatIntervalMs = 30000,
    this.logger,
    RealtimeEncode? encode,
    RealtimeDecode? decode,
    TimerCalculation? reconnectAfterMs,
    Map<String, String>? headers,
    this.params = const {},
    this.longpollerTimeout = 20000,
    RealtimeLogLevel? logLevel,
    this.httpClient,
  })  : endPoint = Uri.parse('$endPoint/${Transports.websocket}')
            .replace(
              queryParameters:
                  logLevel == null ? null : {'log_level': logLevel.name},
            )
            .toString(),
        headers = {
          ...Constants.defaultHeaders,
          if (headers != null) ...headers,
        },
        transport = transport ?? createWebSocketClient {
    _log.config(
        'Initialize RealtimeClient with endpoint: $endPoint, timeout: $timeout, heartbeatIntervalMs: $heartbeatIntervalMs, longpollerTimeout: $longpollerTimeout, logLevel: $logLevel');
    _log.finest('Initialize with headers: $headers, params: $params');
    final customJWT = this.headers['Authorization']?.split(' ').last;
    accessToken = customJWT ?? params['apikey'];

    this.reconnectAfterMs =
        reconnectAfterMs ?? RetryTimer.createRetryFunction();
    this.encode = encode ??
        (dynamic payload, Function(String result) callback) =>
            callback(json.encode(payload));
    this.decode = decode ??
        (String payload, Function(dynamic result) callback) =>
            callback(json.decode(payload));
    reconnectTimer = RetryTimer(
      () async {
        await disconnect();
        await connect();
      },
      this.reconnectAfterMs,
    );
  }

  /// Connects the socket.
  @internal
  Future<void> connect() async {
    if (conn != null) {
      return;
    }

    try {
      log('transport', 'connecting to $endPointURL', null);
      log('transport', 'connecting', null, Level.FINE);
      connState = SocketStates.connecting;
      conn = transport(endPointURL, headers);

      try {
        await conn!.ready;
      } catch (error) {
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

      connState = SocketStates.open;

      _onConnOpen();
      conn!.stream.timeout(Duration(milliseconds: longpollerTimeout));
      conn!.stream.listen(
        // incoming messages
        (message) => onConnMessage(message as String),
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

  /// Disconnects the socket with status [code] and [reason] for the disconnect
  Future<void> disconnect({int? code, String? reason}) async {
    final conn = this.conn;
    if (conn != null) {
      final oldState = connState;
      connState = SocketStates.disconnecting;
      log('transport', 'disconnecting', {'code': code, 'reason': reason},
          Level.FINE);

      // Connection cannot be closed while it's still connecting. Wait for connection to
      // be ready and then close it.
      if (oldState == SocketStates.connecting) {
        await conn.ready.catchError((_) {});
      }

      if (oldState == SocketStates.open ||
          oldState == SocketStates.connecting) {
        if (code != null) {
          await conn.sink.close(code, reason ?? '');
        } else {
          await conn.sink.close();
        }
        connState = SocketStates.disconnected;
        reconnectTimer.reset();
        log('transport', 'disconnected', null, Level.FINE);
      }
      this.conn = null;

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
      disconnect();
    }
    return status;
  }

  Future<List<String>> removeAllChannels() async {
    final values =
        await Future.wait(channels.map((channel) => channel.unsubscribe()));
    disconnect();
    return values;
  }

  /// Logs the message. Override `this.logger` for specialized logging.
  ///
  /// [level] must be [Level.FINEST] for senitive data
  void log(
      [String? kind, String? msg, dynamic data, Level level = Level.FINEST]) {
    _log.log(level, '$kind: $msg', data);
    logger?.call(kind, msg, data);
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
      default:
        return 'closed';
    }
  }

  /// Retuns `true` is the connection is open.
  bool get isConnected => connState == SocketStates.open;

  /// Removes a subscription from the socket.
  @internal
  void remove(RealtimeChannel channel) {
    channels = channels.where((c) => c.joinRef != channel.joinRef).toList();
  }

  RealtimeChannel channel(
    String topic, [
    RealtimeChannelConfig params = const RealtimeChannelConfig(),
  ]) {
    final chan = RealtimeChannel('realtime:$topic', this, params: params);
    channels.add(chan);
    return chan;
  }

  /// Push out a message if the socket is connected.
  ///
  /// If the socket is not connected, the message gets enqueued within a local buffer, and sent out when a connection is next established.
  String? push(Message message) {
    void callback() {
      encode(message.toJson(), (result) => conn?.sink.add(result));
    }

    log('push', '${message.topic} ${message.event} (${message.ref})',
        message.payload);

    if (isConnected) {
      callback();
    } else {
      sendBuffer.add(callback);
    }
    return null;
  }

  void onConnMessage(String rawMessage) {
    decode(rawMessage, (msg) {
      final topic = msg['topic'] as String;
      final event = msg['event'] as String;
      final payload = msg['payload'];
      final ref = msg['ref'] as String?;
      if (ref != null && ref == pendingHeartbeatRef) {
        pendingHeartbeatRef = null;
      }

      log(
        'receive',
        "${payload['status'] ?? ''} $topic $event ${ref != null ? '($ref)' : ''}",
        payload,
      );

      channels
          .where((channel) => channel.isMember(topic))
          .forEach((channel) => channel.trigger(
                event,
                payload,
                ref,
              ));
      for (final callback in stateChangeCallbacks['message']!) {
        callback(msg);
      }
    });
  }

  /// Returns the URL of the websocket.
  String get endPointURL {
    final params = Map<String, String>.from(this.params);
    params['vsn'] = Constants.vsn;
    return _appendParams(endPoint, params);
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

    if (tokenToSend != null) {
      Map<String, dynamic>? parsed;
      try {
        final decoded =
            utf8.decode(base64Url.decode(tokenToSend.split('.')[1]));
        parsed = json.decode(decoded);
      } catch (e) {
        // ignore parsing errors
      }
      if (parsed != null && parsed['exp'] != null) {
        final now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
        final valid = now - parsed['exp'] < 0;
        if (!valid) {
          log(
            'auth',
            'InvalidJWTToken: Invalid value for JWT claim "exp" with value ${parsed['exp']}',
            null,
            Level.FINE,
          );
          throw 'InvalidJWTToken: Invalid value for JWT claim "exp" with value ${parsed['exp']}';
        }
      }
    }

    accessToken = tokenToSend;

    for (final channel in channels) {
      if (tokenToSend != null) {
        channel.updateJoinPayload({'access_token': tokenToSend});
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
      dupChannel.unsubscribe();
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
      (Timer t) => sendHeartbeat(),
    );
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

  String _appendParams(String url, Map<String, String> params) {
    if (params.keys.isEmpty) {
      return url;
    }

    var endpoint = Uri.parse(url);
    endpoint = endpoint.replace(queryParameters: {
      ...endpoint.queryParameters,
      ...params,
    });

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
  void sendHeartbeat() {
    if (!isConnected) {
      return;
    }

    // If the previous heartbeat hasn't received a reply, close the connection.
    if (pendingHeartbeatRef != null) {
      pendingHeartbeatRef = null;
      log(
        'transport',
        'heartbeat timeout. Attempting to re-establish connection',
      );
      conn?.sink.close(Constants.wsCloseNormal, 'heartbeat timeout');
      return;
    }
    pendingHeartbeatRef = makeRef();
    push(Message(
      topic: 'phoenix',
      event: ChannelEvents.heartbeat,
      payload: {},
      ref: pendingHeartbeatRef!,
    ));
    setAuth(accessToken);
  }
}
