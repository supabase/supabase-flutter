import 'package:supabase_flutter/src/version.dart';

import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';

class Constants {
  static final Map<String, String> defaultHeaders = Map.unmodifiable({
    'X-Client-Info': [
      'supabase-flutter/$version',
      if (conditionalPlatform != null) 'platform=$conditionalPlatform',
      if (conditionalPlatformVersion != null)
        'platform-version=${Uri.encodeFull(conditionalPlatformVersion!).replaceAll("%20", " ")}',
      'runtime=dart',
      if (conditionalRuntimeVersion != null) 'runtime-version=$conditionalRuntimeVersion',
    ].join('; '),
  });
}
