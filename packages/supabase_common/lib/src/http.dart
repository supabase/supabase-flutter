import 'dart:convert';

import 'package:http/http.dart';

/// Sends [request] over [httpClient], or over a one-off client when no client
/// was provided.
///
/// Every Supabase client takes an optional [Client] so callers can plug in
/// their own transport, and falls back to the default one otherwise.
Future<StreamedResponse> sendRequest(
  BaseRequest request, {
  Client? httpClient,
}) => httpClient?.send(request) ?? request.send();

/// The value of the [name] header, matched case insensitively.
///
/// HTTP header names are case insensitive, and while `package:http` lowercases
/// the names of received headers, headers assembled by the client packages can
/// use any casing.
String? headerValue(Map<String, String> headers, String name) {
  final lowerCaseName = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == lowerCaseName) {
      return entry.value;
    }
  }
  return null;
}

/// Sets `Content-Type` to [value] unless [headers] already carries one.
///
/// Requests whose body the caller controls must not have an explicitly passed
/// content type overwritten.
void setDefaultContentType(Map<String, String> headers, String value) {
  if (headerValue(headers, 'content-type') == null) {
    headers['Content-Type'] = value;
  }
}

/// The media type of a response, lowercased and without any parameters, so
/// `Content-Type: application/json; charset=utf-8` becomes `application/json`.
///
/// Returns `null` when the response carries no content type.
String? responseMediaType(Map<String, String> headers) =>
    headerValue(headers, 'content-type')?.split(';').first.trim().toLowerCase();

/// Decodes [body] as a JSON object, or returns `null` when it is empty, is not
/// valid JSON, or is valid JSON that is not an object.
///
/// Error responses are the main use: a service is expected to describe the
/// failure in a JSON object, but a proxy or gateway in front of it can return
/// anything at all, so decoding must not throw.
Map<String, dynamic>? tryDecodeJsonObject(String body) {
  if (body.isEmpty) {
    return null;
  }
  try {
    final decoded = json.decode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}
