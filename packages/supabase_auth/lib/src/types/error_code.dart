// All error codes from the Supabase Auth API. The whole list can be found here:
// https://github.com/supabase/auth/blob/master/internal/api/errorcodes.go
import 'package:collection/collection.dart';
import 'package:supabase_common/supabase_common.dart';

/// A machine-readable identifier for an [AuthApiException], returned by the
/// Supabase Auth server as the `error_code` field.
enum ErrorCode {
  /// An unexpected server failure, such as an internal error.
  unexpectedFailure,

  /// A request value failed validation.
  validationFailed,

  /// The request body could not be parsed as JSON.
  badJson,

  /// The email address is already in use by another user.
  emailExists,

  /// The phone number is already in use by another user.
  phoneExists,

  /// The provided JWT could not be parsed or verified.
  badJwt,

  /// The user does not have permission to perform an admin action.
  notAdmin,

  /// The request is missing a required `Authorization` header.
  noAuthorization,

  /// No user matches the given identifier.
  userNotFound,

  /// The session does not exist or was already terminated.
  sessionNotFound,

  /// The session has expired and must be refreshed.
  sessionExpired,

  /// The request requires a session but none was provided.
  sessionMissing,

  /// The PKCE or OAuth flow state does not exist or already completed.
  flowStateNotFound,

  /// The PKCE or OAuth flow state has expired.
  flowStateExpired,

  /// New user sign-ups are disabled for this project.
  signupDisabled,

  /// The user has been banned and cannot sign in.
  userBanned,

  /// The OAuth provider's email must be verified before it can be used.
  providerEmailNeedsVerification,

  /// The invite does not exist, was already used, or has expired.
  inviteNotFound,

  /// The `state` parameter of the OAuth callback is missing or invalid.
  badOauthState,

  /// The OAuth callback is missing required parameters.
  badOauthCallback,

  /// The OAuth provider is not enabled for this project.
  oauthProviderNotSupported,

  /// The JWT's `aud` claim does not match what the server expects.
  unexpectedAudience,

  /// The user's only identity cannot be unlinked.
  singleIdentityNotDeletable,

  /// The identity cannot be unlinked because its email is used by another
  /// identity of the same user.
  emailConflictIdentityNotDeletable,

  /// The identity is already linked to a user.
  identityAlreadyExists,

  /// Signing in with email is disabled for this project.
  emailProviderDisabled,

  /// Signing in with phone is disabled for this project.
  phoneProviderDisabled,

  /// The user has reached the maximum number of enrolled MFA factors.
  tooManyEnrolledMfaFactors,

  /// An MFA factor with this name already exists for the user.
  mfaFactorNameConflict,

  /// No MFA factor matches the given identifier.
  mfaFactorNotFound,

  /// The MFA challenge was created from a different IP address.
  mfaIpAddressMismatch,

  /// The MFA challenge has expired.
  mfaChallengeExpired,

  /// The MFA verification code is incorrect.
  mfaVerificationFailed,

  /// The MFA verification was rejected, for example by an auth hook.
  mfaVerificationRejected,

  /// The session's authenticator assurance level is too low for this
  /// operation.
  insufficientAal,

  /// The captcha verification failed.
  captchaFailed,

  /// SAML SSO is disabled for this project.
  samlProviderDisabled,

  /// Manually linking identities is disabled for this project.
  manualLinkingDisabled,

  /// The SMS message could not be sent.
  smsSendFailed,

  /// The user's email has not been confirmed yet.
  emailNotConfirmed,

  /// The user's phone number has not been confirmed yet.
  phoneNotConfirmed,

  /// The reauthentication nonce is missing from the request.
  reauthNonceMissing,

  /// The SAML relay state does not exist or was already used.
  samlRelayStateNotFound,

  /// The SAML relay state has expired.
  samlRelayStateExpired,

  /// No SAML identity provider matches the given identifier.
  samlIdpNotFound,

