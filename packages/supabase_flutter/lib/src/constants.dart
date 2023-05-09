import 'package:supabase_flutter/src/version.dart';

class Constants {
  static const Map<String, String> defaultHeaders = {
    'X-Client-Info': 'supabase-flutter/$version',
  };
}
