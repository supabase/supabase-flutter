import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Interval for the native WebSocket to send protocol-level ping frames.
///
/// When a pong is not received within this interval the connection is assumed
/// dead and closed, which makes silently dropped connections (common on iOS,
/// where the OS buffers writes instead of surfacing a TCP reset) detectable and
/// keeps disconnect behavior consistent across platforms. Aligned with the
/// app-level heartbeat cadence of 25 seconds.
const _defaultWebSocketPingInterval = Duration(seconds: 25);

WebSocketChannel createWebSocketClient(
  String url,
  Map<String, String> headers, {
  Duration? pingInterval = _defaultWebSocketPingInterval,
}) {
  return IOWebSocketChannel.connect(
    url,
    headers: headers,
    pingInterval: pingInterval,
  );
}
