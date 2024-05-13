import 'dart:convert';

import 'package:functions_client/src/constants.dart';
import 'package:functions_client/src/types.dart';
import 'package:http/http.dart' as http;
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

class FunctionsClient {
  final String _url;
  final Map<String, String> _headers;
  final http.Client? _httpClient;
  final YAJsonIsolate _isolate;
  final bool _hasCustomIsolate;

  /// In case you don't provide your own isolate, call [dispose] when you're done
  FunctionsClient(
    String url,
    Map<String, String> headers, {
    http.Client? httpClient,
    YAJsonIsolate? isolate,
  })  : _url = url,
        _headers = {...Constants.defaultHeaders, ...headers},
        _isolate = isolate ?? (YAJsonIsolate()..initialize()),
        _hasCustomIsolate = isolate != null,
        _httpClient = httpClient;

  /// Getter for the headers
  Map<String, String> get headers {
    return _headers;
  }

  /// Updates the authorization header
  ///
  /// [token] - the new jwt token sent in the authorisation header
  void setAuth(String token) {
    _headers['Authorization'] = 'Bearer $token';
  }

  /// Invokes a function
  ///
  /// [functionName] - the name of the function to invoke
  ///
  /// [headers]: object representing the headers to send with the request
  ///
  /// [body]: the body of the request
  ///
  /// ```dart
  /// // Call a standard function
  /// final response = await supabase.functions.invoke('hello-world');
  /// print(response.data);
  ///
  /// // Listen to Server Sent Events
  /// final response = await supabase.functions.invoke('sse-function');
  /// response.data
  ///     .transform(const Utf8Decoder())
  ///     .listen((val) {
  ///       print(val);
  ///     });
  /// ```
  /// To stream SSE on the web, you can use a custom HTTP client that is
  /// able to handle SSE such as [fetch_client](https://pub.dev/packages/fetch_client).
  /// ```dart
  /// final fetchClient = FetchClient(mode: RequestMode.cors);
  /// await Supabase.initialize(
  ///   url: supabaseUrl,
  ///   anonKey: supabaseKey,
  ///   httpClient: fetchClient,
  /// );
  /// ```
  Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    HttpMethod method = HttpMethod.post,
  }) async {
    final bodyStr = body == null ? null : await _isolate.encode(body);

    final uri = Uri.parse('$_url/$functionName')
        .replace(queryParameters: queryParameters);

    final finalHeaders = <String, String>{
      ..._headers,
      if (headers != null) ...headers
    };

    final request = http.Request(method.name, uri);

    finalHeaders.forEach((key, value) {
      request.headers[key] = value;
    });
    if (bodyStr != null) request.body = bodyStr;
    final response = await (_httpClient?.send(request) ?? request.send());
    final responseType = (response.headers['Content-Type'] ??
            response.headers['content-type'] ??
            'text/plain')
        .split(';')[0]
        .trim();

    final dynamic data;

    if (responseType == 'application/json') {
      final bodyBytes = await response.stream.toBytes();
      data = bodyBytes.isEmpty
          ? ""
          : await _isolate.decode(utf8.decode(bodyBytes));
    } else if (responseType == 'application/octet-stream') {
      data = await response.stream.toBytes();
    } else if (responseType == 'text/event-stream') {
      data = response.stream;
    } else {
      final bodyBytes = await response.stream.toBytes();
      data = utf8.decode(bodyBytes);
    }

    if (200 <= response.statusCode && response.statusCode < 300) {
      return FunctionResponse(data: data, status: response.statusCode);
    } else {
      throw FunctionException(
        status: response.statusCode,
        details: data,
        reasonPhrase: response.reasonPhrase,
      );
    }
  }

  /// Disposes the self created isolate for json encoding/decoding
  ///
  /// Does nothing if you pass your own isolate
  Future<void> dispose() async {
    if (!_hasCustomIsolate) {
      return _isolate.dispose();
    }
  }
}
