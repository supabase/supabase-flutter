import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A callback invoked before every request to supply headers whose values can
/// change at runtime, most importantly the `Authorization` bearer token.
///
/// This is the interceptor/middleware hook. Because it runs per request, a
/// token refreshed by the auth loop is always picked up without rebuilding the
/// client.
typedef HeaderProvider = FutureOr<Map<String, String>> Function();

/// Thrown for any non-2xx response. [body] is the decoded error payload when
/// the server returned JSON, otherwise the raw string.
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.body,
    this.reasonPhrase,
  });

  final int statusCode;
  final Object? body;
  final String? reasonPhrase;

  @override
  String toString() => 'ApiException($statusCode $reasonPhrase): $body';
}

/// A response whose body is handed to the caller as a live byte stream instead
/// of being buffered. Used for operations that return
/// `application/octet-stream`, e.g. Functions streaming/SSE responses.
class StreamedApiResponse {
  StreamedApiResponse({
    required this.statusCode,
    required this.headers,
    required this.stream,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Stream<List<int>> stream;
}

/// Minimal transport shared by the generated clients. Deliberately built on the
/// `http` package that supabase-dart already depends on, with no `build_runner`
/// and no platform-specific imports so the same code runs on mobile, desktop
/// and web.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.headerProvider,
    Map<String, String> defaultHeaders = const {},
  })  : _httpClient = httpClient ?? http.Client(),
        _defaultHeaders = defaultHeaders;

  final String baseUrl;
  final http.Client _httpClient;
  final Map<String, String> _defaultHeaders;
  final HeaderProvider? headerProvider;

  /// Merges default headers, the runtime [headerProvider] result and the
  /// per-operation [extra] headers. Later entries win.
  Future<Map<String, String>> headers([
    Map<String, String> extra = const {},
  ]) async {
    final provided = await headerProvider?.call() ?? const {};
    return {..._defaultHeaders, ...provided, ...extra};
  }

  /// Builds a request URI, dropping query entries whose value is null.
  Uri uri(String path, [Map<String, String?> query = const {}]) {
    final filtered = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: filtered.isEmpty ? null : filtered,
    );
  }

  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _httpClient.send(request);
  }

  void close() => _httpClient.close();
}

/// Reads a streamed response into memory and raises [ApiException] on a non-2xx
/// status. Shared by every generated JSON operation.
Future<http.Response> readOrThrow(http.StreamedResponse streamed) async {
  final response = await http.Response.fromStream(streamed);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw _errorFrom(response);
  }
  return response;
}

ApiException _errorFrom(http.Response response) {
  Object? body = response.body;
  final contentType = response.headers['content-type'] ?? '';
  if (contentType.contains('application/json') && response.body.isNotEmpty) {
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      // Keep the raw string body.
    }
  }
  return ApiException(
    statusCode: response.statusCode,
    body: body,
    reasonPhrase: response.reasonPhrase,
  );
}

/// Percent-encodes a path value per RFC 3986 path-segment rules, preserving
/// `/` separators (so wildcard object keys with sub-paths stay intact). Mirrors
/// the encoding the hand-written storage client applies to object keys.
String encodePath(String value) => Uri(pathSegments: value.split('/')).path;

/// Reads an integer-valued response header without crashing when it is absent
/// or non-integer. Returns null instead of throwing.
int? parseIntHeader(String? value) =>
    value == null ? null : num.tryParse(value)?.toInt();

/// Feeds [body] into a [http.StreamedRequest] without collecting it into memory
/// first. The bytes flow straight from the source stream to
/// the socket. Uses [StreamSink.addStream] so a source error propagates to the
/// send future instead of becoming an unhandled error after the sink closes.
http.StreamedRequest streamingRequest(
  String method,
  Uri uri, {
  required Stream<List<int>> body,
  int? contentLength,
}) {
  final request = http.StreamedRequest(method, uri);
  if (contentLength != null) {
    request.contentLength = contentLength;
  }
  request.sink.addStream(body).whenComplete(request.sink.close);
  return request;
}
