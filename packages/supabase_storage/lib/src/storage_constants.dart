import 'package:supabase_storage/src/version.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:meta/meta.dart';

@internal
class StorageConstants {
  static final Map<String, String> defaultHeaders = {
    'X-Client-Info': buildClientInfoHeader('storage-dart', version),
  };
}
