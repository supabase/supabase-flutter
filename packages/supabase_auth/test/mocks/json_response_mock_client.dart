import 'dart:convert';

import 'package:http/http.dart';

/// A mock HTTP client that answers every request with the same JSON body.
class JsonResponseMockClient extends BaseClient {
  JsonResponseMockClient({required this.body, this.statusCode = 200});

  /// The body the mocked server encodes and returns for every request.
  final Object? body;

  final int statusCode;

  Uri? lastUri;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastUri = request.url;

    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      statusCode,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}
