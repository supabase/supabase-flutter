import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createWebSocketClient(
  String url,
  Map<String, String> headers,
) {
  // Deliver binary frames as `Uint8List` (arraybuffer) so protocol 2.0.0
  // binary frames can be decoded synchronously.
  return HtmlWebSocketChannel.connect(url, binaryType: BinaryType.list);
}
