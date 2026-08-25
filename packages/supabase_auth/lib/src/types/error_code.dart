// All error codes from the Supabase Auth API. The whole list can be found here:
// https://github.com/supabase/auth/blob/master/internal/api/errorcodes.go
import 'package:collection/collection.dart';

/// A machine-readable identifier for an [AuthApiException], returned by the
/// Supabase Auth server as the `error_code` field.
enum ErrorCode {
  /// An unexpected server failure, such as an internal error.
  unexpectedFailure('unexpected_failure'),

  /// A request value failed validation.
  validationFailed('validation_failed'),

  /// The request body could not be parsed as JSON.
  badJson('bad_json'),

  /// The email address is already in use by another user.
  emailExists('email_exists'),

  /// The phone number is already in use by another user.
  phoneExists('phone_exists'),

  /// The provided JWT could not be parsed or verified.
  badJwt('bad_jwt'),

  /// The user does not have permission to perform an admin action.
  notAdmin('not_admin'),

  /// The request is missing a required `Authorization` header.
  noAuthorization('no_authorization'),

  /// No user matches the given identifier.
  userNotFound('user_not_found'),

  /// The session does not exist or was already terminated.
  sessionNotFound('session_not_found'),

  /// The session has expired and must be refreshed.
  sessionExpired('session_expired'),

  /// The request requires a session but none was provided.
  sessionMissing('session_missing'),

  /// The PKCE or OAuth flow state does not exist or already completed.
  flowStateNotFound('flow_state_not_found'),

  /// The PKCE or OAuth flow state has expired.
  flowStateExpired('flow_state_expired'),

  /// New user sign-ups are disabled for this project.
  signupDisabled('signup_disabled'),

  /// The user has been banned and cannot sign in.
  userBanned('user_banned'),

  /// The OAuth provider's email must be verified before it can be used.
  providerEmailNeedsVerification('provider_email_needs_verification'),

  /// The invite does not exist, was already used, or has expired.
  inviteNotFound('invite_not_found'),

  /// The `state` parameter of the OAuth callback is missing or invalid.
  badOauthState('bad_oauth_state'),

  /// The OAuth callback is missing required parameters.
  badOauthCallback('bad_oauth_callback'),

  /// The OAuth provider is not enabled for this project.
  oauthProviderNotSupported('oauth_provider_not_supported'),

  /// The JWT's `aud` claim does not match what the server expects.
  unexpectedAudience('unexpected_audience'),

  /// The user's only identity cannot be unlinked.
  singleIdentityNotDeletable('single_identity_not_deletable'),

  /// The identity cannot be unlinked because its email is used by another
  /// identity of the same user.
  emailConflictIdentityNotDeletable('email_conflict_identity_not_deletable'),

  /// The identity is already linked to a user.
  identityAlreadyExists('identity_already_exists'),

  /// Signing in with email is disabled for this project.
  emailProviderDisabled('email_provider_disabled'),

  /// Signing in with phone is disabled for this project.
  phoneProviderDisabled('phone_provider_disabled'),

  /// The user has reached the maximum number of enrolled MFA factors.
  tooManyEnrolledMfaFactors('too_many_enrolled_mfa_factors'),

  /// An MFA factor with this name already exists for the user.
  mfaFactorNameConflict('mfa_factor_name_conflict'),

  /// No MFA factor matches the given identifier.
  mfaFactorNotFound('mfa_factor_not_found'),

  /// The MFA challenge was created from a different IP address.
  mfaIpAddressMismatch('mfa_ip_address_mismatch'),

  /// The MFA challenge has expired.
  mfaChallengeExpired('mfa_challenge_expired'),

  /// The MFA verification code is incorrect.
  mfaVerificationFailed('mfa_verification_failed'),

  /// The MFA verification was rejected, for example by an auth hook.
  mfaVerificationRejected('mfa_verification_rejected'),

  /// The session's authenticator assurance level is too low for this
  /// operation.
  insufficientAal('insufficient_aal'),

  /// The captcha verification failed.
  captchaFailed('captcha_failed'),

  /// SAML SSO is disabled for this project.
  samlProviderDisabled('saml_provider_disabled'),

  /// Manually linking identities is disabled for this project.
  manualLinkingDisabled('manual_linking_disabled'),

  /// The SMS message could not be sent.
  smsSendFailed('sms_send_failed'),

  /// The user's email has not been confirmed yet.
  emailNotConfirmed('email_not_confirmed'),

  /// The user's phone number has not been confirmed yet.
  phoneNotConfirmed('phone_not_confirmed'),

  /// The reauthentication nonce is missing from the request.
  reauthNonceMissing('reauth_nonce_missing'),

  /// The SAML relay state does not exist or was already used.
  samlRelayStateNotFound('saml_relay_state_not_found'),

  /// The SAML relay state has expired.
  samlRelayStateExpired('saml_relay_state_expired'),

  /// No SAML identity provider matches the given identifier.
  samlIdpNotFound('saml_idp_not_found'),

