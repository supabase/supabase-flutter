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

  group('RealtimeConstants', () {
    test('is type alias for Constants', () {
      expect(RealtimeConstants.vsn, Constants.vsn);
    });
  });

  group('SocketStates', () {
    test('enum values exist', () {
      expect(SocketStates.connecting, isNotNull);
      expect(SocketStates.open, isNotNull);
      expect(SocketStates.disconnecting, isNotNull);
      expect(SocketStates.closed, isNotNull);
      expect(SocketStates.disconnected, isNotNull);
    });
  });

  group('ChannelStates', () {
    test('enum values exist', () {
      expect(ChannelStates.closed, isNotNull);
      expect(ChannelStates.errored, isNotNull);
      expect(ChannelStates.joined, isNotNull);
      expect(ChannelStates.joining, isNotNull);
      expect(ChannelStates.leaving, isNotNull);
    });
  });

  group('ChannelEvents', () {
    test('enum values exist', () {
      expect(ChannelEvents.close, isNotNull);
      expect(ChannelEvents.error, isNotNull);
      expect(ChannelEvents.join, isNotNull);
      expect(ChannelEvents.reply, isNotNull);
      expect(ChannelEvents.leave, isNotNull);
      expect(ChannelEvents.heartbeat, isNotNull);
      expect(ChannelEvents.accessToken, isNotNull);
      expect(ChannelEvents.broadcast, isNotNull);
      expect(ChannelEvents.presence, isNotNull);
      expect(ChannelEvents.postgresChanges, isNotNull);
    });
  });

  group('ChannelEventsExtended', () {
    test('fromType returns correct enum from name', () {
      expect(ChannelEventsExtended.fromType('close'), ChannelEvents.close);
      expect(ChannelEventsExtended.fromType('error'), ChannelEvents.error);
      expect(ChannelEventsExtended.fromType('join'), ChannelEvents.join);
    });

    test('fromType returns correct enum from eventName', () {
      expect(ChannelEventsExtended.fromType('phx_close'), ChannelEvents.close);
      expect(ChannelEventsExtended.fromType('phx_error'), ChannelEvents.error);
      expect(ChannelEventsExtended.fromType('access_token'),
          ChannelEvents.accessToken);
      expect(ChannelEventsExtended.fromType('postgres_changes'),
          ChannelEvents.postgresChanges);
      expect(
          ChannelEventsExtended.fromType('broadcast'), ChannelEvents.broadcast);
      expect(
          ChannelEventsExtended.fromType('presence'), ChannelEvents.presence);
    });

    test('fromType throws for invalid type', () {
      expect(
          () => ChannelEventsExtended.fromType('invalid_type'),
          throwsA(isA<String>().having(
              (s) => s, 'error', contains('No type invalid_type exists'))));
    });

    test('eventName returns correct string', () {
      expect(ChannelEvents.close.eventName(), 'phx_close');
      expect(ChannelEvents.error.eventName(), 'phx_error');
      expect(ChannelEvents.join.eventName(), 'phx_join');
      expect(ChannelEvents.reply.eventName(), 'phx_reply');
      expect(ChannelEvents.leave.eventName(), 'phx_leave');
      expect(ChannelEvents.heartbeat.eventName(), 'phx_heartbeat');
      expect(ChannelEvents.accessToken.eventName(), 'access_token');
      expect(ChannelEvents.postgresChanges.eventName(), 'postgres_changes');
      expect(ChannelEvents.broadcast.eventName(), 'broadcast');
      expect(ChannelEvents.presence.eventName(), 'presence');
    });
  });

  group('Transports', () {
    test('has correct websocket value', () {
      expect(Transports.websocket, 'websocket');
    });
  });

  group('RealtimeLogLevel', () {
    test('enum values exist', () {
      expect(RealtimeLogLevel.info, isNotNull);
      expect(RealtimeLogLevel.debug, isNotNull);
      expect(RealtimeLogLevel.warn, isNotNull);
      expect(RealtimeLogLevel.error, isNotNull);
    });
  });
}
