import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';

class CustomHttpClient extends BaseClient {
  BaseRequest? lastRequest;
  Uint8List? lastBody;
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastRequest = request;
    final bodyStream = request.finalize();
    lastBody = await bodyStream.toBytes();

    if (request.url.path.endsWith("empty-succ")) {
      return StreamedResponse(
        Stream.empty(),
        200,
        request: request,
      );
    }

    if (request.url.path.endsWith("non-json-succ")) {
      return StreamedResponse(
        Stream.value(
          utf8.encode('<html><body>502 Bad Gateway</body></html>'),
        ),
        200,
        request: request,
        reasonPhrase: 'OK',
      );
    }
    //Return custom status code to check for usage of this client.
    return StreamedResponse(
      Stream.value(lastBody!),
      420,
      request: request,
    );
  }
}
