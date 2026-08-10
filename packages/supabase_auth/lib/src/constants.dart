import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

enum AuthChangeEvent {
  initialSession,
  passwordRecovery,
  signedIn,
  signedOut,
  tokenRefreshed,
  userUpdated,
  mfaChallengeVerified;

  String get value => snakeCase.toUpperCase();

  @internal
  static AuthChangeEvent? fromValue(String? value) {
    for (final event in AuthChangeEvent.values) {
      if (event.value == value || event.name == value) {
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
  static GenerateLinkType fromValue(String? value) {
    for (final type in GenerateLinkType.values) {
      if (type.snakeCase == value) {
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
