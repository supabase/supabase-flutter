import 'package:supabase/src/constants.dart' as supabase_constants;
import 'package:supabase_flutter/src/version.dart';

class Constants {
  static Map<String, String> get defaultHeaders => {
        'X-Client-Info': [
          'supabase-flutter/$version',
          if (supabase_constants.Constants.platform != null)
            'platform=${supabase_constants.Constants.platform}',
          if (supabase_constants.Constants.platformVersion != null)
            'platform-version=${Uri.encodeFull(supabase_constants.Constants.platformVersion!).replaceAll("%20", " ")}',
          'runtime=dart',
          if (supabase_constants.Constants.runtimeVersion != null)
            'runtime-version=${supabase_constants.Constants.runtimeVersion}',
        ].join('; '),
      };
}