  /// The SAML assertion did not contain a user identifier.
  samlAssertionNoUserId('saml_assertion_no_user_id'),

  /// The SAML assertion did not contain an email address.
  samlAssertionNoEmail('saml_assertion_no_email'),

  /// A user with this identifier already exists.
  userAlreadyExists('user_already_exists'),

  /// No SSO provider matches the given identifier.
  ssoProviderNotFound('sso_provider_not_found'),

  /// The SAML identity provider's metadata could not be fetched.
  samlMetadataFetchFailed('saml_metadata_fetch_failed'),

  /// A SAML identity provider with this entity ID already exists.
  samlIdpAlreadyExists('saml_idp_already_exists'),

  /// The SSO domain is already registered to a provider.
  ssoDomainAlreadyExists('sso_domain_already_exists'),

  /// The SAML assertion's entity ID does not match the registered provider.
  samlEntityIdMismatch('saml_entity_id_mismatch'),

  /// The request conflicts with the current state of the resource, for
  /// example a concurrent update.
  conflict('conflict'),

  /// The authentication provider is disabled for this project.
  providerDisabled('provider_disabled'),

  /// The user's account is managed by SSO and cannot be modified directly.
  userSsoManaged('user_sso_managed'),

  /// The operation requires the user to reauthenticate first.
  reauthenticationNeeded('reauthentication_needed'),

  /// The new password must be different from the current one.
  samePassword('same_password'),

  /// The reauthentication code is incorrect or expired.
  reauthenticationNotValid('reauthentication_not_valid'),

  /// The one-time password has expired.
  otpExpired('otp_expired'),

  /// Signing in with a one-time password is disabled for this project.
  otpDisabled('otp_disabled'),

  /// No identity matches the given identifier.
  identityNotFound('identity_not_found'),

  /// The password does not meet the project's strength requirements.
  weakPassword('weak_password'),

  /// Too many requests were sent in a short period.
  overRequestRateLimit('over_request_rate_limit'),

  /// Too many emails were sent to this address in a short period.
  overEmailSendRateLimit('over_email_send_rate_limit'),

  /// Too many SMS messages were sent to this number in a short period.
  overSmsSendRateLimit('over_sms_send_rate_limit'),

  /// The PKCE code verifier does not match the code challenge sent when the
  /// flow started.
  badCodeVerifier('bad_code_verifier'),

  /// Signing in anonymously is disabled for this project.
  anonymousProviderDisabled('anonymous_provider_disabled'),

  /// An auth hook did not respond in time.
  hookTimeout('hook_timeout'),

  /// An auth hook did not respond in time even after being retried.
  hookTimeoutAfterRetry('hook_timeout_after_retry'),

  /// An auth hook's response exceeded the maximum payload size.
  hookPayloadOverSizeLimit('hook_payload_over_size_limit'),

  /// An auth hook's response did not report its payload size.
  hookPayloadUnknownSize('hook_payload_unknown_size'),

  /// The request took too long to complete.
  requestTimeout('request_timeout'),

  /// Enrolling a phone MFA factor is disabled for this project.
  mfaPhoneEnrollDisabled('mfa_phone_enroll_not_enabled'),

  /// Verifying a phone MFA factor is disabled for this project.
  mfaPhoneVerifyDisabled('mfa_phone_verify_not_enabled'),

  /// Enrolling a TOTP MFA factor is disabled for this project.
  mfaTotpEnrollDisabled('mfa_totp_enroll_not_enabled'),

  /// Verifying a TOTP MFA factor is disabled for this project.
  mfaTotpVerifyDisabled('mfa_totp_verify_not_enabled'),

  /// Enrolling a WebAuthn MFA factor is disabled for this project.
  mfaWebauthnEnrollDisabled('mfa_webauthn_enroll_not_enabled'),

  /// Verifying a WebAuthn MFA factor is disabled for this project.
  mfaWebauthnVerifyDisabled('mfa_webauthn_verify_not_enabled'),

  /// Passkeys are disabled for this project.
  passkeyDisabled('passkey_disabled'),

  /// The user has reached the maximum number of registered passkeys.
  tooManyPasskeys('too_many_passkeys'),

  /// The WebAuthn challenge does not exist or was already used.
  webauthnChallengeNotFound('webauthn_challenge_not_found'),

  /// The WebAuthn challenge has expired.
  webauthnChallengeExpired('webauthn_challenge_expired'),

  /// The WebAuthn credential is already registered.
  webauthnCredentialExists('webauthn_credential_exists'),

  /// No WebAuthn credential matches the given identifier.
  webauthnCredentialNotFound('webauthn_credential_not_found'),

  /// The WebAuthn verification failed.
  webauthnVerificationFailed('webauthn_verification_failed');

  const ErrorCode(this.code);

  /// The wire value sent as the `error_code` field.
  final String code;

  /// Returns the error code whose [code] matches, or `null` if none does.
  static ErrorCode? fromCode(String code) {
    return ErrorCode.values.firstWhereOrNull(
      (errorCode) => errorCode.code == code,
    );
  }
}
