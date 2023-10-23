import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
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
}

class RealtimeClient {
  String? accessToken;
  List<RealtimeChannel> channels = [];
  final String endPoint;
  final Map<String, String> headers;
  final Map<String, dynamic> params;
  final Duration timeout;
  final WebSocketTransport transport;
  final Client? httpClient;
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
  int eventsPerSecondLimitMs = 100;
  bool inThrottle = false;

  /// Initializes the Socket
  ///
  /// `endPoint` The string WebSocket endpoint, ie, "ws://example.com/socket", "wss://example.com", "/socket" (inherited host & protocol)
  /// `transport` The Websocket Transport, for example WebSocket.
  /// `timeout` The default timeout in milliseconds to trigger push timeouts.
  /// `params` The optional params to pass when connecting.
  /// `headers` The optional headers to pass when connecting.
  /// `heartbeatIntervalMs` The millisec interval to send a heartbeat message.
  /// `logger` The optional function for specialized logging, ie: logger: (kind, msg, data) => { console.log(`$kind: $msg`, data) }
  /// `encode` The function to encode outgoing messages. Defaults to JSON: (payload, callback) => callback(JSON.stringify(payload))
  /// `decode` The function to decode incoming messages. Defaults to JSON: (payload, callback) => callback(JSON.parse(payload))
  /// `longpollerTimeout` The maximum timeout of a long poll AJAX request. Defaults to 20s (double the server long poll timer).
  /// `reconnectAfterMs` The optional function that returns the millsec reconnect interval. Defaults to stepped backoff off.
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
    final eventsPerSecond = params['eventsPerSecond'];
    if (eventsPerSecond != null) {
      eventsPerSecondLimitMs = (1000 / int.parse(eventsPerSecond)).floor();
    }

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
      () {
        disconnect();
        connect();
      },
      this.reconnectAfterMs,
    );
  }

  /// Connects the socket.
  @internal
  void connect() async {
    if (conn != null) {
      return;
    }

    try {
      connState = SocketStates.connecting;
      conn = transport(endPointURL, headers);

      // handle connection errors
      conn!.ready.catchError(_onConnError);

      connState = SocketStates.open;

      _onConnOpen();
      conn!.stream.timeout(Duration(milliseconds: longpollerTimeout));
      conn!.stream.listen(
        // incoming messages
        (message) => onConnMessage(message as String),
        onError: _onConnError,
        onDone: () {
          // communication has been closed
          if (connState != SocketStates.disconnected) {
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
  void disconnect({int? code, String? reason}) {
    final conn = this.conn;
    if (conn != null) {
      connState = SocketStates.disconnected;
      if (code != null) {
        conn.sink.close(code, reason ?? '');
      } else {
        conn.sink.close();
      }
      this.conn = null;

      // remove open handles
      if (heartbeatTimer != null) heartbeatTimer?.cancel();
      reconnectTimer.reset();
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
  void log([String? kind, String? msg, dynamic data]) {
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
      case SocketStates.closing:
        return 'closing';
      case SocketStates.disconnected:
        return 'disconnected';
      case SocketStates.closed:
      default:
        return 'closed';
    }
  }

  /// Retuns `true` is the connection is open.
  bool get isConnected => connectionState == 'open';

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
    final event = message.event;
    void callback() {
      encode(message.toJson(), (result) => conn?.sink.add(result));
    }

    log('push', '${message.topic} ${message.event} (${message.ref})',
        message.payload);

    if (isConnected) {
      if ([
        ChannelEvents.broadcast,
        ChannelEvents.presence,
        ChannelEvents.postgresChanges
      ].contains(event)) {
        final isThrottled = _throttle(callback)();
        if (isThrottled) {
          return 'rate limited';
        }
      } else {
        callback();
      }
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
  void setAuth(String? token) {
    accessToken = token;

    for (final channel in channels) {
      if (token != null) {
        channel.updateJoinPayload({'user_token': token});
      }
      if (channel.joinedOnce && channel.isJoined) {
        channel.push(ChannelEvents.accessToken, {'access_token': token});
      }
    }
  }

  /// Unsubscribe from channels with the specified topic.
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
    log('transport', 'close', event);

    /// SocketStates.disconnected: by user with socket.disconnect()
    /// SocketStates.closed: NOT by user, should try to reconnect
    if (connState == SocketStates.closed) {
      _triggerChanError();
      reconnectTimer.scheduleTimeout();
    }
    if (heartbeatTimer != null) heartbeatTimer!.cancel();
    for (final callback in stateChangeCallbacks['close']!) {
      callback(event);
    }
  }

  void _onConnError(dynamic error) {
    log('transport', error.toString());
    _triggerChanError();
    for (final callback in stateChangeCallbacks['error']!) {
      callback(error);
    }
  }

  void _triggerChanError() {
    for (final channel in channels) {
      channel.trigger(ChannelEvents.error.eventName());
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

  bool Function() _throttle(Function callback, [int? eventsPerSecondLimit]) {
    return () {
      if (inThrottle) return true;
      callback();
      inThrottle = true;
      Timer(
          Duration(
              milliseconds: eventsPerSecondLimit ?? eventsPerSecondLimitMs),
          () => inThrottle = false);
      return false;
    };
  }
}
