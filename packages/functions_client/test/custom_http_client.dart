import 'dart:convert';

import 'package:http/http.dart';

class CustomHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
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
    } else {
      return StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({"key": "Hello World"}))),
        200,
        request: request,
        headers: {
          "Content-Type": "application/json",
        },
      );
    }
  }
}
