import 'package:supabase/src/version.dart';
import 'dart:io' show Platform;

const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');

class Constants {
  static String? get platform {
    return kIsWeb ? null : Platform.operatingSystem;
  }

  static String? get platformVersion {
    return kIsWeb ? null : Platform.operatingSystemVersion;
  }

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
