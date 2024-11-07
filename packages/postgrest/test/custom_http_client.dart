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
    //Return custom status code to check for usage of this client.
    return StreamedResponse(
      Stream.value(lastBody!),
      420,
      request: request,
    );
  }
}
