import 'dart:convert';

import 'package:gotrue/src/constants.dart';
import 'package:gotrue/src/types/auth_exception.dart';
import 'package:gotrue/src/types/error_code.dart';
import 'package:gotrue/src/types/fetch_options.dart';
import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:supabase_common/supabase_common.dart';

@internal
class GotrueFetch {
  final Client? httpClient;

  const GotrueFetch([this.httpClient]);

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

  String? _getErrorCode(dynamic error) {
    if (error is Map) {
      final dynamic errorCode = error['code'];
      if (errorCode is String) {
        return errorCode;
      }
    }
    return null;
  }

  /// Message to use when a response body carries no usable error description.
  ///
  /// Falls back to the reason phrase, which HTTP/2 responses don't have, and
  /// then to a message synthesized from the status code.
  String _getStatusMessage(Response response) {
    final reasonPhrase = response.reasonPhrase;
    if (reasonPhrase != null && reasonPhrase.isNotEmpty) {
      return reasonPhrase;
    }
    return 'HTTP ${response.statusCode}';
  }

  AuthException _handleError(dynamic error) {
    if (error is! Response) {
      throw AuthRetryableFetchException(message: error.toString());
    }
    final response = error;

    // If the status is 500 or above, it's likely a server error,
    // and can be retried.
    final isRetryable = response.statusCode >= 500;

    final dynamic data;

    // Catch this case as trying to decode it will throw a misleading
    // [FormatException]
    if (response.body.isEmpty) {
      if (isRetryable) {
        throw AuthRetryableFetchException(
          message: _getStatusMessage(response),
          statusCode: response.statusCode,
        );
      }
      throw AuthUnknownException(
        message:
            'Received an empty response with status code '
            '${response.statusCode}',
        originalError: response,
      );
    }
    try {
      data = jsonDecode(response.body);
    } catch (error) {
      if (isRetryable) {
        throw AuthRetryableFetchException(
          message: _getStatusMessage(response),
          statusCode: response.statusCode,
        );
      }
      throw AuthUnknownException(
        message: 'Failed to decode error response',
        originalError: error,
      );
    }

    if (isRetryable) {
      throw AuthRetryableFetchException(
        message: _getErrorMessage(data),
        statusCode: response.statusCode,
      );
    }

    final errorCode = _getErrorCode(data);

    if (errorCode == ErrorCode.weakPassword.code) {
      throw AuthWeakPasswordException(
        message: _getErrorMessage(data),
        statusCode: response.statusCode,
        reasons: List<String>.from(data['weak_password']?['reasons'] ?? []),
      );
    }

    throw AuthApiException(
      _getErrorMessage(data),
      statusCode: response.statusCode,
      errorCode: errorCode,
    );
  }

  Future<dynamic> request(
    String url,
    HttpMethod method, {
    GotrueRequestOptions? options,
  }) async {
    final result = await requestWithResponse(url, method, options: options);
    return result.body;
  }

  /// Performs the request and returns the resolved [body] alongside the raw
  /// [response], for callers that need to read response headers.
  ///
  /// Use [request] unless you need the headers.
  @internal
  Future<({dynamic body, Response response})> requestWithResponse(
    String url,
    HttpMethod method, {
    GotrueRequestOptions? options,
  }) async {
    // Copy the maps before mutating them. Callers pass the client's shared
    // header/query maps by reference, so writing `Authorization`, the API
    // version or `redirect_to` directly would leak into every later request.
    final headers = {...?options?.headers};

    // Pin the API version rather than letting a caller override it. This client
    // only understands the error shape of [Constants.apiVersion], so asking the
    // server for an older one would produce responses it cannot parse.
    headers[Constants.apiVersionHeaderName] = Constants.apiVersion;

    if (options?.jwt != null) {
      headers['Authorization'] = 'Bearer ${options!.jwt}';
    }

    final qs = {...?options?.query};
    if (options?.redirectTo != null) {
      qs['redirect_to'] = options!.redirectTo!;
    }
    Uri uri = Uri.parse(url);
    uri = uri.replace(queryParameters: {...uri.queryParameters, ...qs});

    final response = await _handleRequest(
      method: method,
      uri: uri,
      options: options,
      headers: headers,
    );

    return (body: _resolveBody(response, options), response: response);
  }

  dynamic _resolveBody(Response response, GotrueRequestOptions? options) {
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

  Future<Response> _handleRequest({
    required HttpMethod method,
    required Uri uri,
    required GotrueRequestOptions? options,
    required Map<String, String> headers,
  }) async {
    final bodyStr = json.encode(options?.body ?? {});

    if (method != HttpMethod.get && method != HttpMethod.head) {
      headers['Content-Type'] = 'application/json';
    }
    Response response;
    try {
      response = await switch (method) {
        HttpMethod.get => (httpClient?.get ?? get)(uri, headers: headers),
        HttpMethod.head => (httpClient?.head ?? head)(uri, headers: headers),
        HttpMethod.post => (httpClient?.post ?? post)(
          uri,
          headers: headers,
          body: bodyStr,
        ),
        HttpMethod.put => (httpClient?.put ?? put)(
          uri,
          headers: headers,
          body: bodyStr,
        ),
        HttpMethod.patch => (httpClient?.patch ?? patch)(
          uri,
          headers: headers,
          body: bodyStr,
        ),
        HttpMethod.delete => (httpClient?.delete ?? delete)(
          uri,
          headers: headers,
          body: bodyStr,
        ),
      };
    } catch (e) {
      // fetch failed, likely due to a network or CORS error
      throw AuthRetryableFetchException(message: e.toString());
    }

    if (!isSuccessStatusCode(response.statusCode)) {
      throw _handleError(response);
    }

    return response;
  }
}
