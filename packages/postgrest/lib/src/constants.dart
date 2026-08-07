import 'package:postgrest/src/version.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:meta/meta.dart';

@internal
final defaultHeaders = {
  'X-Client-Info': buildClientInfoHeader('postgrest-dart', version),
};
