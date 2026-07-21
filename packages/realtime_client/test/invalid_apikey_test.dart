@Tags(['integration'])
library;

import 'dart:async';

import 'package:realtime_client/realtime_client.dart';
import 'package:test/test.dart';

import 'utils/realtime_test_utils.dart';

/// A rejected WebSocket upgrade (for example an invalid apikey) should surface
/// a [RealtimeConnectException] carrying the server's status code on native
/// platforms, instead of a bare `WebSocketChannelException` with only a status
/// code buried in its message.
void main() {
  test('invalid apikey surfaces a RealtimeConnectException', () async {
    final client = RealtimeClient(
      realtimeUrl,
      version: RealtimeProtocolVersion.v1,
      params: {'apikey': 'INVALID_TEST'},
      heartbeatIntervalMs: 5000,
    );

    final error = Completer<Object?>();
    client.onError((e) {
      if (!error.isCompleted) error.complete(e);
    });

    final channel = client.channel('invalid-apikey-check');
    channel.subscribe((status, subscribeError) {
      if (status == RealtimeSubscribeStatus.channelError &&
          subscribeError != null &&
          !error.isCompleted) {
        error.complete(subscribeError);
      }
    });

    final received = await error.future.timeout(const Duration(seconds: 15));

    expect(received, isA<RealtimeConnectException>());
    final exception = received as RealtimeConnectException;
    expect(exception.statusCode, anyOf(401, 403));

    await client.removeAllChannels();
    await client.disconnect();
  });
}
