import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'realtime_connect_exception.dart';

/// Interval for the native WebSocket to send protocol-level ping frames.
///
/// When a pong is not received within this interval the connection is assumed
/// dead and closed, which makes silently dropped connections (common on iOS,
/// where the OS buffers writes instead of surfacing a TCP reset) detectable and
/// keeps disconnect behavior consistent across platforms. Aligned with the
/// app-level heartbeat cadence of 25 seconds.
const _defaultWebSocketPingInterval = Duration(seconds: 25);

/// GUID from RFC 6455 used to derive the `Sec-WebSocket-Accept` response value.
const _webSocketGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

WebSocketChannel createWebSocketClient(
  String url,
  Map<String, String> headers, {
  Duration? pingInterval = _defaultWebSocketPingInterval,
}) {
  // Drive the upgrade manually instead of using [IOWebSocketChannel.connect] /
  // [WebSocket.connect]. Those discard the HTTP response on a non-101 status,
  // which hides the server's error body (for example the "Invalid API key"
  // message and hint returned for a bad apikey). Doing the handshake by hand
  // keeps the response in scope so a rejected upgrade surfaces a
  // [RealtimeConnectException] with the reason, in the same request.
  final uri = Uri.parse(url);
  final httpUri = uri.replace(
    scheme: switch (uri.scheme) {
      'wss' => 'https',
      'ws' => 'http',
      'https' || 'http' => uri.scheme,
      // Match [WebSocket.connect], which rejects unsupported schemes
      // synchronously with a [WebSocketException].
      final scheme => throw WebSocketException(
        "Unsupported URL scheme '$scheme'",
      ),
    },
  );
  return IOWebSocketChannel(_connect(httpUri, headers, pingInterval));
}

Future<WebSocket> _connect(
  Uri httpUri,
  Map<String, String> headers,
  Duration? pingInterval,
) async {
  final nonce = base64.encode(
    List<int>.generate(16, (_) => Random.secure().nextInt(256)),
  );

  final client = HttpClient();
  try {
    final request = await client.openUrl('GET', httpUri);
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    request.headers
      ..set(HttpHeaders.connectionHeader, 'Upgrade')
      ..set(HttpHeaders.upgradeHeader, 'websocket')
      ..set('Sec-WebSocket-Version', '13')
      ..set('Sec-WebSocket-Key', nonce);

    final response = await request.close();

    if (response.statusCode != HttpStatus.switchingProtocols) {
      final body = await response.transform(utf8.decoder).join();
      throw _exceptionFromResponse(
        response.statusCode,
        response.headers.value('sb-error-code'),
        body,
      );
    }

    _validateAccept(response.headers.value('sec-websocket-accept'), nonce);

    final socket = await response.detachSocket();
    return WebSocket.fromUpgradedSocket(socket, serverSide: false)
      ..pingInterval = pingInterval;
  } finally {
    client.close();
  }
}

void _validateAccept(String? accept, String nonce) {
  final expected = base64.encode(
    sha1.convert(utf8.encode('$nonce$_webSocketGuid')).bytes,
  );
  if (accept != expected) {
    throw const WebSocketException(
      'WebSocket upgrade returned an invalid Sec-WebSocket-Accept header',
    );
  }
}

RealtimeConnectException _exceptionFromResponse(
  int statusCode,
  String? errorCode,
  String body,
) {
  String? message;
  String? hint;
  if (body.isNotEmpty) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        message = decoded['message'] as String?;
        hint = decoded['hint'] as String?;
      } else {
        message = body;
      }
    } catch (_) {
      message = body;
    }
  }
  return RealtimeConnectException(
    statusCode: statusCode,
    message: message,
    hint: hint,
    errorCode: errorCode,
  );
}
