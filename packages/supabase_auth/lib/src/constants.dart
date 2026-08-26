import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

/// The kind of change reported on `AuthClient.onAuthStateChange`.
enum AuthChangeEvent {
  /// Emitted once at startup with the session restored from storage, or
  /// `null` if there was none.
  initialSession,

  /// Emitted after the user follows a password recovery link.
  passwordRecovery,

  /// Emitted after a successful sign-in.
  signedIn,

  /// Emitted after the user signs out.
  signedOut,

  /// Emitted after the access token is refreshed.
  tokenRefreshed,

  /// Emitted after the user's profile is updated.
  userUpdated,

  /// Emitted after an MFA challenge is verified.
  mfaChallengeVerified;

  /// The event name sent by the server, for example `'SIGNED_IN'`.
  String get value => snakeCase.toUpperCase();

  /// Parses an event name, matching either [value] or [Enum.name].
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

/// The kind of link `AuthAdminApi.generateLink` generates.
enum GenerateLinkType {
  /// A signup confirmation link.
  signup,

  /// An invite link.
  invite,

  /// A magic sign-in link.
  magiclink,

  /// A password recovery link.
  recovery,

  /// A confirmation link sent to the user's current email address, for an
  /// email change.
  emailChangeCurrent,

  /// A confirmation link sent to the user's new email address, for an email
  /// change.
  emailChangeNew,

  /// Returned when the backend sends an unrecognized type.
  /// This allows forward compatibility with new link types.
  unknown;

  /// Parses the `type` field of a generate-link response, defaulting to
  /// [GenerateLinkType.unknown].
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

/// The kind of one-time password `AuthClient.verifyOTP` verifies.
enum OtpType {
  /// A one-time password sent by SMS.
  sms,

  /// A one-time password confirming a phone number change.
  phoneChange,

  /// A one-time password confirming sign-up.
  signup,

  /// A one-time password confirming an invite.
  invite,

  /// A one-time password from a magic link.
  magiclink,

  /// A one-time password for password recovery.
  recovery,

  /// A one-time password confirming an email change.
  emailChange,

  /// A one-time password sent by email.
  email,
}

/// Messaging channel to use (e.g. whatsapp or sms)
enum OtpChannel {
  /// Sends the one-time password by SMS.
  sms,

  /// Sends the one-time password over WhatsApp.
  whatsapp,
}

/// The blockchain used to sign in with a Web3 wallet.
enum Web3Chain {
  /// The Ethereum blockchain.
  ethereum,

  /// The Solana blockchain.
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
