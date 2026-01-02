import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';
import 'package:jose_plus/jose.dart' as jose;

/// Email of a user with unverified factor
const email1 = 'fake1@email.com';

/// Email of a user with verified factor
const email2 = 'fake2@email.com';

/// Phone of [userId1]
const phone1 = '166600000000';

/// User id of user with [email1] and [phone1]
const userId1 = '18bc7a4e-c095-4573-93dc-e0be29bada97';

/// User id of user with [email2]
const userId2 = '28bc7a4e-c095-4573-93dc-e0be29bada97';

/// Factor ID of user with [email1]
const factorId1 = '1d3aa138-da96-4aea-8217-af07daa6b82d';

/// Factor ID of user with [email2]
const factorId2 = '2d3aa138-da96-4aea-8217-af07daa6b82d';

final password = 'secret';

String getNewEmail() {
  final timestamp =
      (DateTime.now().microsecondsSinceEpoch / (1000 * 1000)).round();
  return 'fake$timestamp@email.com';
}

String getNewPhone() {
  final timestamp =
      (DateTime.now().microsecondsSinceEpoch / (1000 * 1000)).round();
  return '$timestamp';
}

/// Generates a service role JWT token for authentication with GoTrue.
///
/// Supports two modes:
/// 1. Symmetric signing (HS256): Uses GOTRUE_JWT_SECRET
/// 2. Asymmetric signing (ES256/RS256): Uses GOTRUE_JWT_KEYS
///
/// The mode is automatically detected based on the presence of GOTRUE_JWT_KEYS.
String getServiceRoleToken(DotEnv env) {
  final jwtKeys = env['GOTRUE_JWT_KEYS'];

  // If GOTRUE_JWT_KEYS is set, use asymmetric signing (ES256/RS256)
  if (jwtKeys != null && jwtKeys.isNotEmpty) {
    return _getServiceRoleTokenAsymmetric(jwtKeys);
  }

  // Otherwise, use symmetric signing (HS256)
  final secret =
      env['GOTRUE_JWT_SECRET'] ?? '37c304f8-51aa-419a-a1af-06154e63707a';
  return _getServiceRoleTokenSymmetric(secret);
}

/// Creates a service role token using symmetric HS256 signing.
String _getServiceRoleTokenSymmetric(String secret) {
  return JWT(
    {
      'role': 'service_role',
    },
  ).sign(SecretKey(secret));
}

/// Creates a service role token using asymmetric signing (ES256/RS256).
///
/// [jwtKeysJson] should be a JSON array of JWKs (JSON Web Keys), typically from the GOTRUE_JWT_KEYS environment variable.
/// The first key in the array is used to sign the token.
String _getServiceRoleTokenAsymmetric(String jwtKeysJson) {
  try {
    final List<dynamic> keysArray = json.decode(jwtKeysJson) as List<dynamic>;
    if (keysArray.isEmpty) {
      throw Exception('Input json array has no JWT keys');
    }

    // Use the first key from the array
    final keyData = keysArray.first as Map<String, dynamic>;
    final jwk = jose.JsonWebKey.fromJson(keyData);

    // Create JWT claims
    final claims = jose.JsonWebTokenClaims.fromJson({
      'role': 'service_role',
    });

    // Create and sign the token
    final builder = jose.JsonWebSignatureBuilder()
      ..jsonContent = claims.toJson()
      ..addRecipient(jwk, algorithm: keyData['alg'] as String?);

    final jws = builder.build();
    return jws.toCompactSerialization();
  } catch (e) {
    throw Exception('Failed to create asymmetric service role token: $e');
  }
}

/// Construct session data for a given expiration date
({String accessToken, String sessionString}) getSessionData(
    DateTime expireDateTime) {
  final expiresAt = expireDateTime.millisecondsSinceEpoch ~/ 1000;
  final accessTokenMid = base64.encode(utf8.encode(json.encode(
      {'exp': expiresAt, 'sub': '1234567890', 'role': 'authenticated'})));
  final accessToken = 'any.$accessTokenMid.any';
  final sessionString =
      '{"access_token":"$accessToken","expires_in":${expireDateTime.difference(DateTime.now()).inSeconds},"refresh_token":"-yeS4omysFs9tpUYBws9Rg","token_type":"bearer","provider_token":null,"provider_refresh_token":null,"user":{"id":"4d2583da-8de4-49d3-9cd1-37a9a74f55bd","app_metadata":{"provider":"email","providers":["email"]},"user_metadata":{"Hello":"World"},"aud":"","email":"fake1680338105@email.com","phone":"","created_at":"2023-04-01T08:35:05.208586Z","confirmed_at":null,"email_confirmed_at":"2023-04-01T08:35:05.220096086Z","phone_confirmed_at":null,"last_sign_in_at":"2023-04-01T08:35:05.222755878Z","role":"","updated_at":"2023-04-01T08:35:05.226938Z"}}';
  return (accessToken: accessToken, sessionString: sessionString);
}

class TestAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _map = {};
  @override
  Future<String?> getItem({required String key}) async {
    return _map[key];
  }

  @override
  Future<void> removeItem({required String key}) async {
    _map.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _map[key] = value;
  }
}
