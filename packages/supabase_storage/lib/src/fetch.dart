import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:supabase_storage/src/logger.dart';
import 'package:meta/meta.dart';
import 'package:mime/mime.dart';
import 'package:supabase_storage/src/types.dart';
import 'package:supabase_common/supabase_common.dart';

import 'file_stub.dart' if (dart.library.io) './file_io.dart';

@internal
class Fetch {
  const Fetch([this.httpClient, this.requestTimeout]);
  final Client? httpClient;

  /// How long a request may go without progress, `null` for no limit.
  final Duration? requestTimeout;

  MediaType _parseMediaType(String path) {
    final mime = lookupMimeType(path);
    return MediaType.parse(mime ?? 'application/octet-stream');
  }

  StorageApiException _handleError(
    http.Response response,
    StackTrace stackTrace,
    Uri? url,
    FetchOptions? options,
  ) {
    final data = tryDecodeJsonObject(response.body);
    final requestId = response.headers.requestId;

    if (data == null) {
      storageLogger.fine(
        'StorageException for ${url?.redacted}',
        response.body,
        stackTrace,
      );
      return StorageApiException(
        response.body.isEmpty ? (response.reasonPhrase ?? '') : response.body,
        statusCode: response.statusCode,
        requestId: requestId,
        headers: response.headers,
        body: response.body,
      );
    }

    final exception = StorageApiException.fromJson(
      data,
      response.statusCode,
      requestId: requestId,
      headers: response.headers,
      body: response.body,
    );
    storageLogger.fine(
      'StorageException for ${url?.redacted}',
      exception,
      stackTrace,
    );
    return exception;
  }

  StorageTransportException _transportException(
    Uri? url,
    Exception error,
    StackTrace stackTrace,
  ) {
    storageLogger.fine(
      'StorageTransportException for ${url?.redacted}',
      error,
      stackTrace,
    );
    return StorageTransportException('Request failed: $error', cause: error);
  }

