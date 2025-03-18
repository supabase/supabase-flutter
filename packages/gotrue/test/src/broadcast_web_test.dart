@TestOn('browser')
import 'dart:async';

import 'package:gotrue/src/broadcast_web.dart';
import 'package:gotrue/src/types/types.dart';
import 'package:test/test.dart';

void main() {
  group('getBroadcastChannel', () {
    late BroadcastChannel channel1;
    late BroadcastChannel channel2;

    setUp(() {
      channel1 = getBroadcastChannel('test-channel');
      channel2 = getBroadcastChannel('test-channel');
    });

    tearDown(() {
      channel1.close();
      channel2.close();
    });

    test('can send and receive messages between channels', () async {
      final completer = Completer<Map<String, dynamic>>();

      // Listen for messages on channel2
      final subscription = channel2.onMessage.listen((message) {
        completer.complete(message);
      });

      // Send message from channel1
      final testMessage = {
        'event': 'test-event',
        'data': {'foo': 'bar'}
      };
      channel1.postMessage(testMessage);

      // Wait for the message to be received
      final receivedMessage = await completer.future;

      expect(receivedMessage['event'], equals('test-event'));
      expect(receivedMessage['data']['foo'], equals('bar'));

      await subscription.cancel();
    });

    test('can close channels', () async {
      channel1.close();

      // Verify that sending messages after closing throws
      expect(
        () => channel1.postMessage({'event': 'test'}),
        throwsA(anything),
      );
    });
  });
}
