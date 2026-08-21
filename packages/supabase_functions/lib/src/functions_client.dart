import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_functions/src/functions_constants.dart';
import 'package:supabase_functions/src/types.dart';
import 'package:supabase_functions/src/version.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show MultipartRequest;
import 'package:supabase_functions/src/logger.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

class FunctionsClient {
  final String _url;
  final Map<String, String> _headers;
  final http.Client? _httpClient;
  final AsyncJsonCodec _jsonCodec;
  final bool _ownsJsonCodec;
  final String? _region;

  /// [jsonCodec] encodes the request body and decodes the response. The
  /// default codec keeps large payloads off the calling isolate. A codec
  /// passed here is owned by the caller, so [dispose] leaves it alone; call
  /// [dispose] when you're done with a client that created its own.
  ///
  /// [accessToken] is resolved before every invocation and sent as
  /// `Authorization: Bearer <token>`. Use it when the token rotates, for
  /// example a session token that is refreshed. Returning `null` sends no
  /// bearer token. A header passed to [invoke] still wins over it, so a single
  /// call can be made with a different token.
  FunctionsClient(
    String url,
    Map<String, String> headers, {
    http.Client? httpClient,
    AsyncJsonCodec? jsonCodec,
    String? region,
    Future<String?> Function()? accessToken,
  }) : assert(
         accessToken == null || headers.header('Authorization') == null,
         'Pass either an Authorization header or accessToken, not both: the '
         'header would win over the resolved token on every invocation.',
       ),
       _url = url,
       _headers = {...FunctionsConstants.defaultHeaders, ...headers},
       _jsonCodec = jsonCodec ?? (YAJsonIsolate()..initialize()),
       _ownsJsonCodec = jsonCodec == null,
       // The transport belongs to the caller, so the client never closes it,
       // the same way it leaves a caller-provided JSON codec alone.
       // ignore: dispose-class-fields
       _httpClient = accessToken == null
           ? httpClient
           : AccessTokenClient(accessToken, httpClient),
       _region = region {
    functionsLogger.config(
      "Initialize FunctionsClient v$version with url "
      "'${Uri.parse(url).redacted}' and region "
      "'$region'",
    );
    functionsLogger.finest("Initialize with headers: ${headers.redacted}");
  }

  /// Getter for the headers
  Map<String, String> get headers {
    return _headers;
  }

