/// A dart client library for Supabase Auth.
library;

export 'package:supabase_common/supabase_common.dart'
    show SupabaseApiException, SupabaseException;

export 'src/constants.dart' hide Constants;
export 'src/auth_admin_api.dart';
export 'src/auth_client.dart';
export 'src/helper.dart' show decodeJwt, validateExp;
export 'src/types/auth_exception.dart';
export 'src/types/auth_response.dart';
export 'src/types/auth_state.dart';
export 'src/types/custom_oauth_provider.dart';
export 'src/types/error_code.dart';
export 'src/types/auth_async_storage.dart';
export 'src/types/jwt.dart';
export 'src/auth_admin_passkey_api.dart';
export 'src/types/mfa.dart';
export 'src/types/passkey.dart';
export 'src/types/sign_out_reason.dart';
export 'src/types/types.dart';
export 'src/types/session.dart';
export 'src/types/user.dart';
export 'src/types/user_attributes.dart';
