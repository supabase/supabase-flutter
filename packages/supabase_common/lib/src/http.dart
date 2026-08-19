import 'dart:convert';

import 'package:http/http.dart';

/// Sending a request over a caller-provided transport.
extension SendWith on BaseRequest {
  /// Sends this request over [httpClient], or over a one-off [Client] when
  /// [httpClient] is `null`.
  ///
  /// Every Supabase client takes an optional [Client] so callers can plug in
  /// their own transport, and falls back to the default one otherwise.
  Future<StreamedResponse> sendWith(Client? httpClient) =>
      httpClient?.send(this) ?? send();
}

/// Reading and logging a map of HTTP headers.
///
/// [BaseRequest.headers] already compares its keys case insensitively, so
/// [header] and [mediaType] are only needed for [BaseResponse.headers], which
/// is a plain map.
extension HeaderMap on Map<String, String> {
  /// The value of the [name] header, matched case insensitively.
  ///
  /// HTTP header names are case insensitive, and while the `package:http`
  /// clients lowercase the names of the headers they receive, a client written
  /// against [BaseClient] can hand back any casing.
  String? header(String name) {
    final lowerCaseName = name.toLowerCase();
    for (final MapEntry(:key, :value) in entries) {
      if (key.toLowerCase() == lowerCaseName) {
        return value;
      }
    }
    return null;
  }

  /// The media type, lowercased and without any parameters, so
  /// `Content-Type: application/json; charset=utf-8` becomes
  /// `application/json`.
  ///
  /// Returns `null` when there is no content type.
  ///
  /// `MediaType.parse` from `package:http_parser` is not used because it throws
  /// on a malformed value, and a proxy or gateway in front of a service can
  /// answer with anything at all.
  String? get mediaType =>
      header('content-type')?.split(';').first.trim().toLowerCase();
}

/// Decodes [body] as a JSON object, or returns `null` when it is empty, is not
/// valid JSON, or is valid JSON that is not an object.
///
/// Error responses are the main use: a service is expected to describe the
/// failure in a JSON object, but a proxy or gateway in front of it can return
/// anything at all, so decoding must not throw.
Map<String, dynamic>? tryDecodeJsonObject(String body) {
  try {
    final decoded = json.decode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}
