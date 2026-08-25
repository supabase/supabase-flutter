import 'package:supabase_common/supabase_common.dart';
import 'package:meta/meta.dart';

export 'package:supabase_common/supabase_common.dart' show FetchOptions;

@internal
class AuthRequestOptions extends FetchOptions {
  AuthRequestOptions({
    this.jwt,
    this.redirectTo,
    this.body,
    this.query,
    required Map<String, String> headers,
    bool? noResolveJson,
  }) : super(headers, noResolveJson: noResolveJson);
  final String? jwt;
  final String? redirectTo;
  final Map<String, dynamic>? body;
  final Map<String, String>? query;
}
