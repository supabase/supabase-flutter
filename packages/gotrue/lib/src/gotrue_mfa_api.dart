part of 'gotrue_client.dart';

class GoTrueMFAApi {
  final GoTrueClient _client;
  final GotrueFetch _fetch;

  GoTrueMFAApi({required GoTrueClient client, required GotrueFetch fetch})
      : _client = client,
        _fetch = fetch;

  /// Unenroll removes a MFA factor.
  ///
  /// A user has to have an `aal2` authenticator level in order to unenroll a `verified` factor.
  Future<AuthMFAUnenrollResponse> unenroll(String factorId) async {
    final session = _client.currentSession;

    final data = await _fetch.request(
      '${_client._url}/factors/$factorId',
      RequestMethodType.delete,
      options: GotrueRequestOptions(
        headers: _client._headers,
        jwt: session?.accessToken,
      ),
    );

    return AuthMFAUnenrollResponse.fromJson(data);
  }

  /// Starts the enrollment process for a new Multi-Factor Authentication (MFA) factor.
  /// This method creates a new `unverified` factor.
  /// To verify a factor, present the QR code or secret to the user and ask them to add it to their authenticator app.
  ///
  /// The user has to enter the code from their authenticator app to verify it.
  ///
  /// Upon verifying a factor, all other sessions are logged out and the current session's authenticator level is promoted to `aal2`.
  ///
  /// [factorType] : Type of factor being enrolled.
  ///
  /// [issuer] : Domain which the user is enrolled with.
  ///
  /// [friendlyName] : Human readable name assigned to the factor.
  Future<AuthMFAEnrollResponse> enroll({
    FactorType factorType = FactorType.totp,
    String? issuer,
    String? friendlyName,
  }) async {
    final session = _client.currentSession;
    final data = await _fetch.request(
      '${_client._url}/factors',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _client._headers,
        body: {
          'friendly_name': friendlyName,
          'factor_type': factorType.name,
          'issuer': issuer,
        },
        jwt: session?.accessToken,
      ),
    );

    data['totp']['qr_code'] =
        'data:image/svg+xml;utf-8,${data['totp']['qr_code']}';

    final response = AuthMFAEnrollResponse.fromJson(data);
    return response;
  }

  /// Verifies a code against a [challengeId].
  ///
  /// The verification [code] is provided by the user by entering a code seen in their authenticator app.
  Future<AuthMFAVerifyResponse> verify({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    final session = _client.currentSession;

    final data = await _fetch.request(
      '${_client._url}/factors/$factorId/verify',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _client._headers,
        body: {
          'challenge_id': challengeId,
          'code': code,
        },
        jwt: session?.accessToken,
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

  /// Prepares a challenge used to verify that a user has access to a MFA factor.
  ///
  /// [factorId] System assigned identifier for authenticator device as returned by enroll
  Future<AuthMFAChallengeResponse> challenge({
    required String factorId,
  }) async {
    final session = _client.currentSession;

    final data = await _fetch.request(
      '${_client._url}/factors/$factorId/challenge',
      RequestMethodType.post,
      options: GotrueRequestOptions(
        headers: _client._headers,
        jwt: session?.accessToken,
      ),
    );

    return AuthMFAChallengeResponse.fromJson(data);
  }

  /// Helper method which creates a challenge and immediately uses the given code to verify against it thereafter.
  ///
  /// The verification code is provided by the user by entering a code seen in their authenticator app.
  Future<AuthMFAVerifyResponse> challengeAndVerify({
    required String factorId,
    required String code,
  }) async {
    final challengeResponse = await challenge(factorId: factorId);
    return verify(
      factorId: factorId,
      challengeId: challengeResponse.id,
      code: code,
    );
  }

  /// Returns the list of MFA factors enabled for this user.
  ///
  /// Automatically refreshes the session to get the latest list of factors.
  Future<AuthMFAListFactorsResponse> listFactors() async {
    await _client.refreshSession();
    final user = _client.currentUser;
    final factors = user?.factors ?? [];
    final totp = factors
        .where((factor) =>
            factor.factorType == FactorType.totp &&
            factor.status == FactorStatus.verified)
        .toList();

    return AuthMFAListFactorsResponse(all: factors, totp: totp);
  }

  /// Returns the Authenticator Assurance Level (AAL) for the active session.
  ///
  /// You can use this to check whether the current user needs to be shown a screen to verify their MFA factors.
  AuthMFAGetAuthenticatorAssuranceLevelResponse
      getAuthenticatorAssuranceLevel() {
    final session = _client.currentSession;
    if (session == null) {
      return AuthMFAGetAuthenticatorAssuranceLevelResponse(
        currentLevel: null,
        nextLevel: null,
        currentAuthenticationMethods: [],
      );
    }
    final payload = Jwt.parseJwt(session.accessToken);

    final currentLevel = AuthenticatorAssuranceLevels.values
        .firstWhereOrNull((level) => level.name == payload['aal']);

    var nextLevel = currentLevel;

    if (session.user.factors
            ?.any((factor) => factor.status == FactorStatus.verified) ??
        false) {
      nextLevel = AuthenticatorAssuranceLevels.aal2;
    }

    final amr = (payload['amr'] as List)
        .map((e) => AMREntry.fromJson(Map.from(e)))
        .toList();
    return AuthMFAGetAuthenticatorAssuranceLevelResponse(
      currentLevel: currentLevel,
      nextLevel: nextLevel,
      currentAuthenticationMethods: amr,
    );
  }
}