  /// The SAML assertion did not contain a user identifier.
  samlAssertionNoUserId,

  /// The SAML assertion did not contain an email address.
  samlAssertionNoEmail,

  /// A user with this identifier already exists.
  userAlreadyExists,

  /// No SSO provider matches the given identifier.
  ssoProviderNotFound,

  /// The SAML identity provider's metadata could not be fetched.
  samlMetadataFetchFailed,

  /// A SAML identity provider with this entity ID already exists.
  samlIdpAlreadyExists,

  /// The SSO domain is already registered to a provider.
  ssoDomainAlreadyExists,

  /// The SAML assertion's entity ID does not match the registered provider.
  samlEntityIdMismatch,

  /// The request conflicts with the current state of the resource, for
  /// example a concurrent update.
  conflict,

  /// The authentication provider is disabled for this project.
  providerDisabled,

  /// The user's account is managed by SSO and cannot be modified directly.
  userSsoManaged,

  /// The operation requires the user to reauthenticate first.
  reauthenticationNeeded,

  /// The new password must be different from the current one.
  samePassword,

  /// The reauthentication code is incorrect or expired.
  reauthenticationNotValid,

  /// The one-time password has expired.
  otpExpired,

  /// Signing in with a one-time password is disabled for this project.
  otpDisabled,

  /// No identity matches the given identifier.
  identityNotFound,

  /// The password does not meet the project's strength requirements.
  weakPassword,

  /// Too many requests were sent in a short period.
  overRequestRateLimit,

  /// Too many emails were sent to this address in a short period.
  overEmailSendRateLimit,

  /// Too many SMS messages were sent to this number in a short period.
  overSmsSendRateLimit,

  /// The PKCE code verifier does not match the code challenge sent when the
  /// flow started.
  badCodeVerifier,

  /// Signing in anonymously is disabled for this project.
  anonymousProviderDisabled,

  /// An auth hook did not respond in time.
  hookTimeout,

  /// An auth hook did not respond in time even after being retried.
  hookTimeoutAfterRetry,

  /// An auth hook's response exceeded the maximum payload size.
  hookPayloadOverSizeLimit,

  /// An auth hook's response did not report its payload size.
  hookPayloadUnknownSize,

  /// The request took too long to complete.
  requestTimeout,

  /// Enrolling a phone MFA factor is disabled for this project.
  mfaPhoneEnrollNotEnabled,

  /// Verifying a phone MFA factor is disabled for this project.
  mfaPhoneVerifyNotEnabled,

  /// Enrolling a TOTP MFA factor is disabled for this project.
  mfaTotpEnrollNotEnabled,

  /// Verifying a TOTP MFA factor is disabled for this project.
  mfaTotpVerifyNotEnabled,

  /// Enrolling a WebAuthn MFA factor is disabled for this project.
  mfaWebauthnEnrollNotEnabled,

  /// Verifying a WebAuthn MFA factor is disabled for this project.
  mfaWebauthnVerifyNotEnabled,

  /// Passkeys are disabled for this project.
  passkeyDisabled,

  /// The user has reached the maximum number of registered passkeys.
  tooManyPasskeys,

  /// The WebAuthn challenge does not exist or was already used.
  webauthnChallengeNotFound,

  /// The WebAuthn challenge has expired.
  webauthnChallengeExpired,

  /// The WebAuthn credential is already registered.
  webauthnCredentialExists,

  /// No WebAuthn credential matches the given identifier.
  webauthnCredentialNotFound,

  /// The WebAuthn verification failed.
  webauthnVerificationFailed;

  /// The wire value sent as the `error_code` field.
  String get code => snakeCase;

  /// Returns the error code whose [code] matches, or `null` if none does.
  static ErrorCode? fromCode(String code) {
    return ErrorCode.values.firstWhereOrNull(
      (errorCode) => errorCode.code == code,
    );
  }
}
