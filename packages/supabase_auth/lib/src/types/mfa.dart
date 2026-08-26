import 'package:supabase_auth/supabase_auth.dart';
import 'package:supabase_common/supabase_common.dart';

/// The response of `AuthMFAApi.enroll`.
class AuthMFAEnrollResponse {
  const AuthMFAEnrollResponse({
    required this.id,
    required this.type,
    this.totp,
    this.phone,
  });

  factory AuthMFAEnrollResponse.fromJson(Map<String, dynamic> json) {
    final type = FactorType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => FactorType.unknown,
    );
    return AuthMFAEnrollResponse(
      id: json['id'] as String,
      type: type,
      totp: type == FactorType.totp && json['totp'] != null
          ? TOTPEnrollment.fromJson(json['totp'] as Map<String, dynamic>)
          : null,
      phone: type == FactorType.phone && json['phone'] != null
          ? PhoneEnrollment._fromJsonValue(json['phone'])
          : null,
    );
  }

  /// ID of the factor that was just enrolled (in an unverified state).
  final String id;

  /// Type of MFA factor. Supports both `[FactorType.totp]` and
  /// `[FactorType.phone]`.
  final FactorType type;

  /// TOTP enrollment information (only present when type is totp).
  final TOTPEnrollment? totp;

  /// Phone enrollment information (only present when type is phone).
  final PhoneEnrollment? phone;
}

/// TOTP enrollment information returned by `AuthMFAApi.enroll`.
class TOTPEnrollment {
  const TOTPEnrollment({
    required this.qrCode,
    required this.secret,
    required this.uri,
  });

  factory TOTPEnrollment.fromJson(Map<String, dynamic> json) {
    return TOTPEnrollment(
      qrCode: json['qr_code'] as String,
      secret: json['secret'] as String,
      uri: json['uri'] as String,
    );
  }

  /// A `data:image/svg+xml;utf-8,` URL containing a QR code that encodes the
  /// authenticator URI.
  ///
  /// Ready to use directly as an image source. Avoid logging this value to
  /// the console.
  final String qrCode;

  /// The TOTP secret (also encoded in the QR code).
  ///
  /// Show this secret in a password-style field to the user, in case they are
  /// unable to scan the QR code. Avoid logging this value to the console.
  final String secret;

  /// The authenticator URI encoded within the QR code, should you need to use
  /// it. Avoid logging this value to the console.
  final String uri;
}

/// Phone enrollment information returned by `AuthMFAApi.enroll`.
class PhoneEnrollment {
  const PhoneEnrollment({
    required this.phone,
  });

  factory PhoneEnrollment.fromJson(Map<String, dynamic> json) {
    return PhoneEnrollment(
      phone: json['phone'] as String,
    );
  }

  factory PhoneEnrollment._fromJsonValue(dynamic value) => switch (value) {
    // Server returns phone number as a string directly
    String() => PhoneEnrollment(phone: value),
    // Server returns phone data as an object
    Map<String, dynamic>() => PhoneEnrollment.fromJson(value),
    _ => throw ArgumentError(
      'Invalid phone enrollment data type: ${value.runtimeType}',
    ),
  };

  /// The phone number that will receive the SMS OTP.
  final String phone;
}

/// The response of `AuthMFAApi.challenge`.
class AuthMFAChallengeResponse {
  const AuthMFAChallengeResponse({required this.id, required this.expiresAt});

  factory AuthMFAChallengeResponse.fromJson(Map<String, dynamic> json) {
    return AuthMFAChallengeResponse(
      id: json['id'] as String,
      expiresAt: parseUnixSeconds(json, 'expires_at'),
    );
  }

  /// ID of the newly created challenge.
  final String id;

  /// Timestamp when this challenge will no longer be usable.
  final DateTime expiresAt;
}

