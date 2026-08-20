import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:supabase_realtime/supabase_realtime.dart';
import 'package:supabase_realtime/src/constants.dart';
import 'package:supabase_realtime/src/logger.dart';
import 'package:supabase_realtime/src/retry_timer.dart';
import 'package:supabase_realtime/src/serializer.dart';
import 'package:supabase_realtime/src/websocket/websocket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef WebSocketTransport =
    WebSocketChannel Function(
      String url,
      Map<String, String> headers,
    );

/// Serializes an outgoing message into the `String` or binary frame written to
/// the WebSocket.
///
/// The serialization can run on a background isolate: frames are written to
/// the socket in the order the messages were pushed, even when a later encode
/// completes first.
typedef RealtimeEncode = Future<Object> Function(RealtimeMessage message);

/// Deserializes a raw incoming WebSocket frame (`String` or binary) into a
/// message.
///
/// The deserialization can run on a background isolate: messages are
/// dispatched to the channels in the order the frames were received, even when
/// a later decode completes first.
typedef RealtimeDecode = Future<RealtimeMessage> Function(Object frame);

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

/// The lifecycle status of a heartbeat reported to
/// [RealtimeClient.onHeartbeat].
enum RealtimeHeartbeatStatus {
  sent,
  ok,
  error,
  timeout,
}

/// The status of the WebSocket connection reported by
/// [RealtimeClient.onStatusChange].
enum RealtimeConnectionStatus {
  /// The connection is open and messages can be sent and received.
  open,

  /// The connection is closed, either because [RealtimeClient.disconnect] was
  /// called or because it dropped, in which case the client reconnects with
  /// backoff. [RealtimeClient.connectionState] tells the two apart.
  closed,
}

/// A connection status change emitted by [RealtimeClient.onStatusChange].
class RealtimeConnectionStatusChange {
  /// The new status of the WebSocket connection.
  final RealtimeConnectionStatus status;

  /// The close code and reason sent by the server, `null` for
  /// [RealtimeConnectionStatus.open] and for a close without one.
  final RealtimeCloseEvent? closeEvent;

  const RealtimeConnectionStatusChange(this.status, [this.closeEvent]);

  @override
  String toString() =>
      'RealtimeConnectionStatusChange(status: ${status.name}, '
      'closeEvent: $closeEvent)';
}

