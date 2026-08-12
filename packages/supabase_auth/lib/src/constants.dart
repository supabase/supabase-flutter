import 'package:supabase_auth/src/version.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

@internal
class Constants {
  static const String defaultAuthUrl = 'http://localhost:9999';
  static final Map<String, String> defaultHeaders = {
    'X-Client-Info': buildClientInfoHeader('gotrue-dart', version),
  };

  /// storage key prefix to store code verifiers
  static const String defaultStorageKey = 'supabase.auth.token';

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

enum AuthChangeEvent {
  initialSession('INITIAL_SESSION'),
  passwordRecovery('PASSWORD_RECOVERY'),
  signedIn('SIGNED_IN'),
  signedOut('SIGNED_OUT'),
  tokenRefreshed('TOKEN_REFRESHED'),
  userUpdated('USER_UPDATED'),
  mfaChallengeVerified('MFA_CHALLENGE_VERIFIED');

  final String jsName;
  const AuthChangeEvent(this.jsName);

  @internal
  static AuthChangeEvent? fromString(String? val) {
    for (final event in AuthChangeEvent.values) {
      if (event.name == val) {
        return event;
      }
    }
    return null;
  }
}

enum GenerateLinkType {
  signup,
  invite,
  magiclink,
  recovery,
  emailChangeCurrent,
  emailChangeNew,
  unknown;

  @internal
  static GenerateLinkType fromString(String? val) {
    for (final type in GenerateLinkType.values) {
      if (type.snakeCase == val) {
        return type;
      }
    }
    return GenerateLinkType.unknown;
  }
}

enum OtpType {
  sms,
  phoneChange,
  signup,
  invite,
  magiclink,
  recovery,
  emailChange,
  email,
}

/// Messaging channel to use (e.g. whatsapp or sms)
enum OtpChannel {
  sms,
  whatsapp,
}

/// The blockchain used to sign in with a Web3 wallet.
enum Web3Chain {
  ethereum,
  solana,
}

/// Determines which sessions should be logged out.
enum SignOutScope {
  /// All sessions by this account will be signed out.
  global,

  /// Only this session will be signed out.
  local,

  /// All other sessions except the current one will be signed out. When using
  /// others, there is no [AuthChangeEvent.signedOut] event fired on the current
  /// session!
  others,
}
