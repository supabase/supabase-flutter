import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

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
