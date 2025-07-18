import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';

enum HttpMethod {
  get("GET"),
  post("POST"),
  put("PUT"),
  delete("DELETE"),
  patch("PAtch");

  /// The uppercase HTTP method name. This should be used for a [Request]
  final String value;
  const HttpMethod(this.value);
}

class FunctionResponse {
  /// The data returned by the function. Type depends on the header `Content-Type`:
  /// - 'text/plain': [String]
  /// - 'octet/stream': [Uint8List]
  /// - 'application/json': dynamic ([jsonDecode] is used)
  /// - 'text/event-stream': [ByteStream]
  final dynamic data;
  final int status;

  FunctionResponse({
    this.data,
    required this.status,
  });
}

class FunctionException implements Exception {
  final int status;
  final dynamic details;
  final String? reasonPhrase;

  const FunctionException(
      {required this.status, this.details, this.reasonPhrase});

  @override
  String toString() =>
      'FunctionException(status: $status, details: $details, reasonPhrase: $reasonPhrase)';
}
