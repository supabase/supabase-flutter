import 'package:supabase_dart/src/version.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:meta/meta.dart';

@internal
class SupabaseConstants {
  static final Map<String, String> defaultHeaders = Map.unmodifiable({
    'X-Client-Info': buildClientInfoHeader(
      'supabase-dart',
      version,
      platformInfo: PlatformInfo(
        platform: conditionalPlatform,
        platformVersion: conditionalPlatformVersion,
        runtimeVersion: conditionalRuntimeVersion,
      ),
    ),
  });
}
