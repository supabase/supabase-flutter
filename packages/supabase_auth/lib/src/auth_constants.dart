import 'package:supabase_auth/src/version.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

@internal
class AuthConstants {
  static const String defaultAuthUrl = 'http://localhost:9999';
  static final Map<String, String> defaultHeaders = {
    'X-Client-Info': buildClientInfoHeader('gotrue-dart', version),
  };

  /// storage key prefix to store code verifiers
  static const String defaultStorageKey = 'supabase.auth.token';

  /// Maximum number of PKCE code verifiers kept in storage at once. Starting
  /// another flow beyond this evicts the oldest pending verifier.
  static const int pkceMaxConcurrentFlows = 5;

  /// The margin to use when checking if a token is expired.
  static const expiryMargin = Duration(seconds: 30);

  /// Current session will be checked for refresh at this interval.
  static const autoRefreshTickDuration = Duration(seconds: 10);

  /// A token refresh will be attempted this many ticks before the current
  /// session expires.
  static const autoRefreshTickThreshold = 3;

  /// The name of the header that contains API version.
  static const apiVersionHeaderName = 'x-supabase-api-version';

  /// The API version this client speaks, sent on every request.
  static const apiVersion = '2024-01-01';

  /// The TTL for the JWKS cache.
  static const jwksTtl = Duration(minutes: 10);
}
