import 'package:gotrue/gotrue.dart';

class AuthMFAEnrollResponse {
  /// ID of the factor that was just enrolled (in an unverified state).
  final String id;

  /// Type of MFA factor. Supports both `[FactorType.totp]` and `[FactorType.phone]`.
  final FactorType type;

  /// TOTP enrollment information (only present when type is totp).
  final TOTPEnrollment? totp;

  /// Phone enrollment information (only present when type is phone).
  final PhoneEnrollment? phone;

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
}

class TOTPEnrollment {
  ///Contains a QR code encoding the authenticator URI.
  ///
  ///You can convert it to a URL by prepending `data:image/svg+xml;utf-8,` to the value. Avoid logging this value to the console.
  final String qrCode;

  ///The TOTP secret (also encoded in the QR code).
  ///
  ///Show this secret in a password-style field to the user, in case they are unable to scan the QR code. Avoid logging this value to the console.
  final String secret;

  ///The authenticator URI encoded within the QR code, should you need to use it. Avoid logging this value to the console.
  final String uri;

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
}

class PhoneEnrollment {
  /// The phone number that will receive the SMS OTP.
  final String phone;

  const PhoneEnrollment({
    required this.phone,
  });

  factory PhoneEnrollment.fromJson(Map<String, dynamic> json) {
    return PhoneEnrollment(
      phone: json['phone'] as String,
    );
  }

  factory PhoneEnrollment._fromJsonValue(dynamic value) {
    if (value is String) {
      // Server returns phone number as a string directly
      return PhoneEnrollment(phone: value);
    } else if (value is Map<String, dynamic>) {
      // Server returns phone data as an object
      return PhoneEnrollment.fromJson(value);
    } else {
      throw ArgumentError(
          'Invalid phone enrollment data type: ${value.runtimeType}');
    }
  }
}

class AuthMFAChallengeResponse {
  /// ID of the newly created challenge.
  final String id;

  /// Timestamp when this challenge will no longer be usable.
  final DateTime expiresAt;

  const AuthMFAChallengeResponse({required this.id, required this.expiresAt});

  factory AuthMFAChallengeResponse.fromJson(Map<String, dynamic> json) {
    final expiresAtValue = json['expires_at'];
    if (expiresAtValue is! num) {
      throw FormatException(
        'Expected expires_at to be a number, got ${expiresAtValue.runtimeType}',
        json.toString(),
      );
    }
    final expiresAt = expiresAtValue.toInt();
    return AuthMFAChallengeResponse(
      id: json['id'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
    );
  }
}

class AuthMFAVerifyResponse {
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
}

class AuthMFAUnenrollResponse {
  /// ID of the factor that was successfully unenrolled.
  final String id;

  const AuthMFAUnenrollResponse({required this.id});

  factory AuthMFAUnenrollResponse.fromJson(Map<String, dynamic> json) {
    return AuthMFAUnenrollResponse(id: json['id'] as String);
  }
}

class AuthMFAListFactorsResponse {
  final List<Factor> all;
  final List<Factor> totp;
  final List<Factor> phone;

  AuthMFAListFactorsResponse({
    required this.all,
    required this.totp,
    required this.phone,
  });
}

class AuthMFAAdminListFactorsResponse {
  /// All factors attached to the user.
  final List<Factor> factors;

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
}

class AuthMFAAdminDeleteFactorResponse {
  /// ID of the factor that was successfully deleted.
  final String id;

  const AuthMFAAdminDeleteFactorResponse({required this.id});

  factory AuthMFAAdminDeleteFactorResponse.fromJson(Map<String, dynamic> json) {
    return AuthMFAAdminDeleteFactorResponse(id: json['id'] as String);
  }
}

enum FactorStatus {
  verified,
  unverified,

  /// Returned when the backend sends an unknown status value.
  /// This allows forward compatibility with new status types.
  unknown,
}

enum FactorType {
  totp,
  phone,

  /// Returned when the backend sends an unknown factor type.
  /// This allows forward compatibility with new factor types.
  unknown,
}

class Factor {
  /// ID of the factor.
  final String id;

  /// Friendly name of the factor, useful to disambiguate between multiple factors.
  final String? friendlyName;

  /// Type of factor. Supports both `totp` and `phone`.
  final FactorType factorType;

  /// Factor's status.
  final FactorStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Factor({
    required this.id,
    required this.friendlyName,
    required this.factorType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Factor.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(String key) {
      final value = json[key];
      if (value is! String) {
        throw FormatException(
          'Expected $key to be a string, got ${value.runtimeType}',
          json.toString(),
        );
      }
      try {
        return DateTime.parse(value);
      } on FormatException {
        throw FormatException(
          'Invalid date format for $key: $value',
          json.toString(),
        );
      }
    }

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
      createdAt: parseDateTime('created_at'),
      updatedAt: parseDateTime('updated_at'),
    );
  }

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
}

enum AuthenticatorAssuranceLevels {
  // The user's identity has been verified only with a conventional login (email+password, OTP, magic link, social login, etc.).
  aal1,

  // The user's identity has been verified both with a conventional login and at least one MFA factor.
  aal2,
}

class AuthMFAGetAuthenticatorAssuranceLevelResponse {
  /// Current AAL level of the session.
  final AuthenticatorAssuranceLevels? currentLevel;

  /// Next possible AAL level for the session. If the next level is higher than the current one, the user should go through MFA.
  ///
  /// see [GoTrueMFAApi.challenge]
  final AuthenticatorAssuranceLevels? nextLevel;

  /// A list of all authentication methods attached to this session.
  ///
  /// Use the information here to detect the last time a user verified a factor, for example if implementing a step-up scenario.
  final List<AMREntry> currentAuthenticationMethods;

  const AuthMFAGetAuthenticatorAssuranceLevelResponse({
    required this.currentLevel,
    required this.nextLevel,
    required this.currentAuthenticationMethods,
  });
}

enum AMRMethod {
  password('password'),
  otp('otp'),
  oauth('oauth'),
  totp('totp'),
  magiclink('magiclink'),
  recovery('recovery'),
  invite('invite'),
  ssoSaml('sso/saml'),
  emailSignUp('email/signup'),
  emailChange('email_change'),
  tokenRefresh('token_refresh'),
  anonymous('anonymous'),
  mfaPhone('mfa/phone'),
  unknown('unknown');

  final String code;
  const AMRMethod(this.code);
}

/// An authentication method reference (AMR) entry.
///
/// An entry designates what method was used by the user to verify their
/// identity and at what time.
///
/// see [GoTrueMFAApi.getAuthenticatorAssuranceLevel].
///
class AMREntry {
  /// authentication method name
  final AMRMethod method;

  /// Timestamp when the method was successfully used.
  final DateTime timestamp;

  const AMREntry({required this.method, required this.timestamp});

  factory AMREntry.fromJson(Map<String, dynamic> json) {
    final timestampValue = json['timestamp'];
    if (timestampValue is! num) {
      throw FormatException(
        'Expected timestamp to be a number, got ${timestampValue.runtimeType}',
        json.toString(),
      );
    }
    final timestamp = timestampValue.toInt();
    return AMREntry(
      method: AMRMethod.values.firstWhere(
        (e) => e.code == json['method'],
        orElse: () => AMRMethod.unknown,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
    );
  }
}
