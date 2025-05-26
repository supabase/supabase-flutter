import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

http.Client getPlatformHttpClient() {
  return http.Client();
}

WebSocketChannel? getPlatformWebSocketChannel(String url) {
  return null;
}
