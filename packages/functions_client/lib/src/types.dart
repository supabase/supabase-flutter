// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';

enum HttpMethod {
  get,
  post,
  put,
  delete,
  patch,
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

class FunctionException {
  final int status;
  final dynamic details;
  final String? reasonPhrase;

  FunctionException({required this.status, this.details, this.reasonPhrase});

  @override
  String toString() =>
      'FunctionException(status: $status, details: $details, reasonPhrase: $reasonPhrase)';
}
