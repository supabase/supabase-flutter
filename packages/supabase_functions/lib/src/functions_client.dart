import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_functions/src/functions_constants.dart';
import 'package:supabase_functions/src/types.dart';
import 'package:supabase_functions/src/version.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show MultipartRequest;
import 'package:meta/meta.dart';
import 'package:supabase_functions/src/logger.dart';
import 'package:supabase_common/supabase_common.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

/// Client for invoking Supabase Edge Functions.
class FunctionsClient {
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
  ///
  /// [requestTimeout] bounds how long an invocation may go without progress,
  /// see [invoke].
  ///
  /// Without an [httpClient], the client creates one of its own so that
  /// invocations reuse connections, and closes it in [dispose]. A client
  /// passed here belongs to the caller and is left open.
  FunctionsClient(
    String url,
    Map<String, String> headers, {
    http.Client? httpClient,
    AsyncJsonCodec? jsonCodec,
    FunctionsRegion? region,
    Future<String?> Function()? accessToken,
    Duration? requestTimeout,
  }) : assert(
         accessToken == null ||
             headers.header(HttpHeader.authorization) == null,
         'Pass either an Authorization header or accessToken, not both: the '
         'header would win over the resolved token on every invocation.',
       ),
       _url = url,
       _headers = {...FunctionsConstants.defaultHeaders, ...headers},
       _jsonCodec = jsonCodec ?? YAJsonIsolate(),
       _ownsJsonCodec = jsonCodec == null,
       _ownedHttpClient = httpClient == null ? createDefaultHttpClient() : null,
       _httpClient = httpClient,
       _accessToken = accessToken,
       _region = region,
       _requestTimeout = requestTimeout {
    functionsLogger.config(
      "Initialize FunctionsClient v$version with url "
      "'${Uri.parse(url).redacted}' and region "
      "'$region'",
    );
    functionsLogger.finest("Initialize with headers: ${headers.redacted}");
  }
  final String _url;
  final Map<String, String> _headers;

  /// The transport passed by the caller, which the client never closes, the
  /// same way it leaves a caller-provided JSON codec alone.
  final http.Client? _httpClient;
  final http.Client? _ownedHttpClient;
  final Future<String?> Function()? _accessToken;
  final AsyncJsonCodec _jsonCodec;
  final bool _ownsJsonCodec;
  final FunctionsRegion? _region;
  final Duration? _requestTimeout;

  /// The headers sent with every invocation, as an unmodifiable view.
  ///
  /// Pass headers to the constructor instead of mutating them here. A client
  /// managed by a `SupabaseClient` gets its headers replaced through the
  /// internal [replaceHeaders] when `SupabaseClient.headers` is assigned.
  Map<String, String> get headers => Map.unmodifiable(_headers);

  /// Sets an HTTP header for subsequent invocations.
  ///
  /// Returns this for method chaining. A header passed to [invoke] still wins
  /// over it for that single call. On a client managed by a `SupabaseClient`,
  /// assign `SupabaseClient.headers` instead, so that every client gets the
  /// header.
  ///
  /// ```dart
  /// functions.setHeader('x-custom-header', 'value');
  /// ```
  FunctionsClient setHeader(String key, String value) {
    _headers[key] = value;
    return this;
  }

  /// The transport invocations are sent over, resolving [_accessToken] first
  /// when one was given.
  ///
  /// Closing it would close the caller's client too, so [dispose] closes only
  /// [_ownedHttpClient].
  // ignore: dispose-class-fields
  late final http.Client _transport = switch (_accessToken) {
    null => _httpClient ?? _ownedHttpClient!,
    final accessToken => AccessTokenClient(
      accessToken,
      _httpClient ?? _ownedHttpClient,
    ),
  };

