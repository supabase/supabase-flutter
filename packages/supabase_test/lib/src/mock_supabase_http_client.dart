// The composed helpers of this package legitimately build on its own
// test-only primitives outside of a test directory.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'internal_http_clients.dart';
import 'mock_http_clients.dart';
import 'session_fixture.dart';
import 'storage_fixture.dart';
import 'test_jwt.dart';

/// A request a [MockSupabaseHttpClient] has answered, with its body already
/// read, so a test can assert on what the code under test sent.
@visibleForTesting
class RecordedRequest {
  const RecordedRequest._(
    this.request,
    this.method,
    this.url,
    this.headers,
    this.bodyBytes,
  );

  /// The request the client received, with its body already read, so
  /// `finalize` must not be called on it again.
  ///
  /// Holds what the typed subclasses carry beyond the wire format, the
  /// `files` of a [MultipartRequest] for example.
  final BaseRequest request;

  final String method;
  final Uri url;

  /// The request headers, looked up case-insensitively like the headers of
  /// the request itself.
  final Map<String, String> headers;
  final Uint8List bodyBytes;

  /// The query parameters of [url].
  Map<String, String> get queryParameters => url.queryParameters;

  /// The request body decoded as UTF-8.
  String get body => utf8.decode(bodyBytes);

  /// The request body decoded as JSON.
  dynamic get jsonBody => jsonDecode(body);

  @override
  String toString() => '$method $url';
}

/// Builds the response a [MockSupabaseHttpClient] answers a matched request
/// with, from the request it received.
@visibleForTesting
typedef StubHandler = FutureOr<Response> Function(RecordedRequest request);

class _Stub {
  _Stub({
    required this.method,
    required this.path,
    required this.query,
    required this.schema,
    required this.respond,
    required this.remaining,
    this.bareEndpoint,
  });

  final String? method;
  final String? path;

  /// The path this stub also answers when it is matched exactly, so a
  /// shorthand for `/auth/v1/user` answers the `/user` a bare `AuthClient`
  /// addresses too.
  final String? bareEndpoint;
  final Map<String, String>? query;
  final String? schema;
  final FutureOr<StreamedResponse> Function(
    BaseRequest request,
    RecordedRequest recorded,
  )
  respond;
  int? remaining;

  bool matches(BaseRequest request) {
    if (remaining == 0) {
      return false;
    }
    if (method != null &&
        method!.toUpperCase() != request.method.toUpperCase()) {
      return false;
    }
    if (path != null &&
        !_pathMatches(request.url.path, path!) &&
        request.url.path != bareEndpoint) {
      return false;
    }
    final query = this.query;
    if (query != null) {
      final requestQuery = request.url.queryParameters;
      for (final MapEntry(:key, :value) in query.entries) {
        if (requestQuery[key] != value) {
          return false;
        }
      }
    }
    if (schema != null && _requestSchema(request) != schema) {
      return false;
    }
    return true;
  }

  /// The schema a PostgREST request addresses: reads carry it in
  /// `Accept-Profile`, writes in `Content-Profile`, and a request without
  /// either targets `public`.
  static String _requestSchema(BaseRequest request) {
    final method = request.method.toUpperCase();
    final header = method == 'GET' || method == 'HEAD'
        ? 'Accept-Profile'
        : 'Content-Profile';
    return request.headers[header] ?? 'public';
  }

  @override
  String toString() {
    final query = this.query;
    final querySuffix = query == null || query.isEmpty
        ? ''
        : '?${Uri(queryParameters: query).query}';
    final schemaSuffix = schema == null ? '' : ' (schema $schema)';
    return '${method ?? '(any method)'} ${path ?? '(any path)'}'
        '$querySuffix$schemaSuffix';
  }
}

/// Whether [requestPath] is [stubPath], or ends in [stubPath] at a segment
/// boundary, so that a stub written for `/rest/v1/todos` also answers a
/// project hosted under a path prefix, `/supabase/rest/v1/todos` for example.
bool _pathMatches(String requestPath, String stubPath) {
  if (requestPath == stubPath) {
    return true;
  }
  if (!requestPath.endsWith(stubPath)) {
    return false;
  }
  final boundary = requestPath.length - stubPath.length;
  return stubPath.startsWith('/') || requestPath[boundary - 1] == '/';
}

const _singleObjectAccept = 'application/vnd.pgrst.object+json';

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
/// stubs. The auth shorthands answer their endpoint both under the
/// `/auth/v1` prefix and at the root, where a bare `AuthClient` addresses it.
///
/// A request can be failed instead of answered with [stubError], stalled
/// with [stubStall], and driven through a sequence of statuses with
/// [stubStatuses].
///
/// A response that depends on the request, on the parameters of an `rpc` call
/// for example, is registered with [stubHandler].
@visibleForTesting
class MockSupabaseHttpClient extends BaseClient {
  final _stubs = <_Stub>[];

