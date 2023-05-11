import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createWebSocketClient(
  String url,
  Map<String, String> headers,
) {
  return IOWebSocketChannel.connect(url, headers: headers);
}
