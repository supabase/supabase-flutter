import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';

class FailingHttpClient extends BaseClient {
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

class CustomHttpClient extends BaseClient {
  dynamic response;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final dynamic body;
    if (response is Uint8List) {
      body = response;
    } else {
      body = utf8.encode(jsonEncode(response));
    }

    return StreamedResponse(
      Stream.value(body),
      201,
      request: request,
    );
  }
}
