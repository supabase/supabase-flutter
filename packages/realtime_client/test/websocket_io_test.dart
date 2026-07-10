@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:realtime_client/src/websocket/websocket_io.dart';
import 'package:test/test.dart';

/// Minimal WebSocket server that completes the opening handshake but never
/// replies to control frames, so it can simulate a peer that has silently gone
/// away (for example a mobile device that lost connectivity).
Future<ServerSocket> _startUnresponsiveServer() async {
  final server = await ServerSocket.bind('localhost', 0);
  server.listen((socket) {
    final buffer = StringBuffer();
    late StreamSubscription<dynamic> subscription;
    subscription = socket.listen((data) {
      buffer.write(String.fromCharCodes(data));
      final request = buffer.toString();
      if (!request.contains('\r\n\r\n')) {
        return;
      }
      final keyLine = request
          .split('\r\n')
          .firstWhere(
            (line) => line.toLowerCase().startsWith('sec-websocket-key:'),
          );
      final key = keyLine.split(':').last.trim();
      final accept = base64.encode(
        sha1
            .convert(utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
            .bytes,
      );
      socket.write(
        'HTTP/1.1 101 Switching Protocols\r\n'
        'Upgrade: websocket\r\n'
        'Connection: Upgrade\r\n'
        'Sec-WebSocket-Accept: $accept\r\n\r\n',
      );
      // From here on, deliberately ignore everything (including ping frames).
      subscription.onData((_) {});
    });
  });
  return server;
}

void main() {
  test(
    'default transport closes the connection when the peer stops responding',
    () async {
      final server = await _startUnresponsiveServer();
      addTearDown(() => server.close());

      final channel = createWebSocketClient(
        'ws://localhost:${server.port}',
        const {},
        pingInterval: const Duration(milliseconds: 200),
      );
      await channel.ready;

      // Without a transport level ping interval this would never complete, since
      // the dead peer sends neither data nor a close frame.
      await channel.stream.drain().timeout(const Duration(seconds: 5));
    },
  );
}
