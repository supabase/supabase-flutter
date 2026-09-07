part of 'auth_client.dart';

/// {@template auth_mfa_recovery_codes_api}
/// API namespace for MFA recovery codes, exposed on
/// `AuthClient.mfa.recoveryCodes`.
///
/// Recovery codes are single-use backup codes that let a user reach `aal2`
/// when they cannot use their other MFA factors, for example after losing an
/// authenticator app. A user has a single set of recovery codes and the codes
/// are shown exactly once when generated.
///
/// Recovery codes are an experimental feature and must be enabled on the
/// Supabase Auth server before these methods can be used. They can never be
/// the user's only factor: generate them after another factor is verified.
///
/// ```dart
/// final generated = await supabase.auth.mfa.recoveryCodes.generate(
///   friendlyName: 'Backup codes',
/// );
/// // Show generated.codes to the user once and ask them to store them safely.
///
/// final verified = await supabase.auth.mfa.recoveryCodes.verify(
///   'K4M9-X7QP-2AB8-HT3Z',
/// );
/// ```
/// {@endtemplate}
@experimental
class AuthMFARecoveryCodesApi {
  const AuthMFARecoveryCodesApi({
    required AuthClient client,
    required AuthFetch fetch,
  }) : _client = client,
       _fetch = fetch;
  final AuthClient _client;
  final AuthFetch _fetch;

  /// Returns the enrollment status of the user's recovery codes: the total
  /// number of codes in the current set and how many are still unused. Never
  /// returns the codes themselves.
  ///
  /// Works at any authenticator assurance level. Throws an
  /// [AuthApiException] with [ErrorCode.mfaFactorNotFound] when the user has
  /// not generated recovery codes yet. When
  /// [AuthMFARecoveryCodesStatusResponse.remaining] reaches `0`, prompt the
  /// user to call [regenerate].
  Future<AuthMFARecoveryCodesStatusResponse> getStatus() async {
    final data = await _fetch.request(
      '${_client._url}/factors/recovery-codes',
      HttpMethod.get,
      options: AuthRequestOptions(
        headers: _client._headers,
        jwt: _client.currentSession?.accessToken,
      ),
    );

    return AuthMFARecoveryCodesStatusResponse.fromJson(data);
  }

  /// Generates the user's set of recovery codes.
  ///
  /// The plaintext codes are returned exactly once in
  /// [AuthMFARecoveryCodesGenerateResponse.codes] and cannot be retrieved
  /// again, so show them to the user and ask them to store the codes safely.
  ///
  /// [friendlyName] is the name of the recovery codes factor as shown in
  /// [User.factors] and [AuthMFAApi.listFactors]. It must be unique among the
  /// user's factors. The server defaults it to `Recovery codes` when omitted.
  ///
  /// The session must be at `aal2` and the user must already have another
  /// verified factor. A user can only have one set of recovery codes; use
  /// [regenerate] to replace an existing set. Throws an [AuthApiException]
  /// with [ErrorCode.insufficientAal], [ErrorCode.mfaRecoveryCodesSoleFactor],
  /// [ErrorCode.mfaVerifiedFactorExists] or
  /// [ErrorCode.mfaRecoveryCodesEnrollDisabled] otherwise.
  Future<AuthMFARecoveryCodesGenerateResponse> generate({
    String? friendlyName,
  }) async {
    final data = await _fetch.request(
      '${_client._url}/factors/recovery-codes',
      HttpMethod.post,
      options: AuthRequestOptions(
        headers: _client._headers,
        body: friendlyName == null ? null : {'friendly_name': friendlyName},
        jwt: _client.currentSession?.accessToken,
      ),
    );

    return AuthMFARecoveryCodesGenerateResponse.fromJson(data);
  }

  /// Verifies one of the user's recovery codes and upgrades the current
  /// session to `aal2`. Each code can be used only once.
  ///
  /// [code] can be passed exactly as the user typed it: letter case,
  /// whitespace and `-` separators are ignored by the server.
  ///
  /// On success the session is replaced with the upgraded one and
  /// [AuthChangeEvent.mfaChallengeVerified] is emitted. The user's other
  /// `aal1` sessions are signed out and the new access token includes
  /// [AuthenticationMethodReference.mfaRecoveryCode] in its `amr` claim.
  ///
  /// A wrong, already used or missing code throws an [AuthApiException] with
  /// [ErrorCode.mfaVerificationFailed]. After too many failed attempts the
  /// server locks verification for a period and responds with
  /// [ErrorCode.mfaRecoveryCodesLocked]. When recovery code verification is
  /// disabled on the server the code is
  /// [ErrorCode.mfaRecoveryCodesVerifyDisabled].
  Future<AuthMFAVerifyResponse> verify(String code) async {
    final data = await _fetch.request(
      '${_client._url}/factors/recovery-codes/verify',
      HttpMethod.post,
      options: AuthRequestOptions(
        headers: _client._headers,
        body: {'code': code},
        jwt: _client.currentSession?.accessToken,
      ),
    );

    final response = AuthMFAVerifyResponse.fromJson(data);
    _client._saveSession(
      Session(
        accessToken: response.accessToken,
        tokenType: response.tokenType,
        user: response.user,
        expiresIn: response.expiresIn.inSeconds,
        refreshToken: response.refreshToken,
      ),
    );
    _client.notifyAllSubscribers(AuthChangeEvent.mfaChallengeVerified);
    return response;
  }

  /// Replaces the user's recovery codes with a brand new set.
  ///
  /// All remaining codes from the previous set stop working immediately and
  /// any verification lockout is cleared. The factor's id and friendly name
  /// are preserved. The new plaintext codes are returned exactly once.
  ///
  /// The session must be at `aal2`. Throws an [AuthApiException] with
  /// [ErrorCode.mfaFactorNotFound] when the user has no recovery codes to
  /// regenerate; use [generate] instead.
  Future<AuthMFARecoveryCodesGenerateResponse> regenerate() async {
    final data = await _fetch.request(
      '${_client._url}/factors/recovery-codes/regenerate',
      HttpMethod.post,
      options: AuthRequestOptions(
        headers: _client._headers,
        jwt: _client.currentSession?.accessToken,
      ),
    );

    return AuthMFARecoveryCodesGenerateResponse.fromJson(data);
  }

  /// Removes the user's recovery codes factor together with all of its codes.
  ///
  /// The session must be at `aal2`. Throws an [AuthApiException] with
  /// [ErrorCode.mfaFactorNotFound] when the user has no recovery codes.
  Future<AuthMFAUnenrollResponse> unenroll() async {
    final data = await _fetch.request(
      '${_client._url}/factors/recovery-codes',
      HttpMethod.delete,
      options: AuthRequestOptions(
        headers: _client._headers,
        jwt: _client.currentSession?.accessToken,
      ),
    );

    return AuthMFAUnenrollResponse.fromJson(data);
  }
}