  /// Replaces the invocation headers with [newHeaders].
  @internal
  void replaceHeaders(Map<String, String> newHeaders) {
    _headers
      ..clear()
      ..addAll(newHeaders);
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
  /// [MultipartRequest] and must be a map of strings to strings. A body that
  /// cannot be encoded throws a [FunctionsFetchException] before anything is
  /// sent.
  ///
  /// [files] to send in a `MultipartRequest`. [body] is used for the fields.
  ///
  /// [queryParameters] are added to the URL. A value is sent as its
  /// `toString()`, an [Iterable] value as one parameter per element, and a
  /// `null` value is left out.
  ///
  /// [region] optionally specify the region to invoke the function in. When
  /// specified and not [FunctionsRegion.any], adds both the `x-region` header
  /// and the `forceFunctionRegion` query parameter.
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
  /// [requestTimeout] bounds how long the invocation may go without progress,
  /// overriding the timeout the client was created with. The timer restarts
  /// whenever a chunk of the request body is sent or a chunk of the response
  /// arrives, also on a streamed response while it is being listened to. A
  /// timed-out invocation is cancelled and throws a [FunctionsFetchException]
  /// caused by a `TimeoutException`, or emits the `TimeoutException` on the
  /// stream of a streamed response.
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
  Future<FunctionsResponse> invoke(
    String functionName, {
    // ignore: avoid-shadowing
    Map<String, String>? headers,
    Object? body,
    Iterable<http.MultipartFile>? files,
    Map<String, Object?>? queryParameters,
    HttpMethod method = HttpMethod.post,
    FunctionsRegion? region,
    Future<void>? abortSignal,
    Duration? requestTimeout,
  }) async {
    final effectiveRegion = region ?? _region;
    final forcedRegion = effectiveRegion == FunctionsRegion.any
        ? null
        : effectiveRegion?.value;
    final idleTimeout = IdleTimeout(requestTimeout ?? _requestTimeout);

    final effectiveQueryParameters = <String, Object>{
      if (queryParameters != null)
        for (final MapEntry(:key, :value) in queryParameters.entries)
          if (value != null)
            key: value is Iterable
                ? [for (final element in value) _queryValue(element)]
                : _queryValue(value),
      'forceFunctionRegion': ?forcedRegion,
    };

    final uri = Uri.parse('$_url/$functionName').replace(
      queryParameters: effectiveQueryParameters.isNotEmpty
          ? effectiveQueryParameters
          : null,
    );

    final finalHeaders = <String, String>{
      ..._headers,
      ...?headers,
      'x-region': ?forcedRegion,
    };

    final http.BaseRequest request;
    if (files != null) {
      final fields = _multipartFields(body);

      // No content type is set here: a multipart request generates its own
      // boundary while it is being finalized and sets the header itself.
      request =
          idleTimeout.multipartRequest(
              method.value,
              uri,
              abortSignal: abortSignal,
            )
            ..headers.addAll(finalHeaders)
            ..fields.addAll(fields)
            ..files.addAll(files);
    } else {
      final bodyRequest = idleTimeout.request(
        method.value,
        uri,
        abortSignal: abortSignal,
      )..headers.addAll(finalHeaders);

      if (body != null) {
        // The content type is set before the body, so that a body given as a
        // string is encoded with the charset the caller asked for, and so that
        // the charset `Request.body` fills in for itself is kept.
        bodyRequest.headers.putIfAbsent(
          HttpHeader.contentType,
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
          bodyRequest.body = await _encodeJson(body);
        }
      }
      request = bodyRequest;
    }

    functionsLogger.finest(
      'Request: ${request.method} ${request.url.redacted} '
      '${request.headers.redacted}',
    );

    final response = await _guardTransport(
      () => idleTimeout.send(request, _transport),
    );
    final responseType = response.headers.mediaType ?? 'text/plain';

    final isRelayError = response.headers['x-relay-error'] == 'true';
    final isSuccessStatus =
        isSuccessStatusCode(response.statusCode) && !isRelayError;

    if (responseType == 'text/event-stream' && isSuccessStatus) {
      // Only a successful streaming response hands the live stream to the
      // caller. On an error status there is nothing to stream, so the body is
      // drained below to become the exception `details` and the connection
      // isn't left open.
      return FunctionsResponse(
        data: response.stream,
        statusCode: response.statusCode,
        headers: response.headers,
      );
    }
    final Uint8List bodyBytes;
    try {
      bodyBytes = await response.stream.toBytes();
    } on http.RequestAbortedException {
      rethrow;
    } catch (error) {
      // A body that stops arriving on a success status leaves the caller with
      // nothing usable, so it is a transport failure, and so is a timeout on
      // any status. Otherwise, on an error status the status itself is the
      // answer, so it is kept with the read error as the details.
      if (isSuccessStatus || error is TimeoutException) {
        throw _unreadableResponse(error);
      }
      throw _apiException(response, isRelayError, details: error);
    }
    final dynamic data;
    if (_isJson(responseType)) {
      if (bodyBytes.isEmpty) {
        data = null;
      } else {
        dynamic decoded;
        try {
          decoded = await _jsonCodec.decodeBytes(bodyBytes);
        } on FormatException catch (error) {
          // A body labeled JSON that doesn't parse is only tolerated on an
          // error status, where the raw text still needs to reach the caller
          // as the exception `details`. On a success status it's a real
          // anomaly, so surface it instead of handing back a String.
          if (isSuccessStatus) throw _unreadableResponse(error);
          decoded = utf8.decode(bodyBytes, allowMalformed: true);
        }
        data = decoded;
      }
    } else if (responseType == 'application/octet-stream') {
      data = bodyBytes;
    } else if (isSuccessStatus) {
      try {
        data = utf8.decode(bodyBytes);
      } on FormatException catch (error) {
        throw _unreadableResponse(error);
      }
    } else {
      data = utf8.decode(bodyBytes, allowMalformed: true);
    }

    if (isSuccessStatus) {
      return FunctionsResponse(
        data: data,
        statusCode: response.statusCode,
        headers: response.headers,
      );
    }
    throw _apiException(
      response,
      isRelayError,
      details: data,
      body: utf8.decode(bodyBytes, allowMalformed: true),
    );
  }

  /// Whether [mediaType] is JSON, `application/json` or a structured syntax
  /// type such as `application/problem+json`.
  static bool _isJson(String mediaType) =>
      mediaType == 'application/json' || mediaType.endsWith('+json');

  /// The fields of a multipart request, from a [body] that must be a map of
  /// strings to strings.
  static Map<String, String> _multipartFields(Object? body) {
    return switch (body) {
      null => const {},
      Map<String, String>() => body,
      Map() when body.entries.every((entry) => entry.value is String) => {
        for (final MapEntry(:key, :value) in body.entries) '$key': '$value',
      },
      _ => throw FunctionsFetchException(
        message:
            'The body of a multipart request must be a map of strings to '
            'strings',
        cause: ArgumentError.value(body, 'body'),
      ),
    };
  }

  /// The exception for a response whose body could not be read, or, on a
  /// success status, could not be decoded.
  static FunctionsFetchException _unreadableResponse(Object error) =>
      FunctionsFetchException(
        message: 'Failed to read the response of the Edge Function',
        cause: error,
      );

  /// A query parameter [value] as text, a [DateTime] in ISO 8601.
  static String _queryValue(Object? value) =>
      value is DateTime ? value.toIso8601String() : '$value';

  Future<String> _encodeJson(Object body) async {
    try {
      return await _jsonCodec.encode(body);
    } on JsonUnsupportedObjectError catch (error) {
      throw FunctionsFetchException(
        message: 'Failed to encode the request body as JSON',
        cause: error,
      );
    }
  }

  /// Builds the exception for an error [response], a relay one when
  /// [isRelayError].
  ///
  /// A JSON object body supplies the message and the error code. Otherwise the
  /// message is the reason phrase, and when that is absent too, as it is over
  /// HTTP/2, each exception uses its own default.
  FunctionsApiException _apiException(
    http.StreamedResponse response,
    bool isRelayError, {
    required Object? details,
    String? body,
  }) {
    final requestId = response.headers.requestId;
    final (:message, :errorCode) = switch (details) {
      Map() => (
        message:
            _stringField(details, 'message') ??
            _stringField(details, 'error') ??
            response.reasonPhrase,
        errorCode:
            _stringField(details, 'code') ??
            _stringField(details, 'error_code'),
      ),
      _ => (message: response.reasonPhrase, errorCode: null),
    };
    if (isRelayError) {
      return FunctionsRelayException(
        statusCode: response.statusCode,
        details: details,
        errorCode: errorCode,
        requestId: requestId,
        headers: response.headers,
        body: body,
        message: message,
      );
    }
    return FunctionsApiException(
      statusCode: response.statusCode,
      details: details,
      errorCode: errorCode,
      requestId: requestId,
      headers: response.headers,
      body: body,
      message: message,
    );
  }

  /// The value of [key] in [map] when it is a non-empty string.
  static String? _stringField(Map<dynamic, dynamic> map, String key) {
    final value = map[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// Runs [action], wrapping a failure to get a response in a
  /// [FunctionsFetchException]. An abort and an exception the HTTP client
  /// already classified keep their own type.
  Future<T> _guardTransport<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on http.RequestAbortedException {
      rethrow;
    } on SupabaseException {
      rethrow;
    } catch (error) {
      throw FunctionsFetchException(cause: error);
    }
  }

  /// Disposes the JSON codec and closes the HTTP client the client created
  /// for itself.
  ///
  /// Leaves a codec or an HTTP client passed to the constructor alone, since
  /// those belong to the caller.
  Future<void> dispose() async {
    functionsLogger.fine("Dispose FunctionsClient");
    _ownedHttpClient?.close();
    if (_ownsJsonCodec) {
      return _jsonCodec.dispose();
    }
  }
}
