/// Helpers for the widget and unit tests of an app built on
/// `supabase_flutter`.
///
/// [initializeTestSupabase] initializes [Supabase] the way a test needs it:
/// in-memory persistence, no token auto refresh, no deep link detection, and
/// a test publishable key. Answer the HTTP traffic with a
/// `MockSupabaseHttpClient` from `package:supabase_test`, and realtime with
/// its `MockRealtimeTransport`:
///
/// ```dart
/// import 'package:supabase_flutter/testing.dart';
/// import 'package:supabase_test/supabase_test.dart';
///
/// testWidgets('shows the open todos', (tester) async {
///   final httpClient = MockSupabaseHttpClient()
///     ..stubTable('todos', rows: [{'id': 1, 'task': 'Ship it'}]);
///   final supabase = await initializeTestSupabase(httpClient: httpClient);
///   addTearDown(supabase.dispose);
///
///   await tester.pumpWidget(const MyApp());
///   await tester.pumpAndSettle();
///
///   expect(find.text('Ship it'), findsOneWidget);
/// });
/// ```
library;

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'supabase_flutter.dart';

/// The publishable key [initializeTestSupabase] uses by default.
///
/// It carries the `sb_publishable_` prefix, so signed-out requests carry the
/// headers a production publishable key produces.
@visibleForTesting
const testPublishableKey = 'sb_publishable_supabase_flutter_testing';

/// Initializes [Supabase] for a test and returns the instance.
///
/// Compared to [Supabase.initialize], this keeps the session and the pkce
/// code verifier in memory through [asyncStorage], which defaults to a fresh
/// [MemoryAuthAsyncStorage], turns off the token auto refresh so no timer
/// outlives the test, disables deep link detection so no platform channel is
/// touched, turns off the retries of database requests and token refreshes so
/// a stubbed failure surfaces at once, and defaults [publishableKey] to
/// [testPublishableKey]. Pass [retryOptions] to exercise retry handling. Pass a
/// `MockSupabaseHttpClient` as [httpClient] to answer the requests, and the
/// `call` method of a `MockRealtimeTransport` as [realtimeTransport] to
/// answer the realtime traffic, the same way `testSupabaseClient` takes them.
///
/// Dispose the instance when the test ends, for example with
/// `addTearDown(supabase.dispose)`, so the next test can initialize again.
/// Throws a [StateError] when an earlier test left [Supabase] initialized,
/// since that instance still holds the earlier test's mocks.
@visibleForTesting
Future<Supabase> initializeTestSupabase({
  Client? httpClient,
  String url = 'http://localhost:54321',
  String? publishableKey,
  Map<String, String>? headers,
  WebSocketTransport? realtimeTransport,
  AuthAsyncStorage? asyncStorage,
  bool autoRefreshToken = false,
  SupabaseRetryOptions retryOptions = const SupabaseRetryOptions(
    enabled: false,
  ),
}) {
  if (Supabase.isInitializingOrInitialized) {
    return Future.error(
      StateError(
        'Supabase is already initialized. Dispose it at the end of every '
        'test, for example with addTearDown(supabase.dispose).',
      ),
    );
  }
  return Supabase.initialize(
    url: url,
    publishableKey: publishableKey ?? testPublishableKey,
    httpClient: httpClient,
    headers: headers,
    realtimeOptions: RealtimeClientOptions(transport: realtimeTransport),
    postgrestOptions: PostgrestClientOptions(retryOptions: retryOptions),
    authOptions: FlutterAuthClientOptions(
      autoRefreshToken: autoRefreshToken,
      retryOptions: retryOptions,
      asyncStorage: asyncStorage ?? MemoryAuthAsyncStorage(),
      detectSessionInUri: false,
    ),
  );
}
