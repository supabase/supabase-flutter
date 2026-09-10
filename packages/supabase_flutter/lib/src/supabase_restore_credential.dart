// This file intentionally builds on supabase_auth's experimental passkey API.
// ignore_for_file: experimental_member_use

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The platform half of Android's Restore Credentials feature.
///
/// Restore keys are WebAuthn credentials that Android backs up with the user's
/// device data and hands to the app on a new device, so the user is signed in
/// without any interaction. `supabase_flutter` does not depend on a Credential
/// Manager plugin directly. Implement this interface on top of the plugin you
/// use, for example by forwarding to `androidx.credentials`'
/// `CreateRestoreCredentialRequest` and `GetRestoreCredentialOption`, and pass
/// it to [AuthClientRestoreCredential.createRestoreKey] and
/// [AuthClientRestoreCredential.signInWithRestoreKey].
///
/// Both methods exchange JSON strings in the W3C WebAuthn (Level 3) format,
/// which is the format `androidx.credentials` accepts and produces.
@experimental
abstract interface class RestoreCredentialInterface {
  /// Creates a restore key on the device.
  ///
  /// [requestJson] is a `PublicKeyCredentialCreationOptionsJSON`. Returns the
  /// created credential as a `RegistrationResponseJSON`.
  Future<String> createRestoreCredential(String requestJson);

  /// Retrieves the restore key from the device and signs the challenge in
  /// [requestJson] with it.
  ///
  /// [requestJson] is a `PublicKeyCredentialRequestOptionsJSON`. Returns the
  /// assertion as an `AuthenticationResponseJSON`.
  Future<String> getRestoreCredential(String requestJson);
}

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
  /// Requires a signed in (non-anonymous) user.
  Future<Passkey> createRestoreKey(
    RestoreCredentialInterface restoreCredential, {
    String friendlyName = 'Android restore key',
  }) async {
    final registration = await passkey.startRegistration(
      friendlyName: friendlyName,
    );
    final credential = await restoreCredential.createRestoreCredential(
      jsonEncode(registration.options),
    );
    final registered = await passkey.verifyRegistration(
      challengeId: registration.challengeId,
      credential: _decodeCredential(credential),
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
    final credential = await restoreCredential.getRestoreCredential(
      jsonEncode(authentication.options),
    );
    return passkey.verifyAuthentication(
      challengeId: authentication.challengeId,
      credential: _decodeCredential(credential),
    );
  }
}

Map<String, dynamic> _decodeCredential(String credentialJson) {
  final decoded = jsonDecode(credentialJson);
  if (decoded is! Map) {
    throw FormatException(
      'Expected a WebAuthn credential JSON object, '
      'got ${decoded.runtimeType}',
      credentialJson,
    );
  }
  return Map<String, dynamic>.from(decoded);
}
