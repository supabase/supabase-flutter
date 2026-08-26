import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_common/src/random.dart';

/// Generates a random PKCE code verifier.
String generatePKCEVerifier() {
  const verifierLength = 56;
  return base64UrlEncode(randomBytes(verifierLength)).split('=')[0];
}

/// Generates the PKCE code challenge for the given [verifier].
String generatePKCEChallenge(String verifier) {
  return base64UrlEncode(
    sha256.convert(ascii.encode(verifier)).bytes,
  ).split('=')[0];
}
