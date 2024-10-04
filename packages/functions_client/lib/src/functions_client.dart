import 'dart:convert';
import 'dart:typed_data';

import 'package:functions_client/src/constants.dart';
import 'package:functions_client/src/types.dart';
import 'package:functions_client/src/version.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show MultipartRequest;
import 'package:logging/logging.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

class FunctionsClient {
  final String _url;
  final Map<String, String> _headers;
  final http.Client? _httpClient;
  final YAJsonIsolate _isolate;
  final bool _hasCustomIsolate;
  final _log = Logger("supabase.functions");

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
        _httpClient = httpClient {
    _log.config("Initialize FunctionsClient v$version with url: $url");
    _log.finest("Initialize with headers: $headers");
  }

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
  /// [functionName] is the name of the function to invoke
  ///
  /// [headers] to send with the request
  ///
  /// [body] of the request when [files] is null and can be of type String
  /// or an Object that is encodable to JSON with `jsonEncode`.
  /// If [files] is not null, [body] represents the fields of the
  /// [MultipartRequest] and must be be of type `Map<String, String>`.
  ///
  /// [files] to send in a `MultipartRequest`. [body] is used for the fields.
  ///
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
    Object? body,
    Iterable<http.MultipartFile>? files,
    Map<String, dynamic>? queryParameters,
    HttpMethod method = HttpMethod.post,
  }) async {
    final uri = Uri.parse('$_url/$functionName')
        .replace(queryParameters: queryParameters);

    final finalHeaders = <String, String>{
      ..._headers,
      if (headers != null) ...headers
    };

    if (body != null &&
        (headers == null || headers.containsKey("Content-Type") == false)) {
      finalHeaders['Content-Type'] = switch (body) {
        Uint8List() => 'application/octet-stream',
        String() => 'text/plain',
        _ => 'application/json',
      };
    }
    final http.BaseRequest request;
    if (files != null) {
      assert(
        body == null || body is Map<String, String>,
        'body must be of type Map',
      );
      final fields = body as Map<String, String>?;

      request = http.MultipartRequest(method.name, uri)
        ..fields.addAll(fields ?? {})
        ..files.addAll(files);
    } else {
      final bodyRequest = http.Request(method.name, uri);

      final String? bodyStr;
      if (body == null) {
        bodyStr = null;
      } else if (body is String) {
        bodyStr = body;
      } else {
        bodyStr = await _isolate.encode(body);
      }
      if (bodyStr != null) bodyRequest.body = bodyStr;
      request = bodyRequest;
    }

    finalHeaders.forEach((key, value) {
      request.headers[key] = value;
    });

    _log.finest('Request: ${request.method} ${request.url} ${request.headers}');

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
    _log.fine("Dispose FunctionsClient");
    if (!_hasCustomIsolate) {
      return _isolate.dispose();
    }
  }
}
