import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:gotrue/src/types/auth_exception.dart';
import 'package:gotrue/src/types/fetch_options.dart';
import 'package:http/http.dart';

enum RequestMethodType { get, post, put, delete }

class GotrueFetch {
  final Client? httpClient;

  const GotrueFetch([this.httpClient]);

  bool isSuccessStatusCode(int code) {
    return code >= 200 && code <= 299;
  }

  String _getErrorMessage(dynamic error) {
    if (error is Map) {
      return error['msg'] ??
          error['message'] ??
          error['error_description'] ??
          error['error']?.toString() ??
          error.toString();
    }

    return error.toString();
  }

  AuthException _handleError(dynamic error) {
    if (error is! Response) {
      throw AuthRetryableFetchException();
    }

    // If the status is 500 or above, it's likely a server error,
    // and can be retried.
    if (error.statusCode >= 500) {
      throw AuthRetryableFetchException();
    }

    final dynamic data;
    try {
      data = jsonDecode(error.body);
    } catch (error) {
      throw AuthUnknownException(
          message: error.toString(), originalError: error);
    }

    // Check if weak password reasons only contain strings
    if (data is Map &&
        data['weak_password'] is Map &&
        data['weak_password']['reasons'] is List &&
        (data['weak_password']['reasons'] as List).isNotEmpty &&
        (data['weak_password']['reasons'] as List)
            .whereNot((element) => element is String)
            .isEmpty) {
      throw AuthWeakPasswordException(
        message: _getErrorMessage(data),
        statusCode: error.statusCode.toString(),
        reasons: List<String>.from(data['weak_password']['reasons']),
      );
    }

    throw AuthApiException(
      _getErrorMessage(data),
      statusCode: error.statusCode.toString(),
    );
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

    return await _handleRequest(
        method: method, uri: uri, options: options, headers: headers);
  }

  Future<dynamic> _handleRequest({
    required RequestMethodType method,
    required Uri uri,
    required GotrueRequestOptions? options,
    required Map<String, String> headers,
  }) async {
    final bodyStr = json.encode(options?.body ?? {});

    if (method != RequestMethodType.get) {
      headers['Content-Type'] = 'application/json';
    }
    Response response;
    try {
      switch (method) {
        case RequestMethodType.get:
          response = await (httpClient?.get ?? get)(
            uri,
            headers: headers,
          );

          break;
        case RequestMethodType.post:
          response = await (httpClient?.post ?? post)(
            uri,
            headers: headers,
            body: bodyStr,
          );
          break;
        case RequestMethodType.put:
          response = await (httpClient?.put ?? put)(
            uri,
            headers: headers,
            body: bodyStr,
          );
          break;
        case RequestMethodType.delete:
          response = await (httpClient?.delete ?? delete)(
            uri,
            headers: headers,
            body: bodyStr,
          );
          break;
      }
    } catch (e) {
      // fetch failed, likely due to a network or CORS error
      throw AuthRetryableFetchException();
    }

    if (!isSuccessStatusCode(response.statusCode)) {
      throw _handleError(response);
    }

    if (options?.noResolveJson == true) {
      return response.body;
    }

    try {
      return json.decode(utf8.decode(response.bodyBytes));
    } catch (error) {
      throw _handleError(error);
    }
  }
}
