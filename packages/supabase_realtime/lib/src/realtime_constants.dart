import 'package:meta/meta.dart';
import 'package:supabase_realtime/src/version.dart';
import 'package:supabase_common/supabase_common.dart';

class RealtimeConstants {
  static const Duration defaultTimeout = Duration(milliseconds: 10000);
  static const Duration defaultConnectionCloseTimeout = Duration(seconds: 6);
  static const Duration defaultHeartbeatInterval = Duration(seconds: 25);

  @internal
  static const int webSocketCloseNormal = 1000;

  @internal
  static final Map<String, String> defaultHeaders = {
    'X-Client-Info': buildClientInfoHeader('realtime-dart', version),
  };
}