  /// Every request this client has answered, oldest first.
  final requests = <RecordedRequest>[];

  /// The answered requests whose URL path ends in [path], optionally
  /// narrowed to [method], oldest first.
  ///
  /// ```dart
  /// final inserts = httpClient.requestsTo('/rest/v1/todos', method: 'POST');
  /// expect(inserts.single.jsonBody, {'task': 'Write tests'});
  /// ```
  List<RecordedRequest> requestsTo(String path, {String? method}) {
    return requests
        .where(
          (request) =>
              _pathMatches(request.url.path, path) &&
              (method == null ||
                  method.toUpperCase() == request.method.toUpperCase()),
        )
        .toList();
  }

  /// Forgets every registered stub and every recorded request, so a client
  /// shared between tests starts each of them clean.
  void reset() {
    _stubs.clear();
    requests.clear();
  }

  /// Answers requests matching [method] and [path] with [body] under
  /// [statusCode].
  ///
  /// A null [method] or [path] matches any method or path. [path] matches a
  /// request whose URL path is [path] or ends in it, ignoring the query, so a
  /// stub for `/rest/v1/todos` also answers a project served under a path
  /// prefix. [query] narrows the match further to requests whose query
  /// carries every one of its entries, so two stubs of the same endpoint can
  /// answer differently filtered queries. A [Uint8List]
  /// body is sent as is with the content type `application/octet-stream`, any
  /// other body is encoded as JSON, and a null [body] produces an empty
  /// response body. [headers] are added to the response, and override the
  /// content type. [times] limits how many requests the stub answers before
  /// it stops matching, so consecutive stubs of the same endpoint can model
  /// state that changes between calls.
  void stub(
    Object? body, {
    String? method,
    String? path,
    Map<String, String>? query,
    int statusCode = 200,
    Map<String, String> headers = const {},
    int? times,
  }) {
    _stub(
      body,
      method: method,
      path: path,
      query: query,
      statusCode: statusCode,
      headers: headers,
      times: times,
    );
  }

  void _stub(
    Object? body, {
    String? method,
    String? path,
    String? bareEndpoint,
    Map<String, String>? query,
    int statusCode = 200,
    Map<String, String> headers = const {},
    int? times,
  }) {
    _stubs.add(
      _Stub(
        method: method,
        path: path,
        bareEndpoint: bareEndpoint,
        query: query,
        schema: null,
        remaining: times,
        respond: (request, _) => _response(
          body,
          request: request,
          statusCode: statusCode,
          headers: headers,
        ),
      ),
    );
  }

  /// Answers requests matching [method] and [path] with [body] as text under
  /// [contentType] and [reasonPhrase].
  ///
  /// Use it for the bodies that are not JSON, the HTML error page a gateway
  /// returns for example. [method], [path], [query] and [times] match as they
  /// do for [stub].
  void stubText(
    String body, {
    String? method,
    String? path,
    Map<String, String>? query,
    int statusCode = 200,
    String contentType = 'text/plain; charset=utf-8',
    String? reasonPhrase,
    Map<String, String> headers = const {},
    int? times,
  }) {
    final bytes = utf8.encode(body);
    _stubs.add(
      _Stub(
        method: method,
        path: path,
        query: query,
        schema: null,
        remaining: times,
        respond: (request, _) => StreamedResponse(
          Stream.value(bytes),
          statusCode,
          request: request,
          contentLength: bytes.length,
          reasonPhrase: reasonPhrase,
          headers: {'content-type': contentType, ...headers},
        ),
      ),
    );
  }

  /// Fails requests matching [method] and [path] by throwing [error] instead
  /// of answering them, the way a client fails when the network is gone.
  ///
  /// Pair it with [times] to fail the first requests only, so retry handling
  /// can be exercised:
  ///
  /// ```dart
  /// httpClient
  ///   ..stubTable('todos', rows: [])
  ///   ..stubError(ClientException('Offline'), times: 2);
  /// // The first two reads throw, every one after that returns no rows.
  /// ```
  ///
  /// [method], [path] and [query] match as they do for [stub].
  void stubError(
    Object error, {
    String? method,
    String? path,
    Map<String, String>? query,
    int? times,
  }) {
    _stubs.add(
      _Stub(
        method: method,
        path: path,
        query: query,
        schema: null,
        remaining: times,
        respond: (_, _) => throw error,
      ),
    );
  }

