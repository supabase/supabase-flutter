// The composed helpers of this package legitimately build on its own
// test-only primitives outside of a test directory.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';

import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:supabase/supabase.dart';

import 'session_fixture.dart';
import 'test_jwt.dart';

/// A [SupabaseClient] wired for tests.
///
/// Compared to constructing one directly, this configures the in-memory
/// storage the pkce flow requires, turns off the token auto refresh so no
/// timer outlives the test, and defaults the API key to an unsigned anon JWT.
/// Answer its requests by passing a `MockSupabaseHttpClient` as [httpClient]:
///
/// ```dart
/// final httpClient = MockSupabaseHttpClient()
///   ..stubTable('todos', rows: [
///     {'id': 1, 'task': 'Ship it', 'status': false},
///   ]);
/// final supabase = testSupabaseClient(httpClient: httpClient);
/// addTearDown(supabase.dispose);
///
/// final todos = await supabase.from('todos').select();
/// ```
///
/// The client owns an isolate for JSON decoding, so dispose it when the test
/// ends, for example with `addTearDown(supabase.dispose)`.
@visibleForTesting
SupabaseClient testSupabaseClient({
  Client? httpClient,
  String url = 'http://localhost:54321',
  String? apiKey,
  bool autoRefreshToken = false,
}) {
  return SupabaseClient(
    url,
    apiKey ?? unsignedTestJwt({'role': 'anon', 'iss': 'supabase_testing'}),
    httpClient: httpClient,
    authOptions: AuthClientOptions(
      autoRefreshToken: autoRefreshToken,
      pkceAsyncStorage: MemoryAuthAsyncStorage(),
    ),
  );
}

/// Puts [auth] into a signed-in state without any network traffic, and
/// returns the resulting session.
///
/// The session carries an unsigned access token holding [userId], [role],
/// [email] and [claims], and a user built by [testUserJson], so code under
/// test observes `currentUser`, `currentSession` and the `Authorization`
/// header exactly as after a real sign-in. Subscribers of
/// `onAuthStateChange` receive a `tokenRefreshed` event.
///
/// [expiresAt] defaults to an hour from now and must lie in the future; to
/// exercise expiry handling, build an expired session from the fixtures
/// directly instead.
///
/// ```dart
/// final supabase = testSupabaseClient(httpClient: httpClient);
/// final session = await signInTestUser(supabase.auth);
///
/// expect(supabase.auth.currentUser?.id, session.user.id);
/// ```
@visibleForTesting
Future<Session> signInTestUser(
  AuthClient auth, {
  String userId = testUserId,
  String email = 'fake1@email.com',
  String role = 'authenticated',
  Map<String, dynamic> claims = const {},
  DateTime? expiresAt,
}) async {
  final expiry = expiresAt ?? DateTime.now().add(const Duration(hours: 1));
  final accessToken = unsignedTestJwt({
    'exp': expiry.millisecondsSinceEpoch ~/ 1000,
    'sub': userId,
    'role': role,
    'email': email,
    ...claims,
  });
  final response = await auth.recoverSession(
    jsonEncode(
      testSessionResponseJson(
        accessToken: accessToken,
        user: testUserJson(id: userId, email: email),
      ),
    ),
  );
  return response.session!;
}
