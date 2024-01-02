import 'dart:convert';

import 'package:gotrue/src/types/auth_exception.dart';
import 'package:gotrue/src/types/fetch_options.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

enum RequestMethodType { get, post, put, delete }

class GotrueFetch {
  final Client? httpClient;

  const GotrueFetch([this.httpClient]);

  bool isSuccessStatusCode(int code) {
    return code >= 200 && code <= 299;
  }

  AuthException _handleError(http.Response error) {
    late AuthException errorRes;

    try {
      final parsedJson = json.decode(error.body) as Map<String, dynamic>;
      final String message = (parsedJson['msg'] ??
              parsedJson['message'] ??
              parsedJson['error_description'] ??
              parsedJson['error'] ??
              error.body)
          .toString();
      errorRes = AuthException(message, statusCode: '${error.statusCode}');
    } catch (_) {
      errorRes = AuthException(error.body, statusCode: '${error.statusCode}');
    }

    return errorRes;
  }

  Future<dynamic> request(
    String url,
    RequestMethodType method, {
    GotrueRequestOptions? options,
  }) async {
    final headers = options?.headers ?? {};
    if (options?.jwt != null) {
      headers['Authorization'] = 'Bearer ${options!.jwt}';
    }

    final qs = options?.query ?? {};
    if (options?.redirectTo != null) {
      qs['redirect_to'] = options!.redirectTo!;
    }
    Uri uri = Uri.parse(url);
    uri = uri.replace(queryParameters: {...uri.queryParameters, ...qs});
    late final http.Response response;

    final bodyStr = json.encode(options?.body ?? {});

    if (method != RequestMethodType.get) {
      headers['Content-Type'] = 'application/json';
    }
    switch (method) {
      case RequestMethodType.get:
        response = await (httpClient?.get ?? http.get)(
          uri,
          headers: headers,
        );

        break;
      case RequestMethodType.post:
        response = await (httpClient?.post ?? http.post)(
          uri,
          headers: headers,
          body: bodyStr,
        );
        break;
      case RequestMethodType.put:
        response = await (httpClient?.put ?? http.put)(
          uri,
          headers: headers,
          body: bodyStr,
        );
        break;
      case RequestMethodType.delete:
        response = await (httpClient?.delete ?? http.delete)(
          uri,
          headers: headers,
          body: bodyStr,
        );
        break;
    }

    if (isSuccessStatusCode(response.statusCode)) {
      if (options?.noResolveJson == true) {
        return response.body;
      } else {
        return json.decode(utf8.decode(response.bodyBytes));
      }
    } else {
      throw _handleError(response);
    }
  }
}