/// The response of `AuthMFAApi.verify` and `AuthMFAApi.challengeAndVerify`.
class AuthMFAVerifyResponse {
  const AuthMFAVerifyResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.refreshToken,
    required this.user,
  });

  factory AuthMFAVerifyResponse.fromJson(Map<String, dynamic> json) {
    final expiresInValue = json['expires_in'];
    if (expiresInValue is! num) {
      throw FormatException(
        'Expected expires_in to be a number, got ${expiresInValue.runtimeType}',
        json.toString(),
      );
    }
    final expiresIn = expiresInValue.toInt();
    final userJson = json['user'];
    if (userJson is! Map<String, dynamic>) {
      throw FormatException(
        'Expected user to be an object, got ${userJson.runtimeType}',
        json.toString(),
      );
    }
    final user = User.fromJson(userJson);
    if (user == null) {
      throw FormatException(
        'Failed to parse user object: missing required fields',
        json.toString(),
      );
    }
    return AuthMFAVerifyResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: Duration(seconds: expiresIn),
      refreshToken: json['refresh_token'] as String,
      user: user,
    );
  }

  /// New access token (JWT) after successful verification.
  final String accessToken;

  /// Type of token, typically `Bearer`.
  final String tokenType;

  /// Duration in which the access token will expire.
  final Duration expiresIn;

  /// Refresh token you can use to obtain new access tokens when expired.
  final String refreshToken;

  /// Updated user profile.
  final User user;
}

/// The response of `AuthMFAApi.unenroll`.
class AuthMFAUnenrollResponse {
  const AuthMFAUnenrollResponse({required this.id});

  factory AuthMFAUnenrollResponse.fromJson(Map<String, dynamic> json) {
    return AuthMFAUnenrollResponse(id: json['id'] as String);
  }

  /// ID of the factor that was successfully unenrolled.
  final String id;
}

/// The response of `AuthMFAApi.listFactors`.
class AuthMFAListFactorsResponse {
  const AuthMFAListFactorsResponse({
    required this.all,
    required this.totp,
    required this.phone,
    this.webauthn = const [],
  });

  /// Every MFA factor enabled for the user, of any status.
  final List<Factor> all;

  /// The user's verified TOTP factors.
  final List<Factor> totp;

  /// The user's verified phone factors.
  final List<Factor> phone;

  /// The user's verified WebAuthn factors.
  final List<Factor> webauthn;
}

/// The response of `AuthAdminMFAApi.listFactors`.
class AuthMFAAdminListFactorsResponse {
  const AuthMFAAdminListFactorsResponse({required this.factors});

