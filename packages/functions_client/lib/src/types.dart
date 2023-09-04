import 'dart:convert';
import 'dart:typed_data';

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
  final dynamic data;
  final int? status;

  FunctionResponse({
    this.data,
    this.status,
  });
}
