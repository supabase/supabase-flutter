import 'package:realtime_client/src/version.dart';
import 'package:supabase_common/supabase_common.dart';

class Constants {
  static const Duration defaultTimeout = Duration(milliseconds: 10000);
  static const int defaultHeartbeatIntervalMs = 25000;
  static const int wsCloseNormal = 1000;
  static final Map<String, String> defaultHeaders = {
    'X-Client-Info': buildClientInfoHeader('realtime-dart', version),
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

  String eventName() => switch (this) {
    ChannelEvents.accessToken => 'access_token',
    ChannelEvents.postgresChanges => 'postgres_changes',
    ChannelEvents.broadcast => 'broadcast',
    ChannelEvents.presence => 'presence',
    ChannelEvents.close ||
    ChannelEvents.error ||
    ChannelEvents.join ||
    ChannelEvents.reply ||
    ChannelEvents.leave ||
    ChannelEvents.heartbeat => 'phx_$name',
  };
}

class Transports {
  static const String websocket = 'websocket';
}

enum RealtimeLogLevel { info, debug, warn, error }
