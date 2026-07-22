// This file intentionally builds on gotrue's experimental passkey API.
// ignore_for_file: experimental_member_use

import 'package:meta/meta.dart';
import 'package:passkeys_platform_interface/passkey_authenticator_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/src/passkey/passkey_options_mapper.dart';

/// Passkey (WebAuthn) convenience methods that perform the full ceremony,
/// including the platform prompt (FaceID/TouchID/security key), on top of the
/// server side exposed by [GoTrueClient.passkey].
///
/// Passkeys are a BETA feature and must be enabled for your project in the
/// Supabase Dashboard under Authentication > Configuration > Passkeys.
///
/// This library does not depend on a passkey plugin directly. The platform
/// ceremony is delegated to the [PasskeyAuthenticatorInterface] you pass in.
/// The [`passkeys`](https://pub.dev/packages/passkeys) plugin's
/// `PasskeyAuthenticator` implements that interface, but you are free to supply
/// your own implementation.
///
/// Whichever plugin you use requires platform setup that this library cannot do
/// for you: Associated Domains on iOS/macOS, Digital Asset Links on Android,
/// and including the web SDK in `index.html` on web. See the plugin's README
/// for details.
///
/// Methods rethrow whatever the authenticator throws (e.g. the `passkeys`
/// plugin's `PasskeyAuthCancelledException`) when the platform ceremony fails,
/// and throw [AuthException] when the Supabase server rejects the credential.
@experimental
extension GoTrueClientPasskey on GoTrueClient {
  /// Registers a new passkey for the signed in user.
  ///
  /// Starts the registration with the Supabase server, calls [authenticator] to
  /// create a credential on the device, and verifies it with the server.
  ///
  /// [friendlyName] is the account label the authenticator shows for the
  /// passkey when the server does not provide one. See
  /// [GoTruePasskeyApi.startRegistration].
  ///
  /// Requires a signed in (non-anonymous) user. Returns the newly registered
  /// [Passkey].
  Future<Passkey> registerPasskey(
    PasskeyAuthenticatorInterface authenticator, {
    String? friendlyName,
  }) async {
    final registration = await passkey.startRegistration(
      friendlyName: friendlyName,
    );
    final response = await authenticator.register(
      passkeyRegisterRequestFromOptions(registration.options),
    );
    return passkey.verifyRegistration(
      challengeId: registration.challengeId,
      credential: response.toJson(),
    );
  }

  /// Signs the user in with a passkey.
  ///
  /// Starts the authentication with the Supabase server, calls [authenticator]
  /// to pick and unlock a passkey on the device, and verifies the assertion
  /// with the server.
  ///
  /// Does not require an existing session. On success the session is persisted
  /// and an [AuthChangeEvent.signedIn] event is fired.
  Future<AuthResponse> signInWithPasskey(
    PasskeyAuthenticatorInterface authenticator, {
    String? captchaToken,
  }) async {
    final authentication = await passkey.startAuthentication(
      captchaToken: captchaToken,
    );
    final response = await authenticator.authenticate(
      passkeyAuthenticateRequestFromOptions(authentication.options),
    );
    return passkey.verifyAuthentication(
      challengeId: authentication.challengeId,
      credential: response.toJson(),
    );
  }
}
