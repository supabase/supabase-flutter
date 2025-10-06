/// JWT Header structure
class JwtHeader {
  /// Algorithm used to sign the JWT (e.g., 'RS256', 'ES256', 'HS256')
  final String alg;

  /// Key ID - identifies which key was used to sign the JWT
  final String? kid;

  /// Token type - typically 'JWT'
  final String? typ;

  JwtHeader({
    required this.alg,
    this.kid,
    this.typ,
  });

  factory JwtHeader.fromJson(Map<String, dynamic> json) {
    return JwtHeader(
      alg: json['alg'] as String,
      kid: json['kid'] as String?,
      typ: json['typ'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alg': alg,
      if (kid != null) 'kid': kid,
      if (typ != null) 'typ': typ,
    };
  }
}

/// JWT Payload structure with standard claims
class JwtPayload {
  /// Issuer - identifies principal that issued the JWT
  final String? iss;

  /// Subject - identifies the subject of the JWT
  final String? sub;

  /// Audience - identifies recipients that the JWT is intended for
  final dynamic aud;

  /// Expiration time - timestamp after which the JWT must not be accepted
  final int? exp;

  /// Not Before - timestamp before which the JWT must not be accepted
  final int? nbf;

  /// Issued At - timestamp when the JWT was issued
  final int? iat;

  /// JWT ID - unique identifier for the JWT
  final String? jti;

  /// Additional claims stored in the payload
  final Map<String, dynamic> claims;

  JwtPayload({
    this.iss,
    this.sub,
    this.aud,
    this.exp,
    this.nbf,
    this.iat,
    this.jti,
    Map<String, dynamic>? claims,
  }) : claims = claims ?? {};

  factory JwtPayload.fromJson(Map<String, dynamic> json) {
    return JwtPayload(
      iss: json['iss'] as String?,
      sub: json['sub'] as String?,
      aud: json['aud'],
      exp: json['exp'] as int?,
      nbf: json['nbf'] as int?,
      iat: json['iat'] as int?,
      jti: json['jti'] as String?,
      claims: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(claims);
  }
}

/// Decoded JWT structure
class DecodedJwt {
  /// JWT header
  final JwtHeader header;

  /// JWT payload
  final JwtPayload payload;

  /// JWT signature as raw bytes
  final List<int> signature;

  /// Raw encoded parts of the JWT
  final JwtRawParts raw;

  DecodedJwt({
    required this.header,
    required this.payload,
    required this.signature,
    required this.raw,
  });
}

/// Raw encoded parts of a JWT
class JwtRawParts {
  /// Raw base64url encoded header
  final String header;

  /// Raw base64url encoded payload
  final String payload;

  /// Raw base64url encoded signature
  final String signature;

  JwtRawParts({
    required this.header,
    required this.payload,
    required this.signature,
  });
}

/// Response from getClaims method
class GetClaimsResponse {
  /// JWT claims from the payload
  final Map<String, dynamic> claims;

  GetClaimsResponse({required this.claims});
}

/// Options for getClaims method
class GetClaimsOptions {
  /// If set to `true`, the `exp` claim will not be validated against the current time.
  /// This allows you to extract claims from expired JWTs without getting an error.
  final bool allowExpired;

  const GetClaimsOptions({
    this.allowExpired = false,
  });
}
