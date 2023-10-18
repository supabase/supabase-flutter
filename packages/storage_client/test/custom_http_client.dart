import 'dart:convert';

import 'package:http/http.dart';

class CustomHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    //Return custom status code to check for usage of this client.
    return StreamedResponse(
      request.finalize(),
      420,
      request: request,
    );
  }
}

/// Client that fails for few times when attempting to upload file
class RetryHttpClient extends BaseClient {
  int failureCount = 0;
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (failureCount < 3) {
      failureCount++;
      throw ClientException('Offline');
    }
    //Return custom status code to check for usage of this client.
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'Key': 'public/a.txt'}))),
      201,
      request: request,
    );
  }
}
