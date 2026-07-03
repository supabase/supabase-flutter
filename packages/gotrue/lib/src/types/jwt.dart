import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// JWT Header structure
class JwtHeader {
  /// Algorithm used to sign the JWT (e.g., 'RS256', 'ES256', 'HS256')
  final String alg;

  /// Key ID - identifies which key was used to sign the JWT
  final String? kid;

  /// Token type - typically 'JWT'
  final String? typ;

  const JwtHeader({
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
      claims: Map<String, dynamic>.of(json),
    );
  }

  Map<String, dynamic> toJson() {
    return Map.of(claims);
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

  const DecodedJwt({
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

  const JwtRawParts({
    required this.header,
    required this.payload,
    required this.signature,
  });
}

/// Response from getClaims method
class GetClaimsResponse {
  /// JWT claims from the payload
  final JwtPayload claims;

  /// JWT header
  final JwtHeader header;

  /// JWT signature
  final List<int> signature;

  const GetClaimsResponse({
    required this.claims,
    required this.header,
    required this.signature,
  });
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

class JWKSet {
  final List<JWK> keys;

  const JWKSet({required this.keys});

  factory JWKSet.fromJson(Map<String, dynamic> json) {
    final keys =
        (json['keys'] as List<dynamic>?)
            ?.map((e) => JWK.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return JWKSet(keys: keys);
  }

  Map<String, dynamic> toJson() {
    return {
      'keys': keys.map((e) => e.toJson()).toList(),
    };
  }
}

/// {@template jwk}
/// JSON Web Key (JWK) representation.
/// {@endtemplate}
class JWK {
  /// The "kty" (key type) parameter identifies the cryptographic algorithm
  /// family used with the key, such as "RSA" or "EC".
  final String kty;

  /// The "key_ops" (key operations) parameter identifies the cryptographic
  /// operations for which the key is intended to be used.
  final List<String> keyOps;

  /// The "alg" (algorithm) parameter identifies the algorithm intended for
  /// use with the key.
  final String? alg;

  /// The "kid" (key ID) parameter is used to match a specific key.
  final String? kid;

  /// Additional arbitrary properties of the JWK.
  final Map<String, dynamic> _additionalProperties;

  /// {@macro jwk}
  JWK({
    required this.kty,
    required this.keyOps,
    this.alg,
    this.kid,
    Map<String, dynamic>? additionalProperties,
  }) : _additionalProperties = additionalProperties ?? {};

  /// Creates a [JWK] from a JSON map.
  factory JWK.fromJson(Map<String, dynamic> json) {
    final kty = json['kty'] as String;
    final keyOps =
        (json['key_ops'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        [];
    final alg = json['alg'] as String?;
    final kid = json['kid'] as String?;

    final Map<String, dynamic> additionalProperties = Map.of(json);
    additionalProperties.remove('kty');
    additionalProperties.remove('key_ops');
    additionalProperties.remove('alg');
    additionalProperties.remove('kid');

    return JWK(
      kty: kty,
      keyOps: keyOps,
      alg: alg,
      kid: kid,
      additionalProperties: additionalProperties,
    );
  }

  /// Allows accessing additional properties using operator[].
  dynamic operator [](String key) {
    switch (key) {
      case 'kty':
        return kty;
      case 'key_ops':
        return keyOps;
      case 'alg':
        return alg;
      case 'kid':
        return kid;
      default:
        return _additionalProperties[key];
    }
  }

  /// Converts this [JWK] to a JSON map.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'kty': kty,
      'key_ops': keyOps,
      ..._additionalProperties,
    };
    if (alg != null) {
      json['alg'] = alg;
    }
    if (kid != null) {
      json['kid'] = kid;
    }
    return json;
  }

  /// Builds the RSA public key for verifying RS256 JWTs from this JWK's
  /// modulus (`n`) and exponent (`e`).
  ///
  /// The key is assembled as a PKCS#1 `RSAPublicKey` DER structure and handed to
  /// [RSAPublicKey.bytes]. This avoids `JWTKey.fromJWK`, which is only available
  /// in dart_jsonwebtoken 3.x and would force a dependency bump that is
  /// incompatible with the minimum supported Flutter version.
  // TODO: replace this manual DER assembly with `JWTKey.fromJWK` once the
  // minimum Flutter is >= 3.29.0 (Dart 3.7.0), whose flutter_test bundles
  // clock 1.1.2 and so allows dart_jsonwebtoken 3.x. fromJWK also adds EC
  // (ES256) support.
  RSAPublicKey get publicKey {
    final modulus = _base64UrlToBytes(this['n'] as String);
    final exponent = _base64UrlToBytes(this['e'] as String);
    final der = _derSequence([
      _derInteger(modulus),
      _derInteger(exponent),
    ]);
    return RSAPublicKey.bytes(Uint8List.fromList(der));
  }
}

List<int> _base64UrlToBytes(String input) {
  return base64Url.decode(base64Url.normalize(input));
}

/// DER-encodes an unsigned big-endian integer (prefixing a zero byte when the
/// high bit is set so it is not interpreted as negative).
List<int> _derInteger(List<int> bytes) {
  var content = bytes;
  var start = 0;
  while (start < content.length - 1 && content[start] == 0) {
    start++;
  }
  content = content.sublist(start);
  if (content.isNotEmpty && (content[0] & 0x80) != 0) {
    content = [0, ...content];
  }
  return [0x02, ..._derLength(content.length), ...content];
}

List<int> _derSequence(List<List<int>> elements) {
  final content = elements.expand((element) => element).toList();
  return [0x30, ..._derLength(content.length), ...content];
}

List<int> _derLength(int length) {
  if (length < 0x80) return [length];
  final lengthBytes = <int>[];
  var remaining = length;
  while (remaining > 0) {
    lengthBytes.insert(0, remaining & 0xff);
    remaining >>= 8;
  }
  return [0x80 | lengthBytes.length, ...lengthBytes];
}
