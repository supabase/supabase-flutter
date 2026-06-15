// This file intentionally builds on gotrue's experimental passkey API.
// ignore_for_file: experimental_member_use

import 'package:meta/meta.dart';
import 'package:passkeys/authenticator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/src/passkey/passkey_options_mapper.dart';

final PasskeyAuthenticator _authenticator = PasskeyAuthenticator();

/// Passkey (WebAuthn) convenience methods that perform the full ceremony,
/// including the platform prompt (FaceID/TouchID/security key), on top of the
/// server side exposed by [GoTrueClient.passkey].
///
/// Passkeys are a BETA feature and must be enabled for your project in the
/// Supabase Dashboard under Authentication > Configuration > Passkeys.
///
/// The platform ceremony is handled by the [`passkeys`](https://pub.dev/packages/passkeys)
/// plugin and requires platform setup that this library cannot do for you:
/// Associated Domains on iOS/macOS, Digital Asset Links on Android, and
/// including the `passkeys` web SDK in `index.html` on web. See the package
/// README for details.
///
/// Methods throw the `passkeys` plugin's exceptions (e.g.
/// `PasskeyAuthCancelledException`) when the platform ceremony fails, and
/// [AuthException] when the Supabase server rejects the credential. Import
/// `package:passkeys/exceptions.dart` to catch the specific ceremony errors.
@experimental
extension GoTrueClientPasskey on GoTrueClient {
  /// Registers a new passkey for the signed in user.
  ///
  /// Starts the registration with the Supabase server, prompts the user to
  /// create a credential on the device, and verifies it with the server.
  ///
  /// Requires a signed in (non-anonymous) user. Returns the newly registered
  /// [Passkey].
  Future<Passkey> registerPasskey() async {
    final registration = await passkey.startRegistration();
    final response = await _authenticator.register(
      passkeyRegisterRequestFromOptions(registration.options),
    );
    return passkey.verifyRegistration(
      challengeId: registration.challengeId,
      credential: response.toJson(),
    );
  }

  /// Signs the user in with a passkey.
  ///
  /// Starts the authentication with the Supabase server, prompts the user to
  /// pick and unlock a passkey on the device, and verifies the assertion with
  /// the server.
  ///
  /// Does not require an existing session. On success the session is persisted
  /// and an [AuthChangeEvent.signedIn] event is fired.
  Future<AuthResponse> signInWithPasskey({String? captchaToken}) async {
    final authentication = await passkey.startAuthentication(
      captchaToken: captchaToken,
    );
    final response = await _authenticator.authenticate(
      passkeyAuthenticateRequestFromOptions(authentication.options),
    );
    return passkey.verifyAuthentication(
      challengeId: authentication.challengeId,
      credential: response.toJson(),
    );
  }
}