/// Manages a persistent WebSocket connection to the Supabase Realtime server.
///
/// [RealtimeClient] is the central hub for all real-time communication. It owns
/// the WebSocket lifecycle — opening, closing, and reconnecting with
/// exponential backoff — and multiplexes multiple [RealtimeChannel]
/// subscriptions over a single connection.
///
/// **Responsibilities:**
/// - Establishes and maintains the WebSocket connection to [endpoint].
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
  final String endpoint;

  final Map<String, String> headers;
  final Map<String, dynamic> parameters;

  final RealtimeProtocolVersion version;
  final Duration connectionCloseTimeout;
  final Duration timeout;
  final WebSocketTransport transport;
  final Client? httpClient;
  Duration heartbeatInterval = RealtimeConstants.defaultHeartbeatInterval;
  @internal
  Timer? heartbeatTimer;

  /// Delay before the socket is disconnected once the last channel has been
  /// removed. [Duration.zero] disconnects immediately. Defaults to twice the
  /// heartbeat interval.
  @internal
  late final Duration disconnectOnEmptyChannelsAfter;

  /// Timer that fires the deferred disconnect once all channels are gone.
  ///
  /// Cancelled when a new channel is created or the client disconnects before
  /// it fires, so that quickly switching channels reuses the open socket.
  Timer? _pendingDisconnectTimer;

  /// reference ID of the most recently sent heartbeat.
  ///
  /// Used to keep track of whether the client is connected to the server.
  @internal
  String? pendingHeartbeatRef;

  /// Counter used by [makeRef] to generate a unique reference ID for every
  /// pushed message, including heartbeats.
  @internal
  int ref = 0;
  @internal
  late RetryTimer reconnectTimer;
  static final Serializer _serializer = Serializer();

  /// Serializes outgoing messages, or `null` to use the built-in codec for
  /// [version].
  final RealtimeEncode? encode;

  /// Deserializes incoming frames, or `null` to use the built-in codec for
  /// [version].
  final RealtimeDecode? decode;

  /// Codec used while [encode] and [decode] are `null`.
  ///
  /// It is synchronous, so a client that does not override the codec writes
  /// and dispatches without a microtask hop.
  final Object Function(RealtimeMessage) _builtInEncode;
  final RealtimeMessage Function(Object) _builtInDecode;
  late TimerCalculation reconnectAfter;
  WebSocketChannel? connection;
  StreamSubscription<dynamic>? _connectionSubscription;
  @internal
  List<dynamic> sendBuffer = [];

  final _statusController =
      StreamController<RealtimeConnectionStatusChange>.broadcast();
  final _messageController = StreamController<RealtimeMessage>.broadcast();

  final _heartbeatController =
      StreamController<RealtimeHeartbeatStatus>.broadcast();

  /// The most recent write that is waiting on an asynchronous [encode], or
  /// `null` when every pushed message has reached the socket.
  ///
  /// Encoding starts as soon as the message is pushed, only the write to the
  /// sink is chained, so that a slow encode does not hold back the ones after
  /// it any longer than the ordering requires.
  Future<void>? _pendingWrite;

  /// The most recent dispatch that is waiting on an asynchronous [decode], or
  /// `null` when every received frame has been dispatched.
  Future<void>? _pendingDispatch;

  /// The current state of the socket, or `null` before the first [connect].
  SocketState? connectionState;
  Future<String?> Function()? customAccessToken;

  /// Initializes the Socket
  ///
  /// [endpoint] The string WebSocket endpoint, ie, "ws://example.com/socket",
  /// "wss://example.com", or "/socket" (which inherits the host and protocol).
  ///
  /// [transport] The Websocket Transport, for example WebSocket.
  ///
  /// [timeout] The default timeout to trigger push timeouts.
  ///
  /// [connectionCloseTimeout] The timeout to wait for the connection to close
  /// before dismissing the result. Defaults to 6 seconds.
  ///
  /// [parameters] The optional parameters to pass when connecting.
  ///
  /// [headers] The optional headers to pass when connecting.
  ///
  /// [heartbeatInterval] The interval at which to send a heartbeat message.
  ///
  /// [disconnectOnEmptyChannelsAfter] The delay before disconnecting the socket
  /// once the last channel is removed. If a new channel is created before the
  /// delay elapses, the pending disconnect is cancelled and the open socket is
  /// reused. Pass [Duration.zero] to disconnect immediately. Defaults to twice
  /// the heartbeat interval.
  ///
  /// [encode] Overrides how outgoing messages are serialized, for example to
  /// serialize on a background isolate. Defaults to the codec for [version].
  ///
  /// [decode] Overrides how incoming frames are deserialized. Defaults to the
  /// codec for [version].
  ///
  /// [reconnectAfter] The optional function that returns the reconnect
  /// interval. Defaults to the stepped backoff of
  /// [RetryTimer.createRetryFunction].
  ///
  /// [logLevel] Specifies the log level for the connection on the server.
  ///
  /// [version] The Realtime protocol version. Defaults to
  /// [RealtimeProtocolVersion.v2]; pass [RealtimeProtocolVersion.v1] for the
  /// legacy object-shaped JSON frames.
  RealtimeClient(
    String endpoint, {
    WebSocketTransport? transport,
    this.timeout = RealtimeConstants.defaultTimeout,
    this.connectionCloseTimeout =
        RealtimeConstants.defaultConnectionCloseTimeout,
    this.heartbeatInterval = RealtimeConstants.defaultHeartbeatInterval,
    Duration? disconnectOnEmptyChannelsAfter,
    this.encode,
    this.decode,
    TimerCalculation? reconnectAfter,
    Map<String, String>? headers,
    this.parameters = const {},
    RealtimeLogLevel? logLevel,
    this.httpClient,
    this.customAccessToken,
    this.version = RealtimeProtocolVersion.v2,
  }) : endpoint = Uri.parse('$endpoint/websocket')
           .replace(
             queryParameters: logLevel == null
                 ? null
                 : {'log_level': logLevel.name},
           )
           .toString(),
       headers = {
         ...RealtimeConstants.defaultHeaders,
         ...?headers,
       },
       transport = transport ?? createWebSocketClient,
       _builtInEncode = version == RealtimeProtocolVersion.v1
           ? _encodeLegacy
           : _serializer.encode,
       _builtInDecode = version == RealtimeProtocolVersion.v1
           ? _decodeLegacy
           : _serializer.decode {
    realtimeLogger.config(
      'Initialize RealtimeClient with endpoint: '
      '${Uri.parse(this.endpoint).redacted}, timeout: $timeout, '
      'heartbeatInterval: $heartbeatInterval, '
      'logLevel: ${logLevel?.name}',
    );
    realtimeLogger.finest(
      'Initialize with headers: ${this.headers.redacted}, '
      'parameters: ${redactedPayload(parameters)}',
    );
    final customJWT = this.headers['Authorization']?.split(' ').last;
    accessToken = customJWT ?? parameters['apikey'];

    this.disconnectOnEmptyChannelsAfter =
        disconnectOnEmptyChannelsAfter ?? (heartbeatInterval * 2);

    this.reconnectAfter = reconnectAfter ?? RetryTimer.createRetryFunction();
    reconnectTimer = RetryTimer(
      () => unawaited(_reconnect()),
      this.reconnectAfter,
    );
  }

  /// Connects the socket.
  @internal
  Future<void> connect() async {
    if (connection != null) {
      if (connectionState != SocketState.closed) {
        return;
      }
      await disconnect();
    }

    try {
      realtimeLogger.fine('Connecting');
      realtimeLogger.finest('Connecting to $_redactedEndpointUrl');
      connectionState = SocketState.connecting;
      final WebSocketChannel localConnection = transport(endpointUrl, headers);
      connection = localConnection;

      try {
        await localConnection.ready;
      } catch (error) {
        // Bail out if disconnect() ran or a new connect() started during await
        if (connection != localConnection) {
          return;
        }
        // Don't schedule a reconnect and emit error if connection has been
        // closed by the user or [disconnect] waits for the connection to be
        // ready before closing it.
        if (connectionState != SocketState.disconnected &&
            connectionState != SocketState.disconnecting) {
          connectionState = SocketState.closed;
          _onConnectionError(error);
          reconnectTimer.scheduleTimeout();
        }
        return;
      }

      // Guard: bail out if disconnect() ran during the await
      if (connection != localConnection ||
          connectionState != SocketState.connecting) {
        return;
      }

      connectionState = SocketState.open;

      _onConnectionOpen();
      _connectionSubscription = localConnection.stream.listen(
        (message) => onConnectionMessage(message),
        onError: _onConnectionError,
        onDone: () {
          // communication has been closed
          if (connectionState != SocketState.disconnected &&
              connectionState != SocketState.disconnecting) {
            connectionState = SocketState.closed;
          }
          _onConnectionClose();
        },
      );
    } catch (error) {
      /// General error handling
      _onConnectionError(error);
    }
  }

  Future<void> _reconnect() async {
    await disconnect();
    await connect();
  }

  /// Disconnects the socket with status [code] and [reason] for the disconnect
  Future<void> disconnect({int? code, String? reason}) async {
    _cancelPendingDisconnect();
    final connection = this.connection;
    if (connection != null) {
      final oldState = connectionState;
      final shouldCloseSink =
          oldState == SocketState.open || oldState == SocketState.connecting;
      if (shouldCloseSink) {
        // Don't set the state to `disconnecting` if the connection is already
        // closed.
        connectionState = SocketState.disconnecting;
        realtimeLogger.fine('Disconnecting (code: $code, reason: $reason)');
      }

      if (shouldCloseSink) {
        onTimeout() {
          realtimeLogger.fine('Timeout while closing connection');
          // Handle as the connection would have been closed successfully, to
          // avoid hanging the client. This is done by mimicking the onDone
          // callback of the connection stream. By canceling the subscription,
          // we avoid calling the onDone too.
          connectionState = SocketState.disconnected;
          _onConnectionClose();
        }

        if (code != null) {
          // Add a timeout to close the sink to avoid hanging in case something
          // is wrong with the connection. The Dart SDK has a timeout of 5
          // seconds for closing the IO WebSocket connection, so we set a
          // timeout of 6 seconds here to avoid hanging indefinitely.
          await connection.sink
              .close(code, reason ?? '')
              .timeout(connectionCloseTimeout, onTimeout: onTimeout);
        } else {
          await connection.sink.close().timeout(
            connectionCloseTimeout,
            onTimeout: onTimeout,
          );
        }
        connectionState = SocketState.disconnected;
        realtimeLogger.fine('Disconnected');
      }

      // Cancel any reconnect scheduled by `_onConnectionClose`. When the socket
      // has already dropped (`connectionState == closed`) the block above is
      // skipped, so without this an armed backoff timer would fire after the
      // user explicitly disconnected and silently reopen the connection.
      reconnectTimer.cancel();

      this.connection = null;
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;

      // Drop the chain so a write or dispatch from the closed connection does
      // not hold back the next session's; each is dropped on its own once it
      // resolves, since it no longer matches the current connection.
      _pendingWrite = null;
      _pendingDispatch = null;

      // remove open handles
      if (heartbeatTimer != null) heartbeatTimer?.cancel();
    }
  }

  List<RealtimeChannel> getChannels() {
    return channels;
  }

  Future<String> removeChannel(RealtimeChannel channel) async {
    final status = await channel.unsubscribe();
    return status;
  }

  Future<List<String>> removeAllChannels() async {
    final values = await Future.wait(
      channels.map((channel) => channel.unsubscribe()),
    );
    await disconnect();
    return values;
  }

  /// Emits whenever the WebSocket connection opens or closes.
  ///
  /// Connection errors are emitted as stream errors, so they are observed with
  /// the `onError` handler of [Stream.listen] rather than as status changes:
  ///
  /// ```dart
  /// final subscription = client.onStatusChange.listen(
  ///   (change) => print('Socket ${change.status.name}.'),
  ///   onError: (error) => print('Socket error: $error'),
  /// );
  /// ```
  ///
  /// The connection level statuses and errors are informational: a dropped
  /// connection and its cause also reach every channel through
  /// [RealtimeChannel.onStatusChange], which is what a subscription should
  /// react to.
  Stream<RealtimeConnectionStatusChange> get onStatusChange =>
      _statusController.stream;

  /// Emits every decoded message received over the WebSocket.
  Stream<RealtimeMessage> get onMessage => _messageController.stream;

  /// Emits a status whenever a heartbeat is sent, acknowledged, errors, or
  /// times out.
  Stream<RealtimeHeartbeatStatus> get onHeartbeat =>
      _heartbeatController.stream;

  /// Returns `true` is the connection is open.
  bool get isConnected => connectionState == SocketState.open;

  /// Removes a subscription from the socket.
  ///
  /// Matches on identity rather than on [RealtimeChannel.joinRef], which is
  /// the empty string until a channel is subscribed and is therefore shared
  /// by every channel that has not joined yet.
  @internal
  void remove(RealtimeChannel channel) {
    channels = channels.where((c) => !identical(c, channel)).toList();
    if (channels.isEmpty) {
      realtimeLogger.fine('No channels remaining, scheduling disconnect');
      _schedulePendingDisconnect();
    }
  }

  RealtimeChannel channel(
    String topic, [
    RealtimeChannelConfig config = const RealtimeChannelConfig(),
  ]) {
    final newChannel = RealtimeChannel('realtime:$topic', this, config: config);
    _cancelPendingDisconnect();
    channels.add(newChannel);
    return newChannel;
  }

  /// Schedules a disconnect once the last channel is removed.
  ///
  /// When [disconnectOnEmptyChannelsAfter] is [Duration.zero] the socket
  /// disconnects immediately, otherwise the disconnect is deferred so that a
  /// channel created within the delay can reuse the open socket.
  void _schedulePendingDisconnect() {
    _cancelPendingDisconnect();
    if (disconnectOnEmptyChannelsAfter == Duration.zero) {
      realtimeLogger.fine('Disconnecting immediately, no channels remaining');
      unawaited(disconnect());
      return;
    }
    _pendingDisconnectTimer = Timer(
      disconnectOnEmptyChannelsAfter,
      () {
        _pendingDisconnectTimer = null;
        if (channels.isEmpty) {
          realtimeLogger.fine(
            'Deferred disconnect fired with no channels remaining, '
            'disconnecting',
          );
          unawaited(disconnect());
        }
      },
    );
    realtimeLogger.fine(
      'Deferred disconnect scheduled in '
      '${disconnectOnEmptyChannelsAfter.inMilliseconds}ms',
    );
  }

  /// Cancels a scheduled disconnect when channel activity is detected.
  void _cancelPendingDisconnect() {
    if (_pendingDisconnectTimer != null) {
      realtimeLogger.fine(
        'Pending disconnect cancelled due to channel activity',
      );
      _pendingDisconnectTimer!.cancel();
      _pendingDisconnectTimer = null;
    }
  }

  /// Push out a message if the socket is connected.
  ///
  /// If the socket is not connected, the message gets enqueued within a local
  /// buffer, and sent out when a connection is next established.
  @internal
  void push(RealtimeMessage message) {
    realtimeLogger.finest(
      'Push ${message.topic} ${message.event} (${message.ref}): '
      '${redactedPayload(message.payload)}',
    );

    if (isConnected) {
      _write(message);
    } else {
      sendBuffer.add(() => _write(message));
    }
  }

  /// Encodes [message] and writes it to the socket.
  ///
  /// The built-in codec writes straight to the sink. A custom [encode] is
  /// awaited first, and its write is chained onto [_pendingWrite] so that a
  /// fast encode never overtakes a slow one that was pushed before it.
  void _write(RealtimeMessage message) {
    final connection = this.connection;
    final encode = this.encode;
    if (encode == null) {
      Object frame;
      try {
        frame = _builtInEncode(message);
      } catch (error) {
        realtimeLogger.warning('Failed to encode message', error);
        return;
      }
      try {
        connection?.sink.add(frame);
      } catch (error) {
        realtimeLogger.warning('Failed to write message', error);
      }
      return;
    }

    final Future<Object> encoded;
    try {
      encoded = encode(message);
    } catch (error) {
      realtimeLogger.warning('Failed to encode message', error);
      return;
    }

    final write = _writeWhenReady(connection, _pendingWrite, encoded);
    _pendingWrite = write;
    unawaited(
      write.whenComplete(() {
        if (identical(_pendingWrite, write)) {
          _pendingWrite = null;
        }
      }),
    );
  }

  /// Awaits [encoded] and every write pushed before it, then writes the frame
  /// to [originConnection] if it is still the current one.
  ///
  /// Never completes with an error, so that a failed encode does not stall the
  /// writes chained after it. A frame whose connection was replaced by a
  /// reconnect in the meantime is dropped rather than written to the new
  /// connection.
  Future<void> _writeWhenReady(
    WebSocketChannel? originConnection,
    Future<void>? previousWrite,
    Future<Object> encoded,
  ) async {
    Object? frame;
    try {
      frame = await encoded;
    } catch (error) {
      realtimeLogger.warning('Failed to encode message', error);
    }

    // Awaited even when the encode failed, otherwise the next write would
    // chain onto this one alone and could overtake `previousWrite`.
    await previousWrite;
    if (frame == null) {
      return;
    }

    if (!identical(originConnection, connection)) {
      realtimeLogger.finest(
        'Dropping an encoded frame from a superseded connection',
      );
      return;
    }

    try {
      originConnection?.sink.add(frame);
    } catch (error) {
      realtimeLogger.warning('Failed to write message', error);
    }
  }

  /// Decodes [rawMessage] and dispatches it to the channels it belongs to.
  ///
  /// The built-in codec dispatches straight away. A custom [decode] is awaited
  /// first, and its dispatch is chained onto [_pendingDispatch] so that a fast
  /// decode never overtakes a slow one that was received before it.
  void onConnectionMessage(Object rawMessage) {
    final connection = this.connection;
    final decode = this.decode;
    if (decode == null) {
      final RealtimeMessage message;
      try {
        message = _builtInDecode(rawMessage);
      } catch (error) {
        realtimeLogger.warning('Failed to decode message', error);
        return;
      }
      try {
        _dispatch(message);
      } catch (error) {
        realtimeLogger.warning('Failed to dispatch message', error);
      }
      return;
    }

    final Future<RealtimeMessage> decoded;
    try {
      decoded = decode(rawMessage);
    } catch (error) {
      realtimeLogger.warning('Failed to decode message', error);
      return;
    }

    final dispatch = _dispatchWhenReady(connection, _pendingDispatch, decoded);
    _pendingDispatch = dispatch;
    unawaited(
      dispatch.whenComplete(() {
        if (identical(_pendingDispatch, dispatch)) {
          _pendingDispatch = null;
        }
      }),
    );
  }

  /// Awaits [decoded] and every message received before it, then dispatches it
  /// if [originConnection] is still the current one.
  ///
  /// Never completes with an error, so that a failed decode does not stall the
  /// messages chained after it. A message received on a connection that a
  /// reconnect has since replaced is dropped rather than dispatched into the
  /// new session.
  Future<void> _dispatchWhenReady(
    WebSocketChannel? originConnection,
    Future<void>? previousDispatch,
    Future<RealtimeMessage> decoded,
  ) async {
    RealtimeMessage? message;
    try {
      message = await decoded;
    } catch (error) {
      realtimeLogger.warning('Failed to decode message', error);
    }

    // Awaited even when the decode failed, otherwise the next message would
    // chain onto this one alone and could overtake `previousDispatch`.
    await previousDispatch;
    if (message == null) {
      return;
    }

    if (!identical(originConnection, connection)) {
      realtimeLogger.finest(
        'Dropping a decoded message from a superseded connection',
      );
      return;
    }

    try {
      _dispatch(message);
    } catch (error) {
      realtimeLogger.warning('Failed to dispatch message', error);
    }
  }

  void _dispatch(RealtimeMessage message) {
    final topic = message.topic;
    final event = message.event;
    final payload = message.payload;
    final messageRef = message.ref;
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
    realtimeLogger.finest(
      "Receive $status $topic $event "
      "${messageRef != null ? '($messageRef)' : ''}: "
      "${redactedPayload(payload)}",
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
    _messageController.add(message);
  }

  static Object _encodeLegacy(RealtimeMessage message) =>
      jsonEncode(message.toJson(RealtimeProtocolVersion.v1));

  static RealtimeMessage _decodeLegacy(Object frame) =>
      RealtimeMessage.fromJson(
        jsonDecode(frame as String),
        RealtimeProtocolVersion.v1,
      );

  /// Returns the URL of the websocket.
  String get endpointUrl {
    final queryParameters = Map<String, String>.from(parameters);
    queryParameters['vsn'] = version.wireVersion;
    return _appendParameters(endpoint, queryParameters);
  }

  /// [endpointUrl] with credential-bearing query parameters replaced by
  /// `<redacted>`, safe to include in log records.
  String get _redactedEndpointUrl => Uri.parse(endpointUrl).redacted.toString();

  /// Return the next message ref, accounting for overflows
  @internal
  String makeRef() {
    final int newRef = ref + 1;
    if (newRef < 0) {
      ref = 0;
    } else {
      ref = newRef;
    }
    return ref.toString();
  }

  /// Sets the JWT access token used for channel subscription authorization and
  /// Realtime RLS.
  ///
  /// `token` A JWT strings.
  Future<void> setAccessToken(String? token) async {
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
          'version': RealtimeConstants.defaultHeaders['X-Client-Info'],
        });
      }
      if (channel.joinedOnce && channel.isJoined) {
        channel.push(ChannelEvent.accessToken, {'access_token': tokenToSend});
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
      realtimeLogger.fine('Leaving duplicate topic "$topic"');
      unawaited(dupChannel.unsubscribe());
    }
  }

  void _onConnectionOpen() {
    realtimeLogger.fine('Connected');
    realtimeLogger.finest('Connected to $_redactedEndpointUrl');
    unawaited(_resolveAccessTokenAndFlush());
    reconnectTimer.reset();
    if (heartbeatTimer != null) heartbeatTimer!.cancel();
    heartbeatTimer = Timer.periodic(
      heartbeatInterval,
      (Timer t) => unawaited(sendHeartbeat()),
    );

    try {
      for (final channel in channels) {
        if (channel.isErrored) {
          channel.rejoin();
        }
      }
    } catch (error) {
      realtimeLogger.warning('Error while rejoining channels', error);
    }

    _statusController.add(
      const RealtimeConnectionStatusChange(RealtimeConnectionStatus.open),
    );
  }

  /// communication has been closed
  void _onConnectionClose() {
    final statusCode = connection?.closeCode;
    RealtimeCloseEvent? event;
    if (statusCode != null) {
      event = RealtimeCloseEvent(
        code: statusCode,
        reason: connection?.closeReason,
      );
    }
    realtimeLogger.fine('Connection closed: $event');

    /// SocketState.disconnected: by user with socket.disconnect()
    /// SocketState.closed: NOT by user, should try to reconnect
    if (connectionState == SocketState.closed) {
      _triggerChanError(event);
      reconnectTimer.scheduleTimeout();
    }
    if (heartbeatTimer != null) heartbeatTimer!.cancel();
    _statusController.add(
      RealtimeConnectionStatusChange(RealtimeConnectionStatus.closed, event),
    );
  }

  void _onConnectionError(Object error) {
    realtimeLogger.warning('Connection error', error);
    _triggerChanError(error);
    _statusController.addError(error);
  }

  void _triggerChanError([dynamic error]) {
    for (final channel in channels) {
      channel.trigger(ChannelEvent.error.eventName(), error);
    }
  }

  String _appendParameters(String url, Map<String, String> queryParameters) {
    if (queryParameters.keys.isEmpty) {
      return url;
    }

    var uri = Uri.parse(url);
    uri = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...queryParameters,
      },
    );

    return uri.toString();
  }

  void _flushSendBuffer() {
    if (isConnected && sendBuffer.isNotEmpty) {
      for (final callback in sendBuffer) {
        callback();
      }
      sendBuffer = [];
    }
  }

  /// Resolves the access token before flushing the send buffer so that
  /// buffered channel join payloads carry the correct token.
  ///
  /// When [RealtimeChannel.subscribe] runs before an asynchronous access token
  /// has resolved (common when [customAccessToken] reads from async storage),
  /// the buffered join payload has no `access_token`. That buffered message
  /// captured the stale payload, so once auth has settled the join payloads are
  /// patched with the resolved token, the stale buffered joins are dropped, and
  /// the join is re-sent for any channel still joining.
  Future<void> _resolveAccessTokenAndFlush() async {
    try {
      if (customAccessToken != null) {
        await setAccessToken(null);
        if (accessToken != null) {
          for (final channel in channels) {
            channel.updateJoinPayload({'access_token': accessToken!});
          }
          sendBuffer = [];
          for (final channel in channels) {
            if (channel.isJoining) {
              channel.forceRejoin();
            }
          }
        }
      }
    } catch (error) {
      realtimeLogger.warning(
        'Error resolving access token on connect',
        error,
      );
    } finally {
      _flushSendBuffer();
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
      realtimeLogger.warning(
        'Heartbeat timeout, attempting to re-establish connection',
      );
      _heartbeatController.add(RealtimeHeartbeatStatus.timeout);
      unawaited(
        connection?.sink.close(
          RealtimeConstants.webSocketCloseNormal,
          'heartbeat timeout',
        ),
      );
      return;
    }
    pendingHeartbeatRef = makeRef();
    push(
      RealtimeMessage.outgoing(
        topic: 'phoenix',
        event: ChannelEvent.heartbeat,
        payload: {},
        ref: pendingHeartbeatRef!,
      ),
    );
    _heartbeatController.add(RealtimeHeartbeatStatus.sent);
    await setAccessToken(accessToken);
  }
}
