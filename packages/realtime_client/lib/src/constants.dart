import 'package:realtime_client/src/version.dart';

class Constants {
  static const Duration defaultTimeout = Duration(milliseconds: 10000);
  static const int defaultHeartbeatIntervalMs = 25000;

  /// Interval for transport level WebSocket ping frames on platforms that
  /// support them.
  ///
  /// If a ping is not answered by a pong within this interval the connection is
  /// considered dead and closed, so that dropped connections are detected
  /// consistently across platforms instead of lingering as half open sockets.
  static const Duration defaultWebSocketPingInterval = Duration(seconds: 30);
  static const int wsCloseNormal = 1000;
  static const Map<String, String> defaultHeaders = {
    'X-Client-Info': 'realtime-dart/$version',
  };
}

typedef RealtimeConstants = Constants;

enum RealtimeProtocolVersion {
  /// Legacy protocol: object-shaped JSON text frames only.
  v1('1.0.0'),

  /// Positional JSON array text frames plus binary frames.
  v2('2.0.0');

  const RealtimeProtocolVersion(this.vsn);

  /// The value sent as the `vsn` connection parameter.
  final String vsn;
}

enum SocketStates {
  /// Client attempting to establish a connection
  connecting,

  /// Connection is live and connected
  open,

  /// Socket is closing by the user
  disconnecting,

  /// Socket being close not by the user. Realtime should attempt to reconnect.
  closed,

  /// Socket being closed by the user
  disconnected,
}

enum ChannelStates { closed, errored, joined, joining, leaving }

enum ChannelEvents {
  close,
  error,
  join,
  reply,
  leave,
  heartbeat,
  accessToken,
  broadcast,
  presence,
  postgresChanges,
}

extension ChannelEventsExtended on ChannelEvents {
  static ChannelEvents fromType(String type) {
    for (ChannelEvents enumVariant in ChannelEvents.values) {
      if (enumVariant.name == type || enumVariant.eventName() == type) {
        return enumVariant;
      }
    }
    throw 'No type $type exists';
  }

  String eventName() {
    if (this == ChannelEvents.accessToken) {
      return 'access_token';
    } else if (this == ChannelEvents.postgresChanges) {
      return 'postgres_changes';
    } else if (this == ChannelEvents.broadcast) {
      return 'broadcast';
    } else if (this == ChannelEvents.presence) {
      return 'presence';
    }
    return 'phx_$name';
  }
}

class Transports {
  static const String websocket = 'websocket';
}

enum RealtimeLogLevel { info, debug, warn, error }
