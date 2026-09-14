// This file intentionally builds on supabase_auth's experimental passkey API.
// ignore_for_file: experimental_member_use

import 'package:meta/meta.dart';
import 'package:passkeys_platform_interface/passkeys_platform_interface.dart';
import 'package:supabase_flutter/src/passkey/passkey_options_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Android Restore Credentials ("zero-tap sign-in") on top of Supabase
/// passkeys.
///
/// A restore key is a passkey that Android creates silently, backs up together
/// with the app data, and makes available on the user's next device. Because
/// the server side is the same as for passkeys, Supabase Auth stores and
/// verifies restore keys as regular passkeys. Signing in with one on the new
/// device yields a brand new session, independent of the refresh token chain
/// of the old device, so it is safe to use as the credential restored during
/// device setup.
///
/// Passkeys are a BETA feature and must be enabled for your project in the
/// Supabase Dashboard under Authentication > Configuration > Passkeys. Android
/// also requires Digital Asset Links for the relying party ID, exactly as for
/// passkeys.
///
/// The platform calls are delegated to the [RestoreCredentialInterface] you
/// pass in. The [`passkeys`](https://pub.dev/packages/passkeys) plugin's
/// `PasskeyAuthenticator` implements it since `passkeys` `2.23.0`, so the same
/// object serves [AuthClientPasskey.registerPasskey] and these methods.
///
/// Restore Credentials only exist on Android. Guard the calls with
/// `defaultTargetPlatform == TargetPlatform.android`.
///
/// Methods rethrow whatever the [RestoreCredentialInterface] throws when the
/// platform call fails, for example when there is no restore key on the device,
/// and throw [AuthException] when the Supabase server rejects the credential.
@experimental
extension AuthClientRestoreCredential on AuthClient {
  /// Creates a restore key for the signed in user and registers it as a
  /// passkey.
  ///
  /// Call it right after the user signs in, and on a later launch if the user
  /// is signed in and no restore key exists yet. Android keeps one restore key
  /// per app, so remember the returned [Passkey.id] and delete the previous key
  /// with [AuthPasskeyApi.delete] before creating a new one, and when the user
  /// signs out.
  ///
  /// [friendlyName] becomes the passkey's friendly name so restore keys can be
  /// told apart from the passkeys the user created, for example to hide them
  /// from a passkey management screen. It is also used as the account label
  /// when the server does not provide a `user.name` in the options, see
  /// [AuthPasskeyApi.startRegistration].
  ///
  /// [isCloudBackupEnabled] backs the restore key up to the cloud when the
  /// device has end-to-end encrypted backup and stores it locally otherwise.
  /// Pass `false` to always keep it local.
  ///
  /// Requires a signed in (non-anonymous) user.
  Future<Passkey> createRestoreKey(
    RestoreCredentialInterface restoreCredential, {
    String friendlyName = 'Android restore key',
    bool isCloudBackupEnabled = true,
  }) async {
    final registration = await passkey.startRegistration(
      friendlyName: friendlyName,
    );
    final response = await restoreCredential.createRestoreCredential(
      passkeyRegisterRequestFromOptions(registration.options),
      isCloudBackupEnabled: isCloudBackupEnabled,
    );
    final registered = await passkey.verifyRegistration(
      challengeId: registration.challengeId,
      credential: response.toJson(),
    );
    return passkey.update(
      passkeyId: registered.id,
      friendlyName: friendlyName,
    );
  }

  /// Signs the user in with the restore key on the device.
  ///
  /// Call it on the first launch after the app has been restored on a new
  /// device. Does not require an existing session. On success the session is
  /// persisted and an [AuthChangeEvent.signedIn] event is fired.
  Future<AuthResponse> signInWithRestoreKey(
    RestoreCredentialInterface restoreCredential, {
    String? captchaToken,
  }) async {
    final authentication = await passkey.startAuthentication(
      captchaToken: captchaToken,
    );
    final response = await restoreCredential.getRestoreCredential(
      passkeyAuthenticateRequestFromOptions(authentication.options),
    );
    return passkey.verifyAuthentication(
      challengeId: authentication.challengeId,
      credential: response.toJson(),
    );
  }
}
