import 'dart:convert';

import 'package:gotrue/src/types/auth_exception.dart';
import 'package:gotrue/src/types/jwt.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

export 'package:supabase_common/supabase_common.dart'
    show generatePKCEVerifier, generatePKCEChallenge, uuidRegex, validateUuid;

/// Decodes a JWT token without performing validation
///
/// Returns a [DecodedJwt] containing the header, payload, signature, and raw parts.
/// Throws [AuthInvalidJwtException] if the JWT structure is invalid.
DecodedJwt decodeJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw AuthInvalidJwtException('Invalid JWT structure');
  }

  final rawHeader = parts[0];
  final rawPayload = parts[1];
  final rawSignature = parts[2];

  try {
    // Decode header
    final headerJson = Base64Url.decodeToString(rawHeader);
    final header = JwtHeader.fromJson(json.decode(headerJson));

    // Decode payload
    final payloadJson = Base64Url.decodeToString(rawPayload);
    final payload = JwtPayload.fromJson(json.decode(payloadJson));

    // Decode signature
    final signature = Base64Url.decodeToBytes(rawSignature);

    return DecodedJwt(
      header: header,
      payload: payload,
      signature: signature,
      raw: JwtRawParts(
        header: rawHeader,
        payload: rawPayload,
        signature: rawSignature,
      ),
    );
  } catch (e) {
    if (e is AuthInvalidJwtException) {
      rethrow;
    }
    throw AuthInvalidJwtException('Failed to decode JWT: $e');
  }
}

/// Decodes only the payload of a JWT without validating the header or signature.
///
/// Useful where just the claims are needed and the token may not carry a
/// well-formed header or signature. Throws [AuthInvalidJwtException] if the
/// structure or payload is invalid.
@internal
JwtPayload decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw AuthInvalidJwtException('Invalid JWT structure');
  }

  try {
    final payloadJson = Base64Url.decodeToString(parts[1]);
    return JwtPayload.fromJson(json.decode(payloadJson));
  } catch (e) {
    if (e is AuthInvalidJwtException) {
      rethrow;
    }
    throw AuthInvalidJwtException('Failed to decode JWT: $e');
  }
}

/// Validates the expiration time of a JWT
///
/// Throws [AuthException] if the exp claim is missing or the JWT has expired.
void validateExp(int? exp) {
  if (exp == null) {
    throw AuthException('Missing exp claim');
  }
  final timeNow = DateTime.now().millisecondsSinceEpoch / 1000;
  if (exp <= timeNow) {
    throw AuthException('JWT has expired');
  }
}
