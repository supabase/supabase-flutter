import 'package:supabase/src/version.dart';
import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';

class Constants {
  static String? get platform => condPlatform;
  static String? get platformVersion => condPlatformVersion;
  static String? get runtimeVersion => condRuntimeVersion;

  static final Map<String, String> defaultHeaders = {
    'X-Client-Info': [
      'supabase-dart/$version',
      if (platform != null) 'platform=$platform',
      if (platformVersion != null)
        'platform-version=${Uri.encodeFull(platformVersion!).replaceAll("%20", " ")}',
      'runtime=dart',
      if (runtimeVersion != null) 'runtime-version=$runtimeVersion',
    ].join('; '),
  };
}
