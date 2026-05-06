import 'package:supabase_flutter/src/version.dart';

import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';

class Constants {
  static Map<String, String> get defaultHeaders => {
        'X-Client-Info': [
          'supabase-flutter/$version',
          if (condPlatform != null) 'platform=$condPlatform',
          if (condPlatformVersion != null)
            'platform-version=${Uri.encodeFull(condPlatformVersion!).replaceAll("%20", " ")}',
          'runtime=dart',
          if (condRuntimeVersion != null) 'runtime-version=$condRuntimeVersion',
        ].join('; '),
      };
}
