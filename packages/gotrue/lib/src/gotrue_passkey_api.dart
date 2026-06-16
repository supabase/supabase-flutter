part of 'gotrue_client.dart';

/// {@template gotrue_passkey_api}
/// API namespace for passkey (WebAuthn) authentication.
///
/// Passkeys are a BETA feature and must be enabled for your project in the
/// Supabase Dashboard under Authentication > Configuration > Passkeys before
/// these methods can be used.
///
/// This API exposes the server side of the WebAuthn ceremony. The client
/// side, prompting the user with FaceID/TouchID/security key and producing a
/// credential, has to be performed with a platform passkey API:
/// `navigator.credentials.create()`/`get()` on web, or a passkey plugin on
/// iOS, Android and macOS. Options and credentials are exchanged as JSON maps
/// in the W3C WebAuthn (Level 3) format with binary fields encoded as
/// base64url strings, which is the format such APIs accept and produce.
///
/// Registering a passkey for the signed in user:
/// ```dart
/// final registration = await supabase.auth.passkey.startRegistration();
/// // Perform the platform ceremony with registration.options.
/// final credential = await platformCreatePasskey(registration.options);
/// final passkey = await supabase.auth.passkey.verifyRegistration(
///   challengeId: registration.challengeId,
///   credential: credential,
/// );
/// ```
///
/// Signing in with a passkey:
/// ```dart
/// final authentication = await supabase.auth.passkey.startAuthentication();
/// // Perform the platform ceremony with authentication.options.
/// final credential = await platformGetPasskey(authentication.options);
/// final response = await supabase.auth.passkey.verifyAuthentication(
///   challengeId: authentication.challengeId,
///   credential: credential,
/// );
/// ```
/// {@endtemplate}
@experimental
class GoTruePasskeyApi {
  final GoTrueClient _client;
  final GotrueFetch _fetch;

  const GoTruePasskeyApi({
    required GoTrueClient client,
    required GotrueFetch fetch,
  })  : _client = client,
        _fetch = fetch;

  /// Starts the registration of a new passkey for the signed in user.
  ///
  /// Pass the returned [PasskeyRegistrationOptionsResponse.options] to the
  /// platform's passkey API to create a credential, then complete the
  /// registration with [verifyRegistration].
  ///
  /// Requires a signed in (non-anonymous) user. If the user has verified MFA
  /// factors, the session has to be at `aal2` to manage passkeys.
  Future<PasskeyRegistrationOptionsResponse> startRegistration() async {
    final session = _client.currentSession;

    final data = await _fetch.request(
      '${_client._url}/passkeys/registration/options',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _client._headers,
        body: {},
        jwt: session?.accessToken,
      ),
    );

    return PasskeyRegistrationOptionsResponse.fromJson(data);
  }

  /// Completes the registration of a new passkey.
  ///
  /// [challengeId] is the ID returned by [startRegistration].
  ///
  /// [credential] is the credential created by the platform's passkey API,
  /// serialized in the W3C `RegistrationResponseJSON` format (the format
  /// produced by `PublicKeyCredential.toJSON()` and passkey plugins).
  ///
  /// Returns the newly registered [Passkey]. Its friendly name is generated
  /// by the server from the authenticator that created the credential and
  /// can be changed with [update].
  Future<Passkey> verifyRegistration({
    required String challengeId,
    required Map<String, dynamic> credential,
  }) async {
    final session = _client.currentSession;

    final data = await _fetch.request(
      '${_client._url}/passkeys/registration/verify',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _client._headers,
        body: {
          'challenge_id': challengeId,
          'credential': credential,
        },
        jwt: session?.accessToken,
      ),
    );

    return Passkey.fromJson(data);
  }

  /// Starts a passkey sign in.
  ///
  /// Does not require a session. Pass the returned
  /// [PasskeyAuthenticationOptionsResponse.options] to the platform's passkey
  /// API to obtain an assertion, then complete the sign in with
  /// [verifyAuthentication].
  Future<PasskeyAuthenticationOptionsResponse> startAuthentication({
    String? captchaToken,
  }) async {
    final data = await _fetch.request(
      '${_client._url}/passkeys/authentication/options',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _client._headers,
        body: {
          'gotrue_meta_security': {'captcha_token': captchaToken},
        },
      ),
    );

    return PasskeyAuthenticationOptionsResponse.fromJson(data);
  }

  /// Completes a passkey sign in and returns the new session.
  ///
  /// [challengeId] is the ID returned by [startAuthentication].
  ///
  /// [credential] is the assertion produced by the platform's passkey API,
  /// serialized in the W3C `AuthenticationResponseJSON` format (the format
  /// produced by `PublicKeyCredential.toJSON()` and passkey plugins).
  ///
  /// On success the session is persisted and an
  /// [AuthChangeEvent.signedIn] event is fired.
  Future<AuthResponse> verifyAuthentication({
    required String challengeId,
    required Map<String, dynamic> credential,
  }) async {
    final data = await _fetch.request(
      '${_client._url}/passkeys/authentication/verify',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _client._headers,
        body: {
          'challenge_id': challengeId,
          'credential': credential,
        },
      ),
    );

    final authResponse = AuthResponse.fromJson(data);
    final session = authResponse.session;
    if (session != null) {
      _client._saveSession(session);
      _client.notifyAllSubscribers(AuthChangeEvent.signedIn);
    }

    return authResponse;
  }

  /// Returns the list of passkeys registered to the signed in user.
  Future<List<Passkey>> list() async {
    final session = _client.currentSession;

    final data = await _fetch.request(
      '${_client._url}/passkeys',
      RequestMethodType.get,
      options: GotrueRequestOptions(
        headers: _client._headers,
        jwt: session?.accessToken,
      ),
    );

    if (data is! List) {
      throw FormatException(
        'Expected a list of passkeys, got ${data.runtimeType}',
        data.toString(),
      );
    }
    return data.map((e) => Passkey.fromJson(Map.from(e as Map))).toList();
  }

  /// Updates the friendly name of a passkey.
  Future<Passkey> update({
    required String passkeyId,
    required String friendlyName,
  }) async {
    final session = _client.currentSession;

    final data = await _fetch.request(
      '${_client._url}/passkeys/$passkeyId',
      RequestMethodType.patch,
      options: GotrueRequestOptions(
        headers: _client._headers,
        body: {'friendly_name': friendlyName},
        jwt: session?.accessToken,
      ),
    );

    return Passkey.fromJson(data);
  }

  /// Deletes a passkey from the signed in user.
  ///
  /// If the user has verified MFA factors, the session has to be at `aal2`
  /// to manage passkeys.
  Future<void> delete({required String passkeyId}) async {
    final session = _client.currentSession;

    await _fetch.request(
      '${_client._url}/passkeys/$passkeyId',
      RequestMethodType.delete,
      options: GotrueRequestOptions(
        headers: _client._headers,
        jwt: session?.accessToken,
      ),
    );
  }
}
