import 'package:supabase_functions/src/version.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:meta/meta.dart';

@internal
class FunctionsConstants {
  static final defaultHeaders = {
    HttpHeader.clientInfo: buildClientInfoHeader('functions-dart', version),
  };
}