  /// Never answers requests matching [method] and [path], so only their
  /// timeout or their abort ends them.
  ///
  /// A request that carries no abort trigger stalls forever, so give the
  /// code under test a timeout. [method], [path], [query] and [times] match
  /// as they do for [stub].
  void stubStall({
    String? method,
    String? path,
    Map<String, String>? query,
    int? times,
  }) {
    _stubs.add(
      _Stub(
        method: method,
        path: path,
        query: query,
        schema: null,
        remaining: times,
        respond: (request, _) => stallUntilAborted(request),
      ),
    );
  }

  /// Answers requests matching [method] and [path] with [statuses] in order,
  /// one status per request, and repeats the last one once they run out.
  ///
  /// Retry handling is driven from failures into a success with it, without
  /// counting how often the stub was hit:
  ///
  /// ```dart
  /// httpClient.stubStatuses([503, 503, 200], body: []);
  /// ```
  ///
  /// [method], [path] and [query] match as they do for [stub].
  void stubStatuses(
    List<int> statuses, {
    Object? body,
    String? method,
    String? path,
    Map<String, String>? query,
    Map<String, String> headers = const {},
  }) {
    if (statuses.isEmpty) {
      throw ArgumentError.value(statuses, 'statuses', 'must not be empty');
    }
    var answered = 0;
    _stubs.add(
      _Stub(
        method: method,
        path: path,
        query: query,
        schema: null,
        remaining: null,
        respond: (request, _) {
          final statusCode = statuses[min(answered, statuses.length - 1)];
          answered++;
          return _response(
            body,
            request: request,
            statusCode: statusCode,
            headers: headers,
          );
        },
      ),
    );
  }

  /// Answers requests matching [method] and [path] with the response
  /// [handler] builds from the request.
  ///
  /// Use it when the response depends on what was sent, on the body of an
  /// `rpc` call for example. The handler receives the request with its body
  /// already read, and returns a [Response]; [jsonResponse] builds one from a
  /// JSON body:
  ///
  /// ```dart
  /// httpClient.stubHandler(
  ///   (request) {
  ///     final params = request.jsonBody as Map<String, dynamic>;
  ///     return jsonResponse(params['a'] + params['b']);
  ///   },
  ///   path: '/rest/v1/rpc/add_them',
  /// );
  /// ```
  ///
  /// [method], [path], [query] and [times] match as they do for [stub].
  void stubHandler(
    StubHandler handler, {
    String? method,
    String? path,
    Map<String, String>? query,
    int? times,
  }) {
    _stubs.add(
      _Stub(
        method: method,
        path: path,
        query: query,
        schema: null,
        remaining: times,
        respond: (request, recorded) async {
          final response = await handler(recorded);
          return StreamedResponse(
            Stream.value(response.bodyBytes),
            response.statusCode,
            request: request,
            headers: response.headers,
            contentLength: response.bodyBytes.length,
            reasonPhrase: response.reasonPhrase,
          );
        },
      ),
    );
  }

  /// Answers database requests for [table] with [rows].
  ///
  /// Stubs the PostgREST endpoint `/rest/v1/[table]` that `select`, `insert`,
  /// `update`, `upsert` and `delete` are served through. A null [method]
  /// matches all of them; pass `'GET'` or `'POST'` to answer reads and writes
  /// differently. [query] narrows the stub to queries carrying the given
  /// PostgREST filters, `{'id': 'eq.1'}` for example, so differently filtered
  /// reads of one table receive different rows. [schema] narrows it to
  /// requests addressing that schema, so tables of the same name in different
  /// schemas receive different rows; a null [schema] matches every schema.
  ///
  /// The response is shaped the way PostgREST shapes it for the request: a
  /// query ending in `single()` receives the only row of a one-row list, or
  /// the `PGRST116` error when the list holds any other number of rows, and a
  /// query asking for a count receives [count] in the `content-range` header,
  /// which defaults to the number of rows.
  void stubTable(
    String table, {
    Object? rows,
    String? method,
    Map<String, String>? query,
    String? schema,
    int statusCode = 200,
    int? count,
    int? times,
  }) {
    _stubPostgrest(
      rows,
      method: method,
      path: '/rest/v1/$table',
      query: query,
      schema: schema,
      statusCode: statusCode,
      count: count,
      times: times,
    );
  }

  /// Answers calls of the Postgres function [function] made through `rpc`
  /// with [body].
  ///
  /// The response is shaped for `single()` and counts the way [stubTable]
  /// shapes it, and [schema] narrows the stub to one schema the same way.
  void stubRpc(
    String function, {
    Object? body,
    Map<String, String>? query,
    String? schema,
    int statusCode = 200,
    int? count,
    int? times,
  }) {
    _stubPostgrest(
      body,
      path: '/rest/v1/rpc/$function',
      query: query,
      schema: schema,
      statusCode: statusCode,
      count: count,
      times: times,
    );
  }

