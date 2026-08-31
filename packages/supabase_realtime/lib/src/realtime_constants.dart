import 'package:meta/meta.dart';
import 'package:supabase_realtime/src/version.dart';
import 'package:supabase_common/supabase_common.dart';

/// Default values used by [RealtimeClient].
class RealtimeConstants {
  /// The default [RealtimeClient.timeout].
  static const Duration defaultTimeout = Duration(milliseconds: 10000);

  /// The default [RealtimeClient.connectionCloseTimeout].
  static const Duration defaultConnectionCloseTimeout = Duration(seconds: 6);

  /// The default [RealtimeClient.heartbeatInterval].
  static const Duration defaultHeartbeatInterval = Duration(seconds: 25);

  /// The WebSocket close code for a normal, expected closure.
  @internal
  static const int webSocketCloseNormal = 1000;

  /// The `X-Client-Info` header sent on every connection.
  @internal
  static final Map<String, String> defaultHeaders = {
    'X-Client-Info': buildClientInfoHeader('realtime-dart', version),
  };
}
