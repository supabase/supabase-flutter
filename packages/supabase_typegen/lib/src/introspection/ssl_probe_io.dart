import 'dart:async';
import 'dart:io';

const _timeout = Duration(seconds: 10);

/// The `SSLRequest` message of the Postgres wire protocol: a length of 8
/// followed by the request code 80877103.
const _sslRequest = [0, 0, 0, 8, 0x04, 0xd2, 0x16, 0x2f];

/// Asks the Postgres server at [host] and [port] whether it accepts TLS, the
/// way libpq's `sslmode=prefer` does before it opens the real connection: it
/// sends an `SSLRequest` and reads the one byte answer, `S` for yes and `N`
/// for no, then drops the probe connection.
Future<bool> serverSupportsSsl(String host, int port) async {
  final socket = await Socket.connect(host, port, timeout: _timeout);
  try {
    socket.add(_sslRequest);
    await socket.flush();
    final answer = await socket.first.timeout(_timeout);
    return answer.isNotEmpty && answer.first == 'S'.codeUnitAt(0);
  } finally {
    socket.destroy();
  }
}
