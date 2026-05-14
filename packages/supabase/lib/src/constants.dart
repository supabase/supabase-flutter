import 'package:supabase/src/version.dart';
import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';

class Constants {
  static String? get platform => condPlatform;
  static String? get platformVersion => condPlatformVersion;

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
