// The composed helpers of this package legitimately build on its own
// test-only primitives outside of a test directory.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:clock/clock.dart';
import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:supabase/supabase.dart';

import 'mock_realtime_transport.dart';
import 'session_fixture.dart';
import 'test_jwt.dart';

const _testPublishableKey = 'sb_publishable_supabase_test';

/// A [SupabaseClient] wired for tests.
///
/// Compared to constructing one directly, this turns off the token auto
/// refresh so no timer outlives the test, and defaults [publishableKey] to
/// an `sb_publishable_` key, so signed-out requests carry the headers a
/// production publishable key produces. Database requests and token
/// refreshes are not retried, so a stubbed failure surfaces at once instead
/// of after the real backoff delays; pass [retryOptions] to exercise retry
/// handling. Answer its requests by passing a `MockSupabaseHttpClient` as
/// [httpClient], and its realtime traffic by passing the `call` method of a
/// [MockRealtimeTransport] as [realtimeTransport]:
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
  String? publishableKey,
  WebSocketTransport? realtimeTransport,
  bool autoRefreshToken = false,
  SupabaseRetryOptions retryOptions = const SupabaseRetryOptions(
    enabled: false,
  ),
}) {
  return SupabaseClient(
    url,
    publishableKey ?? _testPublishableKey,
    httpClient: httpClient,
    postgrestOptions: PostgrestClientOptions(retryOptions: retryOptions),
    authOptions: AuthClientOptions(
      autoRefreshToken: autoRefreshToken,
      retryOptions: retryOptions,
    ),
    realtimeOptions: RealtimeClientOptions(transport: realtimeTransport),
  );
}

/// Puts [auth] into a signed-in state without any network traffic, and
/// returns the resulting session.
///
/// The session carries an unsigned access token holding [userId], [role],
/// [email] and [claims], and a user built by [testUserJson] with the same
/// [role], so code under test observes `currentUser`, `currentSession` and
/// the `Authorization` header exactly as after a real sign-in. Subscribers of
/// `onAuthStateChange` receive a `signedIn` event.
///
/// [expiresAt] defaults to an hour from `clock.now()`, so the session stays
/// valid under `withClock` and fake async clocks, and must lie after it; to
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
// ignore: avoid-unnecessary-futures
Future<Session> signInTestUser(
  AuthClient auth, {
  String userId = testUserId,
  String email = 'fake1@email.com',
  String role = 'authenticated',
  Map<String, dynamic> claims = const {},
  DateTime? expiresAt,
}) async {
  final now = clock.now();
  final expiry = expiresAt ?? now.add(const Duration(hours: 1));
  final expirySeconds = expiry.millisecondsSinceEpoch ~/ 1000;
  if (expirySeconds * 1000 <= now.millisecondsSinceEpoch) {
    throw ArgumentError.value(expiresAt, 'expiresAt', 'must lie in the future');
  }
  final accessToken = unsignedTestJwt({
    'exp': expirySeconds,
    'sub': userId,
    'role': role,
    'email': email,
    ...claims,
  });
  final session = Session.fromJson(
    testSessionResponseJson(
      accessToken: accessToken,
      user: testUserJson(id: userId, email: email, role: role),
    ),
  )!;
  // ignore: invalid_use_of_internal_member
  auth.signInWithSession(session);
  return session;
}
