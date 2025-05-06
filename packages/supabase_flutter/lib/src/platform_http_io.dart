import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/adapter_web_socket_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// For iOS and macOS this returns a `CupertinoClient` and [http.Client] for the
/// rest of the platforms.
///
/// This is used to make HTTP requests use the platform's native HTTP client.
http.Client getPlatformHttpClient() {
  if (Platform.isIOS || Platform.isMacOS) {
    return CupertinoClient.defaultSessionConfiguration();
  } else {
    return http.Client();
  }
}

/// For iOS and macOS this returns a `CupertinoWebSocket` wrapped in a
/// `AdapterWebSocketChannel` and `null` for the rest of the platforms.
///
/// It may return `null` because the differentiation for the other platforms
/// is done in [RealtimeClient].
WebSocketChannel Function(String url)? getPlatformWebSocketChannel() {
  if (Platform.isIOS || Platform.isMacOS) {
    return (String url) =>
        AdapterWebSocketChannel(CupertinoWebSocket.connect(Uri.parse(url)));
  }
  return null;
}
