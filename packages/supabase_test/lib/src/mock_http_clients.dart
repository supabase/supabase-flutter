import 'dart:convert';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

/// A [StreamedResponse] with [body] encoded as JSON and a matching content
/// type.
@visibleForTesting
StreamedResponse jsonStreamedResponse(
  Object? body, {
  int statusCode = 200,
  BaseRequest? request,
  Map<String, String> headers = const {},
  String? reasonPhrase,
}) {
  return StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    statusCode,
    request: request,
    headers: {'content-type': 'application/json', ...headers},
    reasonPhrase: reasonPhrase,
  );
}

/// A [Response] with [body] encoded as UTF-8 JSON and a matching content
/// type, for a `MockSupabaseHttpClient` handler to return.
@visibleForTesting
Response jsonResponse(
  Object? body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) {
  return Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8', ...headers},
  );
}
