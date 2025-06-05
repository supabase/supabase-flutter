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
    request.finalize();

    if (request.url.path.endsWith("error-function")) {
      //Return custom status code to check for usage of this client.
      return StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({"key": "Hello World"}))),
        420,
        request: request,
        headers: {
          "Content-Type": "application/json",
        },
        reasonPhrase: "Enhance Your Calm",
      );
    } else if (request.url.path.endsWith('sse')) {
      return StreamedResponse(
          Stream.fromIterable(['a', 'b', 'c'].map((e) => utf8.encode(e))), 200,
          request: request,
          headers: {
            "Content-Type": "text/event-stream",
          });
    } else if (request.url.path.endsWith('binary')) {
      return StreamedResponse(
        Stream.value([1, 2, 3, 4, 5]),
        200,
        request: request,
        headers: {
          "Content-Type": "application/octet-stream",
        },
      );
    } else if (request.url.path.endsWith('text')) {
      return StreamedResponse(
        Stream.value(utf8.encode('Hello World')),
        200,
        request: request,
        headers: {
          "Content-Type": "text/plain",
        },
      );
    } else if (request.url.path.endsWith('empty-json')) {
      return StreamedResponse(
        Stream.value([]),
        200,
        request: request,
        headers: {
          "Content-Type": "application/json",
        },
      );
    } else {
      final Stream<List<int>> stream;
      final Map<String, String> headers;
      
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
        headers = {"Content-Type": "application/json"};
      } else {
        // Check if the request contains binary data (Uint8List)
        final isOctetStream = request.headers['Content-Type'] == 'application/octet-stream';
        if (isOctetStream) {
          // Return the original binary data
          final bodyBytes = (request as Request).bodyBytes;
          stream = Stream.value(bodyBytes);
          headers = {"Content-Type": "application/octet-stream"};
        } else {
          stream = Stream.value(utf8.encode(jsonEncode({"key": "Hello World"})));
          headers = {"Content-Type": "application/json"};
        }
      }
      return StreamedResponse(
        stream,
        200,
        request: request,
        headers: headers,
      );
    }
  }
}