  /// Answers invocations of the edge function [function] with [body].
  ///
  /// A [Uint8List] body reaches the caller as bytes, any other body as JSON.
  void stubEdgeFunction(
    String function, {
    Object? body,
    Map<String, String>? query,
    int statusCode = 200,
    int? times,
  }) {
    stub(
      body,
      path: '/functions/v1/$function',
      query: query,
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
    _stub(
      _sessionJson(user: user, expiresAt: expiresAt),
      method: 'POST',
      path: '/auth/v1/token',
      bareEndpoint: '/token',
      times: times,
    );
  }

  /// Answers the sign-up endpoint the way an auto-confirming project does:
  /// `signUp` succeeds with a session for [user], which defaults to
  /// [testUserJson], built as [stubSignIn] builds it.
  void stubSignUp({
    Map<String, dynamic>? user,
    DateTime? expiresAt,
    int? times,
  }) {
    _stub(
      _sessionJson(user: user, expiresAt: expiresAt),
      method: 'POST',
      path: '/auth/v1/signup',
      bareEndpoint: '/signup',
      times: times,
    );
  }

  /// Answers the logout endpoint, so `signOut` completes.
  void stubSignOut({int? times}) {
    _stub(
      null,
      method: 'POST',
      path: '/auth/v1/logout',
      bareEndpoint: '/logout',
      statusCode: 204,
      times: times,
    );
  }

  /// Answers the user endpoint with [user], which defaults to [testUserJson],
  /// so `getUser` and `updateUser` succeed.
  void stubUser({Map<String, dynamic>? user, int? times}) {
    _stub(
      user ?? testUserJson(),
      path: '/auth/v1/user',
      bareEndpoint: '/user',
      times: times,
    );
  }

  /// Answers an upload of [path] to [bucket], whether through `upload`,
  /// `uploadBinary`, `update` or `updateBinary`, with the object key and [id]
  /// the storage API reports.
  void stubStorageUpload(
    String bucket,
    String path, {
    String id = 'test-object-id',
    int statusCode = 200,
    int? times,
  }) {
    final objectPath = _storageObjectPath(bucket, path);
    for (final method in ['POST', 'PUT']) {
      stub(
        {'Key': '$bucket/${_cleanStoragePath(path)}', 'Id': id},
        method: method,
        path: '/storage/v1/object/$objectPath',
        statusCode: statusCode,
        times: times,
      );
    }
  }

  /// Answers a `download` of [path] from [bucket] with [bytes], whether or
  /// not an image transformation was requested.
  void stubStorageDownload(
    String bucket,
    String path, {
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
    int statusCode = 200,
    int? times,
  }) {
    final objectPath = _storageObjectPath(bucket, path);
    for (final endpoint in ['object', 'render/image/authenticated']) {
      stub(
        bytes,
        method: 'GET',
        path: '/storage/v1/$endpoint/$objectPath',
        statusCode: statusCode,
        headers: {'content-type': contentType},
        times: times,
      );
    }
  }

  /// Answers `createSignedUrl` for [path] in [bucket] with a URL carrying
  /// [token], so the returned URL is
  /// `<project>/storage/v1/object/sign/<bucket>/<path>?token=<token>`.
  void stubStorageSignedUrl(
    String bucket,
    String path, {
    String token = 'test-token',
    int statusCode = 200,
    int? times,
  }) {
    final objectPath = _storageObjectPath(bucket, path);
    stub(
      {'signedURL': '/object/sign/$objectPath?token=$token'},
      method: 'POST',
      path: '/storage/v1/object/sign/$objectPath',
      statusCode: statusCode,
      times: times,
    );
  }

  /// Answers `list` on [bucket] with [objects], each in the JSON shape of a
  /// `FileObject`, which [storageObjectJson] produces.
  void stubStorageList(
    String bucket, {
    required List<Map<String, dynamic>> objects,
    int statusCode = 200,
    int? times,
  }) {
    stub(
      objects,
      method: 'POST',
      path: '/storage/v1/object/list/$bucket',
      statusCode: statusCode,
      times: times,
    );
  }

  /// Answers `remove` on [bucket] with the objects at [paths], as the storage
  /// API reports the deleted objects.
  void stubStorageRemove(
    String bucket, {
    required List<String> paths,
    int statusCode = 200,
    int? times,
  }) {
    stub(
      [
        for (final path in paths)
          storageObjectJson(_cleanStoragePath(path), bucketId: bucket),
      ],
      method: 'DELETE',
      path: '/storage/v1/object/$bucket',
      statusCode: statusCode,
      times: times,
    );
  }

  /// The `<bucket>/<path>` the storage client puts in its URLs, with every
  /// path segment percent-encoded the way the client encodes it.
  String _storageObjectPath(String bucket, String path) {
    final encoded = Uri(pathSegments: _cleanStoragePath(path).split('/')).path;
    return '$bucket/$encoded';
  }

  String _cleanStoragePath(String path) {
    return path.replaceAll(RegExp(r'/+'), '/').replaceAll(RegExp(r'^/|/$'), '');
  }

  Map<String, dynamic> _sessionJson({
    Map<String, dynamic>? user,
    DateTime? expiresAt,
  }) {
    final userJson = user ?? testUserJson();
    final expiry = expiresAt ?? DateTime.now().add(const Duration(hours: 1));
    final accessToken = unsignedTestJwt({
      'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      'sub': userJson['id'],
      'role': 'authenticated',
    });
    return testSessionResponseJson(accessToken: accessToken, user: userJson);
  }

  void _stubPostgrest(
    Object? body, {
    required String path,
    required int statusCode,
    String? method,
    Map<String, String>? query,
    String? schema,
    int? count,
    int? times,
  }) {
    _stubs.add(
      _Stub(
        method: method,
        path: path,
        query: query,
        schema: schema,
        remaining: times,
        respond: (request, _) => _postgrestResponse(
          body,
          request: request,
          statusCode: statusCode,
          count: count,
        ),
      ),
    );
  }

  /// Shapes [body] the way PostgREST would for [request]: counts go into the
  /// `content-range` header, a `HEAD` request carries no body, and a request
  /// for a single object receives the only row or the `PGRST116` error.
  StreamedResponse _postgrestResponse(
    Object? body, {
    required BaseRequest request,
    required int statusCode,
    int? count,
  }) {
    final headers = <String, String>{};
    final prefer = request.headers['Prefer'] ?? '';
    final rowCount =
        count ??
        switch (body) {
          List<Object?> rows => rows.length,
          Map() => 1,
          _ => null,
        };
    if (prefer.contains('count=') && rowCount != null) {
      final range = body is List && body.isNotEmpty
          ? '0-${body.length - 1}'
          : '*';
      headers['content-range'] = '$range/$rowCount';
    }
    if (request.method.toUpperCase() == 'HEAD') {
      return _response(
        null,
        request: request,
        statusCode: statusCode,
        headers: headers,
      );
    }
    final isSuccess = statusCode >= 200 && statusCode <= 299;
    final wantsSingleObject =
        request.headers['Accept']?.startsWith(_singleObjectAccept) ?? false;
    if (isSuccess && wantsSingleObject && body is List) {
      if (body.length != 1) {
        return _response(
          {
            'code': 'PGRST116',
            'details':
                'Results contain ${body.length} rows, '
                '$_singleObjectAccept requires 1 row',
            'hint': null,
            'message': 'JSON object requested, multiple (or no) rows returned',
          },
          request: request,
          statusCode: 406,
          headers: headers,
        );
      }
      body = body.single;
    }
    return _response(
      body,
      request: request,
      statusCode: statusCode,
      headers: headers,
    );
  }

  StreamedResponse _response(
    Object? body, {
    required BaseRequest request,
    required int statusCode,
    required Map<String, String> headers,
  }) {
    return switch (body) {
      null => StreamedResponse(
        const Stream.empty(),
        statusCode,
        request: request,
        headers: headers,
      ),
      Uint8List bytes => StreamedResponse(
        Stream.value(bytes),
        statusCode,
        request: request,
        contentLength: bytes.length,
        headers: {'content-type': 'application/octet-stream', ...headers},
      ),
      _ => jsonStreamedResponse(
        body,
        statusCode: statusCode,
        request: request,
        headers: headers,
      ),
    };
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final headers = LinkedHashMap<String, String>(
      equals: (a, b) => a.toLowerCase() == b.toLowerCase(),
      hashCode: (key) => key.toLowerCase().hashCode,
    )..addAll(request.headers);
    final recorded = RecordedRequest._(
      request,
      request.method,
      request.url,
      UnmodifiableMapView(headers),
      await request.finalize().toBytes(),
    );
    requests.add(recorded);
    for (final registered in _stubs.reversed) {
      if (registered.matches(request)) {
        final remaining = registered.remaining;
        if (remaining != null) {
          registered.remaining = remaining - 1;
        }
        return registered.respond(request, recorded);
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
