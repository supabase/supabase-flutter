import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Generates a random PKCE code verifier.
String generatePKCEVerifier() {
  const verifierLength = 56;
  final random = Random.secure();
  return base64UrlEncode(
    List.generate(verifierLength, (_) => random.nextInt(256)),
  ).split('=')[0];
}

/// Generates the PKCE code challenge for the given [verifier].
String generatePKCEChallenge(String verifier) {
  return base64UrlEncode(
    sha256.convert(ascii.encode(verifier)).bytes,
  ).split('=')[0];
}
