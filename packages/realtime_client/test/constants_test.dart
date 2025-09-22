import 'package:realtime_client/src/constants.dart';
import 'package:test/test.dart';

void main() {
  group('Constants', () {
    test('has correct values', () {
      expect(Constants.vsn, '1.0.0');
      expect(Constants.defaultTimeout.inMilliseconds, 10000);
      expect(Constants.defaultHeartbeatIntervalMs, 25000);
      expect(Constants.wsCloseNormal, 1000);
      expect(Constants.defaultHeaders, isA<Map<String, String>>());
      expect(Constants.defaultHeaders.containsKey('X-Client-Info'), isTrue);
    });
  });

  group('ChannelEventsExtended', () {
    test('conversion methods work correctly', () {
      // fromType with names
      expect(ChannelEventsExtended.fromType('close'), ChannelEvents.close);
      expect(ChannelEventsExtended.fromType('error'), ChannelEvents.error);

      // fromType with eventNames
      expect(ChannelEventsExtended.fromType('phx_close'), ChannelEvents.close);
      expect(ChannelEventsExtended.fromType('access_token'),
          ChannelEvents.accessToken);
      expect(ChannelEventsExtended.fromType('postgres_changes'),
          ChannelEvents.postgresChanges);

      // eventName returns
      expect(ChannelEvents.close.eventName(), 'phx_close');
      expect(ChannelEvents.accessToken.eventName(), 'access_token');
      expect(ChannelEvents.postgresChanges.eventName(), 'postgres_changes');

      // Invalid type throws
      expect(
          () => ChannelEventsExtended.fromType('invalid_type'),
          throwsA(isA<String>().having(
              (s) => s, 'error', contains('No type invalid_type exists'))));
    });
  });

  group('Transports', () {
    test('has correct websocket value', () {
      expect(Transports.websocket, 'websocket');
    });
  });
}
