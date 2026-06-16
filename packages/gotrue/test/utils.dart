import 'dart:convert';

import 'package:dotenv/dotenv.dart';
import 'package:gotrue/gotrue.dart';

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

/// API keys of the local Supabase CLI stack. These are RS256 JWTs signed by the
/// committed supabase/signing_keys.json, so they stay valid as long as that key
/// is in place. Both gotrue and the API gateway verify them against the JWKS.
const _serviceRoleKey =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6IjNkZjU5YWIxLWI4ZWMtNDlkMy05YzkyLThiOWQ0MmNhYzFmZSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MjA5Njg5NTE5Mn0.jO5vwkRNFZTiVHNjFzaypvWV4aJkKm6TvFsdl0W5x9g7LttQMWMopC7HanUpeFLmg4E9gMb-v1e6f6oZ9e0PHYpsRwEdSOxKfYwKhzFI9DsDGLrX4ueArZuKgaV_bulWpwGKI3xwLugeuCp6N0hYFkXvMmUjaKx9nClWckJ33cchSpgjVQ5YxL8PGrUj2Sjhw-5IyGiwrdPfWjTQmpWnCjePoVrRf2jEMF_VGoxDAEqt72w_HGOrdXRFU5BW9-LkvpfzkrTENrj555JtYP4mkZgvUlrkXFRSh010o3n2UehN5WonfDRzwOeTC56QEbPVS6ubvWGR9luykdMNlXawZA';

const _anonKey =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6IjNkZjU5YWIxLWI4ZWMtNDlkMy05YzkyLThiOWQ0MmNhYzFmZSIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjIwOTY4OTUxOTF9.Boe4zFpmRmJRM9b6USbJkZZzg66cXTHWYHm9uGScxnVi-xCXi6jAjy_GGsyKGOgwD110lNzNcdAQtwWjBOz-iBcVfcLpOJjgtFNg80ZK7toO2V0BwhWhAMdic1XnFI3_gxe9iq--iMuNuAebP1uIxGqn-nJ2kdua1cv3g9BZ5UtG9U-I22b4lPTQhdMU7skUsFLxcIpDOb1tS7RafWL3XcobNpd5OnZV_z88fus73DDP9oFKzBsyXARNg3H89IBBd5G9JHpeO4eQdGTPPY4xkGp_zBUnyMJJWTdgXqFjbFHpGpTdD1lSb3TbyeRheAq7IqaAvdqXyaTZVhH7LrZmbw';

String getServiceRoleToken(DotEnv env) =>
    env['GOTRUE_SERVICE_ROLE_TOKEN'] ?? _serviceRoleKey;

String getAnonToken(DotEnv env) => env['GOTRUE_TOKEN'] ?? _anonKey;

/// User id embedded in the session produced by [getSessionData].
const sessionDataUserId = '4d2583da-8de4-49d3-9cd1-37a9a74f55bd';

/// Construct session data for a given expiration date
({String accessToken, String sessionString}) getSessionData(
    DateTime expireDateTime) {
  final expiresAt = expireDateTime.millisecondsSinceEpoch ~/ 1000;
  final accessTokenMid = base64.encode(utf8.encode(json.encode(
      {'exp': expiresAt, 'sub': '1234567890', 'role': 'authenticated'})));
  final accessToken = 'any.$accessTokenMid.any';
  final sessionString =
      '{"access_token":"$accessToken","expires_in":${expireDateTime.difference(DateTime.now()).inSeconds},"refresh_token":"-yeS4omysFs9tpUYBws9Rg","token_type":"bearer","provider_token":null,"provider_refresh_token":null,"user":{"id":"$sessionDataUserId","app_metadata":{"provider":"email","providers":["email"]},"user_metadata":{"Hello":"World"},"aud":"","email":"fake1680338105@email.com","phone":"","created_at":"2023-04-01T08:35:05.208586Z","confirmed_at":null,"email_confirmed_at":"2023-04-01T08:35:05.220096086Z","phone_confirmed_at":null,"last_sign_in_at":"2023-04-01T08:35:05.222755878Z","role":"","updated_at":"2023-04-01T08:35:05.226938Z"}}';
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
