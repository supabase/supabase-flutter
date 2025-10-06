import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:gotrue/src/base64url.dart';
import 'package:gotrue/src/types/auth_exception.dart';
import 'package:gotrue/src/types/jwt.dart';

/// Converts base 10 int into String representation of base 16 int and takes the last two digets.
String dec2hex(int dec) {
  final radixString = '0${dec.toRadixString(16)}';
  return radixString.substring(radixString.length - 2);
}

/// Generates a random code verifier
String generatePKCEVerifier() {
  const verifierLength = 56;
  final random = Random.secure();
  return base64UrlEncode(
      List.generate(verifierLength, (_) => random.nextInt(256))).split('=')[0];
}

String generatePKCEChallenge(String verifier) {
  return base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes)
      .split('=')[0];
}

final uuidRegex =
    RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

void validateUuid(String id) {
  if (!uuidRegex.hasMatch(id)) {
    throw ArgumentError('Invalid id: $id, must be a valid UUID');
  }
}

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
    final headerJson = Base64Url.decodeToString(rawHeader, loose: true);
    final header = JwtHeader.fromJson(json.decode(headerJson));

    // Decode payload
    final payloadJson = Base64Url.decodeToString(rawPayload, loose: true);
    final payload = JwtPayload.fromJson(json.decode(payloadJson));

    // Decode signature
    final signature = Base64Url.decode(rawSignature, loose: true);

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
