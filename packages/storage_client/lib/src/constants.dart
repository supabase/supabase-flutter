import 'package:storage_client/src/version.dart';
import 'package:supabase_common/supabase_common.dart';

class Constants {
  static final Map<String, String> defaultHeaders = {
    'X-Client-Info': buildClientInfoHeader('storage-dart', version),
  };
}
