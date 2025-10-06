import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/types/api_version.dart';
import 'package:gotrue/src/types/auth_exception.dart';
import 'package:gotrue/src/types/error_code.dart';
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

  String? _getErrorCode(dynamic error, String key) {
    if (error is Map) {
      final dynamic errorCode = error[key];
      if (errorCode is String) {
        return errorCode;
      }
    }
    return null;
  }

  AuthException _handleError(dynamic error) {
    if (error is! Response) {
      throw AuthRetryableFetchException(message: error.toString());
    }
    final response = error;

    // If the status is 500 or above, it's likely a server error,
    // and can be retried.
    if (response.statusCode >= 500) {
      throw AuthRetryableFetchException(
        message: response.body,
        statusCode: response.statusCode.toString(),
      );
    }

    final dynamic data;

    // Catch this case as trying to decode it will throw a misleading [FormatException]
    if (response.body.isEmpty) {
      throw AuthUnknownException(
        message:
            'Received an empty response with status code ${response.statusCode}',
        originalError: response,
      );
    }
    try {
      data = jsonDecode(response.body);
    } catch (error) {
      throw AuthUnknownException(
        message: 'Failed to decode error response',
        originalError: error,
      );
    }
    String? errorCode;

    final responseApiVersion = ApiVersion.fromResponse(response);

    if (responseApiVersion?.isSameOrAfter(ApiVersions.v20240101) ?? false) {
      errorCode = _getErrorCode(data, 'code');
    } else {
      errorCode = _getErrorCode(data, 'error_code');
    }

    if (errorCode == null) {
      // Legacy support for weak password errors, when there were no error codes
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
          statusCode: response.statusCode.toString(),
          reasons: List<String>.from(data['weak_password']['reasons']),
        );
      }
    } else if (errorCode == ErrorCode.weakPassword.code) {
      throw AuthWeakPasswordException(
        message: _getErrorMessage(data),
        statusCode: response.statusCode.toString(),
        reasons: List<String>.from(data['weak_password']?['reasons'] ?? []),
      );
    }

    throw AuthApiException(
      _getErrorMessage(data),
      statusCode: response.statusCode.toString(),
      code: errorCode,
    );
  }

  Future<dynamic> request(
    String url,
    RequestMethodType method, {
    GotrueRequestOptions? options,
  }) async {
    final headers = options?.headers ?? {};

    // Set the API version header if not already set
    if (!headers.containsKey(Constants.apiVersionHeaderName)) {
      headers[Constants.apiVersionHeaderName] = ApiVersions.v20240101.name;
    }

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
      throw AuthRetryableFetchException(message: e.toString());
    }

    if (!isSuccessStatusCode(response.statusCode)) {
      throw _handleError(response);
    }

    if (options?.noResolveJson == true) {
      return response.body;
    }

    try {
      final bodyString = utf8.decode(response.bodyBytes);
      if (bodyString.isEmpty) {
        return <String, dynamic>{};
      }
      return json.decode(bodyString);
    } catch (error) {
      throw _handleError(error);
    }
  }
}
