import 'package:gotrue/src/types/auth_response.dart';
import 'package:gotrue/src/version.dart';

class Constants {
  static const String defaultGotrueUrl = 'http://localhost:9999';
  static const String defaultAudience = '';
  static const Map<String, String> defaultHeaders = {
    'X-Client-Info': 'gotrue-dart/$version',
  };
  static const int defaultExpiryMargin = 60 * 1000;

  /// storage key prefix to store code verifiers
  static const String defaultStorageKey = 'supabase.auth.token';
  static const expiryMargin = Duration(seconds: 10);
  static const int maxRetryCount = 10;
  static const retryInterval = Duration(milliseconds: 200);
}

enum AuthChangeEvent {
  initialSession,
  passwordRecovery,
  signedIn,
  signedOut,
  tokenRefreshed,
  userUpdated,
  userDeleted,
  mfaChallengeVerified,
}

extension AuthChangeEventExtended on AuthChangeEvent {
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
  unknown,
}

extension GenerateLinkTypeExtended on GenerateLinkType {
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
  email
}

/// Messaging channel to use (e.g. whatsapp or sms)
enum OtpChannel {
  sms,
  whatsapp,
}

/// Determines which sessions should be logged out.
enum SignOutScope {
  /// All sessions by this account will be signed out.
  global,

  /// Only this session will be signed out.
  local,

  /// All other sessions except the current one will be signed out. When using others, there is no [AuthChangeEvent.signedOut] event fired on the current session!
  others,
}
