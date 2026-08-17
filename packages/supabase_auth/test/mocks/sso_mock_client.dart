import 'dart:convert';

import 'package:http/http.dart';

/// A mock HTTP client that simulates the `POST /sso` endpoint used to obtain
/// the redirect URL of an enterprise identity provider.
class SSOMockClient extends BaseClient {
  SSOMockClient({required this.redirectUrl});

  /// The URL the mocked server reports in the `url` field of its response.
  final String redirectUrl;

  Uri? lastUri;
  Map<String, dynamic>? lastRequestBody;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastUri = request.url;

    if (request is Request) {
      try {
        lastRequestBody = json.decode(request.body) as Map<String, dynamic>;
      } catch (_) {
        // Ignore non-JSON bodies.
      }
    }

    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'url': redirectUrl}))),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}
