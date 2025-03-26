import 'package:supabase/src/version.dart';
import 'dart:io' show Platform;

class Constants {
  static String get platform {
    return Platform.operatingSystem;
  }

  static String get platformVersion {
    return Platform.operatingSystemVersion;
  }

  static final Map<String, String> defaultHeaders = {
    'X-Client-Info': 'supabase-dart/$version',
    'X-Supabase-Client-Platform': platform,
    'X-Supabase-Client-Platform-Version': platformVersion,
  };
}
