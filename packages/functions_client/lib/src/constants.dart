import 'package:functions_client/src/version.dart';
import 'package:supabase_common/supabase_common.dart';

class Constants {
  static final defaultHeaders = {
    'X-Client-Info': buildClientInfoHeader('functions-dart', version),
  };
}