  /// Sends [request] under [idleTimeout], wrapping a failure to get a
  /// response in a [StorageTransportException]. An abort and an exception the
  /// HTTP client already classified keep their own type.
  Future<http.StreamedResponse> _send(
    http.BaseRequest request,
    IdleTimeout idleTimeout,
  ) async {
    try {
      return await idleTimeout.send(request, httpClient);
    } on http.RequestAbortedException {
      rethrow;
    } on SupabaseException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      throw _transportException(request.url, error, stackTrace);
    }
  }

  /// Reads the body of [streamedResponse].
  ///
  /// A body that stops arriving on a success status leaves the caller with
  /// nothing usable, so it is a [StorageTransportException], and so is a
  /// timeout on any status. Otherwise, on an error status the status itself is
  /// the answer, so it is kept as a [StorageApiException] naming the read
  /// error.
  Future<http.Response> _read(http.StreamedResponse streamedResponse) async {
    try {
      return await http.Response.fromStream(streamedResponse);
    } on http.RequestAbortedException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      final url = streamedResponse.request?.url;
      if (isSuccessStatusCode(streamedResponse.statusCode) ||
          error is TimeoutException) {
        throw _transportException(url, error, stackTrace);
      }
      final exception = StorageApiException(
        'Failed to read the response: $error',
        statusCode: streamedResponse.statusCode,
        requestId: streamedResponse.headers.requestId,
        headers: streamedResponse.headers,
      );
      storageLogger.fine(
        'StorageException for ${url?.redacted}',
        exception,
        stackTrace,
      );
      throw exception;
    }
  }

  http.Request _createRequest(
    HttpMethod method,
    String url,
    FetchOptions? options,
    IdleTimeout idleTimeout,
    Future<void>? abortSignal,
  ) {
    return idleTimeout.request(
      method.value,
      Uri.parse(url),
      abortSignal: abortSignal,
    )..headers.addAll({...?options?.headers});
  }

  Future<T> _handleRequest<T>(
    HttpMethod method,
    String url,
    Map<String, dynamic>? body,
    FetchOptions? options, {
    Future<void>? abortSignal,
  }) async {
    final idleTimeout = IdleTimeout(requestTimeout);
    final request = _createRequest(
      method,
      url,
      options,
      idleTimeout,
      abortSignal,
    );
    if (method != HttpMethod.get) {
      request.headers.putIfAbsent(
        HttpHeader.contentType,
        () => 'application/json',
      );
    }
    if (body != null) {
      request.body = json.encode(body);
    }

    storageLogger.finest(
      'Request: ${method.value} ${Uri.parse(url).redacted} '
      '${request.headers.redacted}',
    );
    final streamedResponse = await _send(request, idleTimeout);
    return _handleResponse(streamedResponse, options);
  }

  /// Sends an upload whose body is produced by [createBody] on every attempt,
  /// so a retry reads a fresh stream instead of one an earlier attempt already
  /// consumed.
  ///
  /// The file is the raw request body. `Content-Type`, `Cache-Control`,
  /// `x-upsert` and `x-metadata` carry what the multipart form fields used to.
  /// [contentLength] is sent as `Content-Length` when known; otherwise the
  /// body goes out with chunked transfer encoding.
  Future<Map<String, dynamic>> _handleUploadRequest(
    HttpMethod method,
    String url,
    Stream<List<int>> Function() createBody,
    int? contentLength,
    String contentTypePath,
    FileOptions fileOptions,
    FetchOptions? options,
    SupabaseRetryOptions retryOptions,
    Future<void>? abortSignal,
  ) async {
    final contentType = fileOptions.contentType != null
        ? MediaType.parse(fileOptions.contentType!)
        : _parseMediaType(contentTypePath);
    final headers = {
      ...?options?.headers,
      HttpHeader.contentType: contentType.toString(),
      'Cache-Control': 'max-age=${fileOptions.cacheControl}',
      'x-upsert': fileOptions.upsert.toString(),
      if (fileOptions.metadata != null)
        'x-metadata': base64.encode(
          utf8.encode(json.encode(fileOptions.metadata)),
        ),
      ...?fileOptions.headers,
    };

    var attempts = 0;
    final streamedResponse = await retry<http.StreamedResponse>(
      () async {
        attempts++;
        storageLogger.finest(
          'Request: attempt: $attempts ${method.value} '
          '${Uri.parse(url).redacted} ${headers.redacted}',
        );
        final idleTimeout = IdleTimeout(requestTimeout);
        final request = _UploadRequest(
          method.value,
          Uri.parse(url),
          () => idleTimeout.watchRequestBody(createBody()),
          abortTrigger: idleTimeout.abortTrigger(abortSignal),
        );
        request
          ..headers.addAll(headers)
          ..contentLength = contentLength;
        return _send(request, idleTimeout);
      },
      options: retryOptions,
      retryIf: (error) => error is StorageTransportException,
      abortSignal: abortSignal,
    );

    return _handleResponse(streamedResponse, options);
  }

  /// Reads the response body and returns it as a [T]: [Uint8List] when
  /// `noResolveJson` is set, `null` for an empty body, and decoded JSON
  /// otherwise. Throws a [StorageException] when the body is not a [T].
  Future<T> _handleResponse<T>(
    http.StreamedResponse streamedResponse,
    FetchOptions? options,
  ) async {
    final response = await _read(streamedResponse);
    if (isSuccessStatusCode(response.statusCode)) {
      final dynamic body;
      if (options?.noResolveJson == true) {
        body = response.bodyBytes;
      } else if (response.body.isEmpty) {
        body = null;
      } else {
        body = json.decode(response.body);
      }
      if (body is! T) {
        throw StorageException(
          'Expected a $T response, but got a ${body.runtimeType}',
          requestId: response.headers.requestId,
        );
      }
      return body;
    }
    throw _handleError(
      response,
      StackTrace.current,
      response.request?.url,
      options,
    );
  }

  Future<void> head(String url, {FetchOptions? options}) {
    return _handleRequest<dynamic>(
      HttpMethod.head,
      url,
      null,
      FetchOptions(options?.headers, noResolveJson: true),
    );
  }

  Future<T> get<T>(
    String url, {
    FetchOptions? options,
    Future<void>? abortSignal,
  }) {
    return _handleRequest(
      HttpMethod.get,
      url,
      null,
      options,
      abortSignal: abortSignal,
    );
  }

  /// Performs a GET request and yields the response body as a byte stream
  /// without buffering it in memory.
  ///
  /// The status code is inspected before the body is yielded, so a non-success
  /// response surfaces as a [StorageException] on the stream before any bytes
  /// are emitted.
  @internal
  Stream<Uint8List> getStream(
    String url, {
    FetchOptions? options,
    Future<void>? abortSignal,
  }) async* {
    final idleTimeout = IdleTimeout(requestTimeout);
    final request = _createRequest(
      HttpMethod.get,
      url,
      options,
      idleTimeout,
      abortSignal,
    );

    storageLogger.finest(
      'Request: GET (stream) ${Uri.parse(url).redacted} '
      '${request.headers.redacted}',
    );
    final streamedResponse = await _send(request, idleTimeout);

    if (!isSuccessStatusCode(streamedResponse.statusCode)) {
      final response = await _read(streamedResponse);
      throw _handleError(
        response,
        StackTrace.current,
        response.request?.url,
        FetchOptions(options?.headers, noResolveJson: true),
      );
    }

    yield* streamedResponse.stream.map(
      (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
    );
  }

  Future<T> post<T>(
    String url,
    Map<String, dynamic>? body, {
    FetchOptions? options,
  }) {
    return _handleRequest(HttpMethod.post, url, body, options);
  }

  Future<T> put<T>(
    String url,
    Map<String, dynamic>? body, {
    FetchOptions? options,
  }) {
    return _handleRequest(HttpMethod.put, url, body, options);
  }

  Future<T> delete<T>(
    String url,
    Map<String, dynamic>? body, {
    FetchOptions? options,
  }) {
    return _handleRequest(HttpMethod.delete, url, body, options);
  }

  /// Uploads [file] with [method], streaming it from disk.
  Future<Map<String, dynamic>> uploadFile(
    HttpMethod method,
    String url,
    File file,
    FileOptions fileOptions, {
    FetchOptions? options,
    required SupabaseRetryOptions retryOptions,
    Future<void>? abortSignal,
  }) async {
    final int contentLength = await file.length();
    return _handleUploadRequest(
      method,
      url,
      () => file.openRead(),
      contentLength,
      file.path,
      fileOptions,
      options,
      retryOptions,
      abortSignal,
    );
  }

  /// Uploads [data] with [method].
  Future<Map<String, dynamic>> uploadBytes(
    HttpMethod method,
    String url,
    Uint8List data,
    FileOptions fileOptions, {
    FetchOptions? options,
    required SupabaseRetryOptions retryOptions,
    Future<void>? abortSignal,
  }) {
    return _handleUploadRequest(
      method,
      url,
      () => Stream.value(data),
      data.length,
      Uri.parse(url).path,
      fileOptions,
      options,
      retryOptions,
      abortSignal,
    );
  }

  /// Uploads the bytes of [data] with [method] as they are read.
  ///
  /// A stream can only be listened to once, so the request is never retried.
  Future<Map<String, dynamic>> uploadStream(
    HttpMethod method,
    String url,
    Stream<List<int>> data,
    int? contentLength,
    FileOptions fileOptions, {
    FetchOptions? options,
    Future<void>? abortSignal,
  }) {
    return _handleUploadRequest(
      method,
      url,
      () => data,
      contentLength,
      Uri.parse(url).path,
      fileOptions,
      options,
      const SupabaseRetryOptions(enabled: false),
      abortSignal,
    );
  }
}

/// A request whose body is created when it is finalized, so each attempt of a
/// retried upload sends a fresh stream.
final class _UploadRequest extends http.BaseRequest with http.Abortable {
  _UploadRequest(
    super.method,
    super.url,
    this._createBody, {
    this.abortTrigger,
  });

  final Stream<List<int>> Function() _createBody;

  @override
  final Future<void>? abortTrigger;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_createBody());
  }
}
