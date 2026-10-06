import 'package:postgrest/src/version.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:meta/meta.dart';

@internal
final defaultHeaders = {
  HttpHeader.clientInfo: buildClientInfoHeader('postgrest-dart', version),
};
