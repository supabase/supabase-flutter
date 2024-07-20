import 'dart:convert';

import 'package:http/http.dart';

class CustomHttpClient extends BaseClient {
  /// List of received requests by the client.
  ///
  /// Usefull for testing purposes, to check the request was constructed
  /// correctly.
  List<BaseRequest> receivedRequests = <BaseRequest>[];

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // Add request to receivedRequests list.
    receivedRequests = receivedRequests..add(request);

    if (request.url.path.endsWith("function")) {
      //Return custom status code to check for usage of this client.
      return StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({"key": "Hello World"}))),
        420,
        request: request,
        headers: {
          "Content-Type": "application/json",
        },
      );
    } else if (request.url.path.endsWith('sse')) {
      return StreamedResponse(
          Stream.fromIterable(['a', 'b', 'c'].map((e) => utf8.encode(e))), 200,
          request: request,
          headers: {
            "Content-Type": "text/event-stream",
          });
    } else {
      final Stream<List<int>> stream;
      if (request is MultipartRequest) {
        stream = Stream.value(
          utf8.encode(jsonEncode([
            for (final file in request.files)
              {
                "name": file.field,
                "content": await file.finalize().bytesToString()
              }
          ])),
        );
      } else {
        stream = Stream.value(utf8.encode(jsonEncode({"key": "Hello World"})));
      }
      return StreamedResponse(
        stream,
        200,
        request: request,
        headers: {
          "Content-Type": "application/json",
        },
      );
    }
  }
}
