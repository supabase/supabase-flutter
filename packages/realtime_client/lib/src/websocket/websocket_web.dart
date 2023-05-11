import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createWebSocketClient(
  String url,
  Map<String, String> headers,
) {
  return HtmlWebSocketChannel.connect(url);
}
