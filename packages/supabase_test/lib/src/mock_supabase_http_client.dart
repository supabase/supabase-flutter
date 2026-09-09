// The composed helpers of this package legitimately build on its own
// test-only primitives outside of a test directory.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'mock_http_clients.dart';
import 'session_fixture.dart';
import 'test_jwt.dart';

/// A request a [MockSupabaseHttpClient] has answered, with its body already
/// read, so a test can assert on what the code under test sent.
@visibleForTesting
class RecordedRequest {
  const RecordedRequest._(this.method, this.url, this.headers, this.bodyBytes);

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final Uint8List bodyBytes;

  /// The request body decoded as UTF-8.
  String get body => utf8.decode(bodyBytes);

  /// The request body decoded as JSON.
  dynamic get jsonBody => jsonDecode(body);

  @override
  String toString() => '$method $url';
}

class _Stub {
  _Stub({
    required this.method,
    required this.path,
    required this.respond,
    required this.remaining,
  });

  final String? method;
  final String? path;
  final StreamedResponse Function(BaseRequest request) respond;
  int? remaining;

  bool matches(BaseRequest request) {
    if (remaining == 0) {
      return false;
    }
    if (method != null &&
        method!.toUpperCase() != request.method.toUpperCase()) {
      return false;
    }
    if (path != null && path != request.url.path) {
      return false;
    }
    return true;
  }

  @override
  String toString() => '${method ?? '(any method)'} ${path ?? '(any path)'}';
}

/// A mock HTTP client that answers Supabase requests from stubs registered
/// per endpoint, and records every request it answered in [requests].
///
/// Register stubs with [stub], or with the endpoint shorthands [stubTable],
/// [stubRpc], [stubEdgeFunction] and [stubSignIn], then hand the client to a
/// `SupabaseClient` (for example through `testSupabaseClient`):
///
/// ```dart
/// final httpClient = MockSupabaseHttpClient()
///   ..stubTable('todos', rows: [
///     {'id': 1, 'task': 'Ship it', 'status': false},
///   ]);
/// final supabase = testSupabaseClient(httpClient: httpClient);
///
/// final todos = await supabase.from('todos').select();
/// ```
///
/// The latest registered stub that matches a request answers it, so a stub
/// registered inside a test overrides one registered in `setUp`. A request no
/// stub matches throws a [StateError] naming the request and the registered
/// stubs.
@visibleForTesting
class MockSupabaseHttpClient extends BaseClient {
  final _stubs = <_Stub>[];

  /// Every request this client has answered, oldest first.
  final requests = <RecordedRequest>[];

  /// Answers requests matching [method] and [path] with [body] encoded as
  /// JSON under [statusCode].
  ///
  /// A null [method] or [path] matches any method or path; [path] is compared
  /// against the path of the request URL, ignoring the query. A null [body]
  /// produces an empty response body. [times] limits how many requests the
  /// stub answers before it stops matching, so consecutive stubs of the same
  /// endpoint can model state that changes between calls.
  void stub(
    Object? body, {
    String? method,
    String? path,
    int statusCode = 200,
    Map<String, String> headers = const {},
    int? times,
  }) {
    _stubs.add(
      _Stub(
        method: method,
        path: path,
        remaining: times,
        respond: (request) => body == null
            ? StreamedResponse(
                const Stream.empty(),
                statusCode,
                request: request,
                headers: headers,
              )
            : jsonStreamedResponse(
                body,
                statusCode: statusCode,
                request: request,
                headers: headers,
              ),
      ),
    );
  }

  /// Answers database requests for [table] with [rows].
  ///
  /// Stubs the PostgREST endpoint `/rest/v1/[table]` that `select`, `insert`,
  /// `update`, `upsert` and `delete` are served through. A null [method]
  /// matches all of them; pass `'GET'` or `'POST'` to answer reads and writes
  /// differently.
  void stubTable(
    String table, {
    Object? rows,
    String? method,
    int statusCode = 200,
    int? times,
  }) {
    stub(
      rows,
      method: method,
      path: '/rest/v1/$table',
      statusCode: statusCode,
      times: times,
    );
  }

  /// Answers calls of the Postgres function [function] made through `rpc`
  /// with [body].
  void stubRpc(
    String function, {
    Object? body,
    int statusCode = 200,
    int? times,
  }) {
    stub(
      body,
      path: '/rest/v1/rpc/$function',
      statusCode: statusCode,
      times: times,
    );
  }

  /// Answers invocations of the edge function [function] with [body].
  void stubEdgeFunction(
    String function, {
    Object? body,
    int statusCode = 200,
    int? times,
  }) {
    stub(
      body,
      path: '/functions/v1/$function',
      statusCode: statusCode,
      times: times,
    );
  }

  /// Answers the token endpoint, so password, OTP and refresh token sign-ins
  /// succeed with a session for [user], which defaults to [testUserJson].
  ///
  /// The session carries an unsigned access token holding the id of [user] as
  /// its `sub` claim and expiring at [expiresAt], which defaults to an hour
  /// from now.
  void stubSignIn({
    Map<String, dynamic>? user,
    DateTime? expiresAt,
    int? times,
  }) {
    final userJson = user ?? testUserJson();
    final expiry = expiresAt ?? DateTime.now().add(const Duration(hours: 1));
    final accessToken = unsignedTestJwt({
      'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      'sub': userJson['id'],
      'role': 'authenticated',
    });
    stub(
      testSessionResponseJson(accessToken: accessToken, user: userJson),
      method: 'POST',
      path: '/auth/v1/token',
      times: times,
    );
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    requests.add(
      RecordedRequest._(
        request.method,
        request.url,
        Map.of(request.headers),
        await request.finalize().toBytes(),
      ),
    );
    for (final registered in _stubs.reversed) {
      if (registered.matches(request)) {
        final remaining = registered.remaining;
        if (remaining != null) {
          registered.remaining = remaining - 1;
        }
        return registered.respond(request);
      }
    }
    final stubs = _stubs.isEmpty
        ? '  (none)'
        : _stubs.reversed.map((registered) => '  $registered').join('\n');
    throw StateError(
      'No stub matches ${request.method} ${request.url}.\n'
      'Registered stubs, in matching order:\n$stubs',
    );
  }
}
