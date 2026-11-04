import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:meta/meta.dart';

@internal
WebSocketChannel createWebSocketClient(
  String url,
  Map<String, String> headers,
) {
  throw UnimplementedError(
    'Websocket Client not implemented for this platform',
  );
}

/// Always `null`: the platform does not expose the HTTP status of a refused
/// WebSocket upgrade.
@internal
int? refusedUpgradeStatusCode(Object error) => null;
