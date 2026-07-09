import 'package:supabase_common/supabase_common.dart';
import 'package:supabase_flutter/src/version.dart';

class Constants {
  static final Map<String, String> defaultHeaders = Map.unmodifiable({
    'X-Client-Info': buildClientInfoHeader(
      'supabase-flutter',
      version,
      platformInfo: PlatformInfo(
        platform: conditionalPlatform,
        platformVersion: conditionalPlatformVersion,
        runtimeVersion: conditionalRuntimeVersion,
      ),
    ),
  });
}
