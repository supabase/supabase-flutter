/// Helpers for the widget and unit tests of an app built on
/// `supabase_flutter`.
///
/// [initializeTestSupabase] initializes [Supabase] the way a test needs it:
/// in-memory persistence, no token auto refresh, no deep link detection, and
/// an unsigned test key. Answer the HTTP traffic with a
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

import 'dart:convert';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'supabase_flutter.dart';

/// The publishable key [initializeTestSupabase] uses by default: an unsigned
/// JWT carrying the `anon` role, which the mocked services never verify.
@visibleForTesting
final String testPublishableKey = _unsignedJwt({
  'role': 'anon',
  'iss': 'supabase_flutter_testing',
});

/// Initializes [Supabase] for a test and returns the instance.
///
/// Compared to [Supabase.initialize], this keeps the session in memory
/// through [localStorage], which defaults to [EmptyLocalStorage], stores the
/// pkce code verifier in memory, turns off the token auto refresh so no timer
/// outlives the test, disables deep link detection so no platform channel is
/// touched, and defaults [publishableKey] to [testPublishableKey]. Pass a
/// `MockSupabaseHttpClient` as [httpClient] to answer the requests, and the
/// `call` method of a `MockRealtimeTransport` as [realtimeTransport] to
/// answer the realtime traffic.
///
/// Dispose the instance when the test ends, for example with
/// `addTearDown(supabase.dispose)`, so the next test can initialize again.
@visibleForTesting
Future<Supabase> initializeTestSupabase({
  Client? httpClient,
  String url = 'http://localhost:54321',
  String? publishableKey,
  Map<String, String>? headers,
  WebSocketTransport? realtimeTransport,
  LocalStorage? localStorage,
  bool autoRefreshToken = false,
}) {
  return Supabase.initialize(
    url: url,
    publishableKey: publishableKey ?? testPublishableKey,
    httpClient: httpClient,
    headers: headers,
    realtimeClientOptions: RealtimeClientOptions(transport: realtimeTransport),
    authOptions: FlutterAuthClientOptions(
      autoRefreshToken: autoRefreshToken,
      localStorage: localStorage ?? const EmptyLocalStorage(),
      pkceAsyncStorage: MemoryAuthAsyncStorage(),
      detectSessionInUri: false,
    ),
  );
}

String _unsignedJwt(Map<String, dynamic> claims) {
  final header = base64Url.encode(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final payload = base64Url.encode(utf8.encode(jsonEncode(claims)));
  return '$header.$payload.AAAA';
}
