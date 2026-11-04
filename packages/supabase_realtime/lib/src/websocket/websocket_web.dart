import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:meta/meta.dart';

@internal
WebSocketChannel createWebSocketClient(
  String url,
  Map<String, String> headers,
) {
  // Deliver binary frames as `Uint8List` (arraybuffer) so protocol 2.0.0
  // binary frames can be decoded synchronously.
  return HtmlWebSocketChannel.connect(url, binaryType: BinaryType.list);
}

/// Always `null`: the platform does not expose the HTTP status of a refused
/// WebSocket upgrade.
@internal
int? refusedUpgradeStatusCode(Object error) => null;
