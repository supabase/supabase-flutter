import 'package:supabase/src/version.dart';

class Constants {
  static const Map<String, String> defaultHeaders = {
    'X-Client-Info': 'supabase-dart/$version',
  };
}