  /// Invokes a function
  ///
  /// [functionName] is the name of the function to invoke
  ///
  /// [headers] to send with the request
  ///
  /// [body] of the request when [files] is null and can be of type String,
  /// [Uint8List], or an Object that is encodable to JSON with `jsonEncode`.
  /// If [files] is not null, [body] represents the fields of the
  /// [MultipartRequest] and must be of type `Map<String, String>`.
  ///
  /// [files] to send in a `MultipartRequest`. [body] is used for the fields.
  ///
  /// [region] optionally specify the region to invoke the function in. When
  /// specified and not equal to `'any'`, adds both the `x-region` header and
  /// the `forceFunctionRegion` query parameter.
  ///
  /// [abortSignal] cancels the in-flight request when the provided [Future]
  /// completes. It must not complete with an error. On abort, a
  /// [RequestAbortedException] is thrown. This is useful for cancelling a
  /// request in response to an event or for setting a request timeout:
  ///
  /// ```dart
  /// // Event based
  /// final abortSignal = Completer<void>();
  /// abortSignal.complete(); // Call in some event handler to abort the request
  ///
  /// try {
  ///   final response = await supabase.functions.invoke(
  ///     'hello-world',
  ///     abortSignal: abortSignal.future,
  ///   );
  /// } on RequestAbortedException catch (error) {
  ///   print('Request was aborted: $error');
  /// }
  ///
  /// // Timer based
  /// final response = await supabase.functions.invoke(
  ///   'hello-world',
  ///   abortSignal: Future.delayed(Duration(seconds: 5)),
  /// );
  /// ```
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
  ///     .listen((value) {
  ///       print(value);
  ///     });
  /// ```
  /// To stream SSE on the web, you can use a custom HTTP client that is able to
  /// handle SSE such as [fetch_client](https://pub.dev/packages/fetch_client).
  /// ```dart
  /// final fetchClient = FetchClient(mode: RequestMode.cors);
  /// await Supabase.initialize(
  ///   url: supabaseUrl,
  ///   publishableKey: supabaseKey,
  ///   httpClient: fetchClient,
  /// );
  /// ```
  Future<FunctionResponse> invoke(
    String functionName, {
    // ignore: avoid-shadowing
    Map<String, String>? headers,
    Object? body,
    Iterable<http.MultipartFile>? files,
    Map<String, dynamic>? queryParameters,
    HttpMethod method = HttpMethod.post,
    String? region,
    Future<void>? abortSignal,
  }) async {
    final effectiveRegion = region ?? _region;

    // Merge query parameters with forceFunctionRegion if region is specified
    final effectiveQueryParameters = <String, dynamic>{
      ...?queryParameters,
      if (effectiveRegion != null && effectiveRegion != 'any')
        'forceFunctionRegion': effectiveRegion,
    };

    final uri = Uri.parse('$_url/$functionName').replace(
      queryParameters: effectiveQueryParameters.isNotEmpty
          ? effectiveQueryParameters
          : null,
    );

    final finalHeaders = <String, String>{
      ..._headers,
      ...?headers,
      if (effectiveRegion != null && effectiveRegion != 'any')
        'x-region': effectiveRegion,
    };

    final http.BaseRequest request;
    if (files != null) {
      assert(
        body == null || body is Map<String, String>,
        'body must be of type Map',
      );
      final fields = (body as Map?)?.cast<String, String>();

      // No content type is set here: a multipart request generates its own
      // boundary while it is being finalized and sets the header itself.
      request =
          http.AbortableMultipartRequest(
              method.value,
              uri,
              abortTrigger: abortSignal,
            )
            ..headers.addAll(finalHeaders)
            ..fields.addAll(fields ?? {})
            ..files.addAll(files);
    } else {
      final bodyRequest = http.AbortableRequest(
        method.value,
        uri,
        abortTrigger: abortSignal,
      )..headers.addAll(finalHeaders);

      if (body != null) {
        // The content type is set before the body, so that a body given as a
        // string is encoded with the charset the caller asked for, and so that
        // the charset `Request.body` fills in for itself is kept.
        bodyRequest.headers.putIfAbsent(
          'Content-Type',
          () => switch (body) {
            Uint8List() => 'application/octet-stream',
            String() => 'text/plain',
            _ => 'application/json',
          },
        );

        if (body is String) {
          bodyRequest.body = body;
        } else if (body is Uint8List) {
          bodyRequest.bodyBytes = body;
        } else {
          bodyRequest.body = await _jsonCodec.encode(body);
        }
      }
      request = bodyRequest;
    }

    functionsLogger.finest(
      'Request: ${request.method} ${request.url.redacted} '
      '${request.headers.redacted}',
    );

    final http.StreamedResponse response;
    try {
      response = await request.sendWith(_httpClient);
    } on http.RequestAbortedException {
      rethrow;
    } catch (error) {
      throw FunctionsFetchException(details: error);
    }
    final responseType = response.headers.mediaType ?? 'text/plain';

    final isRelayError = response.headers['x-relay-error'] == 'true';
    final isSuccessStatus =
        isSuccessStatusCode(response.statusCode) && !isRelayError;

    final dynamic data;

    if (responseType == 'application/json') {
      final bodyBytes = await response.stream.toBytes();
      if (bodyBytes.isEmpty) {
        data = "";
      } else {
        dynamic decoded;
        try {
          decoded = await _jsonCodec.decodeBytes(bodyBytes);
        } on FormatException {
          // A body labeled JSON that doesn't parse is only tolerated on an
          // error status, where the raw text still needs to reach the caller
          // as the exception `details`. On a success status it's a real
          // anomaly, so keep surfacing it instead of handing back a String.
          if (isSuccessStatus) rethrow;
          decoded = utf8.decode(bodyBytes);
        }
        data = decoded;
      }
    } else if (responseType == 'application/octet-stream') {
      data = await response.stream.toBytes();
    } else if (responseType == 'text/event-stream' && isSuccessStatus) {
      // Only a successful streaming response hands the live stream to the
      // caller. On an error status there is nothing to stream — fall through
      // and drain the body so it becomes the exception `details` and the
      // connection isn't left open.
      data = response.stream;
    } else {
      final bodyBytes = await response.stream.toBytes();
      data = utf8.decode(bodyBytes);
    }

    if (isSuccessStatus) {
      return FunctionResponse(data: data, statusCode: response.statusCode);
    }
    // The reason phrase is the only message the response itself carries; when
    // it is absent, as it is over HTTP/2, each exception uses its own default.
    if (isRelayError) {
      throw FunctionsRelayException(
        statusCode: response.statusCode,
        details: data,
        message: response.reasonPhrase,
      );
    }
    throw FunctionsApiException(
      statusCode: response.statusCode,
      details: data,
      message: response.reasonPhrase,
    );
  }

  /// Disposes the JSON codec the client created for itself.
  ///
  /// Does nothing when a codec was passed to the constructor, since that one
  /// belongs to the caller.
  Future<void> dispose() async {
    functionsLogger.fine("Dispose FunctionsClient");
    if (_ownsJsonCodec) {
      return _jsonCodec.dispose();
    }
  }
}