  factory AuthMFAAdminListFactorsResponse.fromJson(Map<String, dynamic> json) {
    final factorsList = json['factors'];
    if (factorsList is! List) {
      throw FormatException(
        'Expected factors to be a list, got ${factorsList.runtimeType}',
        json.toString(),
      );
    }
    return AuthMFAAdminListFactorsResponse(
      factors: factorsList
          .map((e) => Factor.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// All factors attached to the user.
  final List<Factor> factors;
}

/// The response of `AuthAdminMFAApi.deleteFactor`.
class AuthMFAAdminDeleteFactorResponse {
  const AuthMFAAdminDeleteFactorResponse({required this.id});

  factory AuthMFAAdminDeleteFactorResponse.fromJson(Map<String, dynamic> json) {
    return AuthMFAAdminDeleteFactorResponse(id: json['id'] as String);
  }

  /// ID of the factor that was successfully deleted.
  final String id;
}

/// Whether an MFA [Factor] can be used to satisfy a challenge.
enum FactorStatus {
  /// The factor completed enrollment and can be used to verify a challenge.
  verified,

  /// The factor has not completed enrollment yet.
  unverified,

  /// Returned when the backend sends an unknown status value.
  /// This allows forward compatibility with new status types.
  unknown,
}

/// The kind of second factor an MFA [Factor] uses.
enum FactorType {
  /// A time-based one-time password from an authenticator app.
  totp,

  /// A one-time password sent by SMS.
  phone,

  /// A WebAuthn security key or platform authenticator.
  webauthn,

  /// Returned when the backend sends an unknown factor type.
  /// This allows forward compatibility with new factor types.
  unknown,
}

/// An MFA factor enrolled by a user.
class Factor {
  const Factor({
    required this.id,
    required this.friendlyName,
    required this.factorType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Factor.fromJson(Map<String, dynamic> json) {
    return Factor(
      id: json['id'] as String,
      friendlyName: json['friendly_name'] as String?,
      factorType: FactorType.values.firstWhere(
        (e) => e.name == json['factor_type'],
        orElse: () => FactorType.unknown,
      ),
      status: FactorStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => FactorStatus.unknown,
      ),
      createdAt: parseIso8601(json, 'created_at'),
      updatedAt: parseIso8601(json, 'updated_at'),
    );
  }

  /// ID of the factor.
  final String id;

  /// Friendly name of the factor, useful to disambiguate between multiple
  /// factors.
  final String? friendlyName;

  /// Type of factor. Supports `totp`, `phone` and `webauthn`.
  final FactorType factorType;

  /// Factor's status.
  final FactorStatus status;

  /// When the factor was enrolled.
  final DateTime createdAt;

  /// When the factor was last updated, for example when it was verified.
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'friendly_name': friendlyName,
      'factor_type': factorType.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Factor &&
        other.id == id &&
        other.friendlyName == friendlyName &&
        other.factorType == factorType &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        friendlyName.hashCode ^
        factorType.hashCode ^
        status.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'Factor(id: $id, friendlyName: $friendlyName, factorType: '
        '${factorType.name}, status: ${status.name}, createdAt: $createdAt, '
        'updatedAt: $updatedAt)';
  }
}

/// How strongly a session's identity has been verified.
enum AuthenticatorAssuranceLevel {
  /// The user's identity has been verified only with a conventional login
  /// (email+password, OTP, magic link, social login, etc.).
  aal1,

  /// The user's identity has been verified both with a conventional login and
  /// at least one MFA factor.
  aal2,
}

/// The response of `AuthMFAApi.getAuthenticatorAssuranceLevel`.
class AuthMFAGetAuthenticatorAssuranceLevelResponse {
  const AuthMFAGetAuthenticatorAssuranceLevelResponse({
    required this.currentLevel,
    required this.nextLevel,
    required this.currentAuthenticationMethods,
  });

  /// Current AAL level of the session.
  final AuthenticatorAssuranceLevel? currentLevel;

  /// Next possible AAL level for the session. If the next level is higher than
  /// the current one, the user should go through MFA.
  ///
  /// see [AuthMFAApi.challenge]
  final AuthenticatorAssuranceLevel? nextLevel;

  /// A list of all authentication methods attached to this session.
  ///
  /// Use the information here to detect the last time a user verified a factor,
  /// for example if implementing a step-up scenario.
  final List<AuthenticationMethodReferenceEntry> currentAuthenticationMethods;
}

/// A method used to verify a user's identity, reported in an
/// [AuthenticationMethodReferenceEntry].
enum AuthenticationMethodReference {
  /// Signed in with a password.
  password('password'),

  /// Signed in with a one-time password sent by SMS or email.
  otp('otp'),

  /// Signed in with a third-party OAuth provider.
  oauth('oauth'),

  /// Verified an MFA TOTP factor.
  totp('totp'),

  /// Signed in with a magic link.
  magicLink('magiclink'),

  /// Signed in through a password recovery link.
  recovery('recovery'),

  /// Signed in by accepting an invite.
  invite('invite'),

  /// Signed in through SAML SSO.
  ssoSaml('sso/saml'),

  /// Signed up with an email and password.
  emailSignUp('email/signup'),

  /// Verified an email change.
  emailChange('email_change'),

  /// Refreshed the session's access token.
  tokenRefresh('token_refresh'),

  /// Signed in anonymously.
  anonymous('anonymous'),

  /// Verified an MFA phone factor.
  mfaPhone('mfa/phone'),

  /// Verified an MFA WebAuthn factor.
  mfaWebauthn('mfa/webauthn'),

  /// Signed in with a passkey.
  passkey('passkey'),

  /// Returned when the backend sends an unknown method.
  /// This allows forward compatibility with new methods.
  unknown('unknown');

  const AuthenticationMethodReference(this.value);

  /// The wire value received from the server.
  final String value;
}

/// An authentication method reference (AMR) entry.
///
/// An entry designates what method was used by the user to verify their
/// identity and at what time.
///
/// see [AuthMFAApi.getAuthenticatorAssuranceLevel].
///
class AuthenticationMethodReferenceEntry {
  const AuthenticationMethodReferenceEntry({
    required this.method,
    required this.timestamp,
  });

  factory AuthenticationMethodReferenceEntry.fromJson(
    Map<String, dynamic> json,
  ) {
    return AuthenticationMethodReferenceEntry(
      method: AuthenticationMethodReference.values.firstWhere(
        (e) => e.value == json['method'],
        orElse: () => AuthenticationMethodReference.unknown,
      ),
      timestamp: parseUnixSeconds(json, 'timestamp'),
    );
  }

  /// authentication method name
  final AuthenticationMethodReference method;

  /// Timestamp when the method was successfully used.
  final DateTime timestamp;
}
