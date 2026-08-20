import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

String _base64UrlNoPadding(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// Crafts a JWT by base64url-encoding [claims] directly.
///
/// Unlike a JWT library, this gives exact control over every claim: no
/// auto-injected `iat`, no claim overrides. The signature is a stub, for
/// code paths that decode without verifying.
@visibleForTesting
String unsignedTestJwt(Map<String, dynamic> claims) {
  final header = base64Url.encode(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final body = base64Url.encode(utf8.encode(jsonEncode(claims)));
  const signature = 'AAAA';
  return '$header.$body.$signature';
}

/// Crafts an HS256 JWT carrying exactly [claims], signed with [secret].
@visibleForTesting
String signedTestJwt(Map<String, dynamic> claims, {required String secret}) {
  final header = _base64UrlNoPadding(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final payload = _base64UrlNoPadding(utf8.encode(jsonEncode(claims)));
  final signingInput = '$header.$payload';
  final signature = _base64UrlNoPadding(
    Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(signingInput)).bytes,
  );
  return '$signingInput.$signature';
}
