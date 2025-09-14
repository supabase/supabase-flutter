import 'package:supabase/src/version.dart';
import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart'
    as cond_platform;

class Constants {
  static String? get platform => cond_platform.platform;
  static String? get platformVersion => cond_platform.platformVersion;

  static final Map<String, String> defaultHeaders = {
    'X-Client-Info': 'supabase-dart/$version',
    if (platform != null)
      'X-Supabase-Client-Platform':
          Uri.encodeFull(platform!).replaceAll("%20", " "),
    if (platformVersion != null)
      'X-Supabase-Client-Platform-Version':
          Uri.encodeFull(platformVersion!).replaceAll("%20", " "),
  };
}
