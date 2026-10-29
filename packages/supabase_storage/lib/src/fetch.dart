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

/// [segment] percent-encoded as one segment of a URL path, so a `/`, `?` or
/// `#` in it stays part of the segment.
///
/// Throws an [ArgumentError] for an empty segment, `.` and `..`, which a URL
/// cannot hold as a segment of their own.
@internal
String encodePathSegment(String segment) {
  if (segment.isEmpty || segment == '.' || segment == '..') {
    throw ArgumentError.value(segment, 'id', 'Must not be empty, "." or ".."');
  }
  return Uri(pathSegments: [segment]).path;
}

@internal
class Fetch {
  const Fetch([this.httpClient, this.requestTimeout]);
  final Client? httpClient;

  /// How long a request may go without progress, `null` for no limit.
  final Duration? requestTimeout;

  MediaType _parseMediaType(String path, [String? fallbackPath]) {
    final mime =
        lookupMimeType(path) ??
        (fallbackPath == null ? null : lookupMimeType(fallbackPath));
    return MediaType.parse(mime ?? 'application/octet-stream');
  }

  StorageApiException _handleError(
    http.Response response,
    Uri? url,
    FetchOptions? options,
  ) {
    final data = tryDecodeJsonObject(response.body);
    final requestId = response.headers.requestId;

    if (data == null) {
      storageLogger.fine(
        'StorageException (${response.statusCode}) for ${url?.loggable}',
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
      'StorageException (${response.statusCode}) for ${url?.loggable}',
    );
    return exception;
  }

  StorageTransportException _transportException(Uri? url, Exception error) {
    storageLogger.fine(
      'StorageTransportException (${error.runtimeType}) for ${url?.loggable}',
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
    } on Exception catch (error) {
      throw _transportException(request.url, error);
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
    } on Exception catch (error) {
      final url = streamedResponse.request?.url;
      if (isSuccessStatusCode(streamedResponse.statusCode) ||
          error is TimeoutException) {
        throw _transportException(url, error);
      }
      final exception = StorageApiException(
        'Failed to read the response: $error',
        statusCode: streamedResponse.statusCode,
        requestId: streamedResponse.headers.requestId,
        headers: streamedResponse.headers,
      );
      storageLogger.fine(
        'StorageException (${streamedResponse.statusCode}) for '
        '${url?.loggable}',
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
    bool partialContent = false,
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
      'Request: ${method.value} ${Uri.parse(url).loggable}',
    );
    final streamedResponse = await _send(request, idleTimeout);
    if (partialContent) await _requirePartialContent(streamedResponse);
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
  ///
  /// [onProgress] is called as the body is handed to the HTTP client. An
  /// exception it throws fails the upload without a retry.
  ///
  /// Unless [idempotent], an attempt that fails after the HTTP client read
  /// the whole body is not retried, since storage may have stored the file
  /// and a retry would then fail as a duplicate.
  Future<Map<String, dynamic>> _handleUploadRequest(
    HttpMethod method,
    String url,
    Stream<List<int>> Function() createBody,
    int? contentLength,
    String contentType,
    FileOptions fileOptions,
    FetchOptions? options,
    SupabaseRetryOptions retryOptions,
    Future<void>? abortSignal,
    UploadProgressCallback? onProgress, {
    bool idempotent = false,
  }) async {
    final headers = {
      ...?options?.headers,
      HttpHeader.contentType: contentType,
      'Cache-Control': 'max-age=${fileOptions.cacheControl}',
      'x-upsert': fileOptions.upsert.toString(),
      if (fileOptions.metadata != null)
        'x-metadata': base64.encode(
          utf8.encode(json.encode(fileOptions.metadata)),
        ),
      ...?fileOptions.headers,
    };

    final progress = onProgress == null
        ? null
        : _UploadProgress(onProgress, contentLength);
    Stream<List<int>> createWatchedBody() {
      final body = createBody();
      return progress?.watch(body) ?? body;
    }

    var attempts = 0;
    var bodySent = false;
    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await retry<http.StreamedResponse>(
        () async {
          final attempt = ++attempts;
          bodySent = false;
          storageLogger.finest(
            'Request: attempt: $attempts ${method.value} '
            '${Uri.parse(url).loggable}',
          );
          final idleTimeout = IdleTimeout(requestTimeout);
          final request = _UploadRequest(
            method.value,
            Uri.parse(url),
            () => _onDone(
              idleTimeout.watchRequestBody(createWatchedBody()),
              () {
                if (attempt == attempts) bodySent = true;
              },
            ),
            abortTrigger: idleTimeout.abortTrigger(abortSignal),
          );
          request
            ..headers.addAll(headers)
            ..contentLength = contentLength;
          return _send(request, idleTimeout);
        },
        options: retryOptions,
        retryIf: (error) =>
            error is StorageTransportException &&
            progress?.callbackError == null &&
            (idempotent || !bodySent),
        abortSignal: abortSignal,
      );
    } on Object {
      progress?.rethrowCallbackError();
      rethrow;
    } finally {
      progress?.finish();
    }

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
        try {
          body = json.decode(response.body);
        } on FormatException catch (error) {
          throw StorageException(
            'Expected a JSON response, but got: ${error.message}',
            requestId: response.headers.requestId,
          );
        }
      }
      if (body is! T) {
        throw StorageException(
          'Expected a $T response, but got a ${body.runtimeType}',
          requestId: response.headers.requestId,
        );
      }
      return body;
    }
    throw _handleError(response, response.request?.url, options);
  }

  /// Performs a GET request.
  ///
  /// {@template storage_fetch_partial_content}
  /// With [partialContent], the request asks for a byte range, and a success
  /// response other than 206 Partial Content throws a [StorageException],
  /// since its body is the whole file instead of the range.
  /// {@endtemplate}
  Future<T> get<T>(
    String url, {
    FetchOptions? options,
    Future<void>? abortSignal,
    bool partialContent = false,
  }) {
    return _handleRequest(
      HttpMethod.get,
      url,
      null,
      options,
      abortSignal: abortSignal,
      partialContent: partialContent,
    );
  }

  /// Throws when [streamedResponse] is a success other than 206 Partial
  /// Content, after releasing its body.
  Future<void> _requirePartialContent(
    http.StreamedResponse streamedResponse,
  ) async {
    final statusCode = streamedResponse.statusCode;
    if (!isSuccessStatusCode(statusCode) || statusCode == 206) return;
    await streamedResponse.stream.listen(null).cancel();
    throw StorageException(
      'Expected the requested byte range with status 206, but got the whole '
      'file with status $statusCode',
      requestId: streamedResponse.headers.requestId,
    );
  }

  /// Performs a GET request and yields the response body as a byte stream
  /// without buffering it in memory.
  ///
  /// The status code is inspected before the body is yielded, so a non-success
  /// response surfaces as a [StorageException] on the stream before any bytes
  /// are emitted.
  ///
  /// {@macro storage_fetch_partial_content}
  @internal
  Stream<Uint8List> getStream(
    String url, {
    FetchOptions? options,
    Future<void>? abortSignal,
    bool partialContent = false,
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
      'Request: GET (stream) ${Uri.parse(url).loggable}',
    );
    final streamedResponse = await _send(request, idleTimeout);

    if (!isSuccessStatusCode(streamedResponse.statusCode)) {
      final response = await _read(streamedResponse);
      throw _handleError(
        response,
        response.request?.url,
        FetchOptions(options?.headers, noResolveJson: true),
      );
    }

    if (partialContent) await _requirePartialContent(streamedResponse);
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

  /// Sends one request of the tus protocol and returns the response whatever
  /// its status, so the caller can tell the statuses tus gives a meaning
  /// apart. [createBody] streams the request body, and [abortSignal] aborts
  /// the request.
  ///
  /// A request that never receives a response throws a
  /// [StorageTransportException].
  Future<http.Response> sendTus(
    HttpMethod method,
    Uri url,
    Map<String, String> headers, {
    Stream<List<int>> Function()? createBody,
    int? contentLength,
    Future<void>? abortSignal,
  }) async {
    final idleTimeout = IdleTimeout(requestTimeout);
    final request = _UploadRequest(
      method.value,
      url,
      () => idleTimeout.watchRequestBody(
        createBody?.call() ?? const Stream.empty(),
      ),
      abortTrigger: idleTimeout.abortTrigger(abortSignal),
    );
    request
      ..headers.addAll(headers)
      ..contentLength = contentLength ?? (createBody == null ? 0 : null);
    storageLogger.finest(
      'Request: ${method.value} ${url.loggable}',
    );
    return _read(await _send(request, idleTimeout));
  }

  /// The [StorageApiException] for an error [response], whose body is the
  /// JSON error envelope of storage or, as the tus routes answer, plain text.
  StorageApiException apiException(http.Response response) =>
      _handleError(response, response.request?.url, null);

  /// The media type a file at [path] is stored with unless the upload names
  /// one, guessed from [fallbackPath] when [path] tells nothing.
  String contentTypeFor(String path, {String? fallbackPath}) =>
      _parseMediaType(path, fallbackPath).toString();

  /// The content type of an upload: the one [fileOptions] names, or the one
  /// guessed from [path], then from [fallbackPath].
  String _uploadContentType(
    FileOptions fileOptions,
    String path, [
    String? fallbackPath,
  ]) => MediaType.parse(
    fileOptions.contentType ?? contentTypeFor(path, fallbackPath: fallbackPath),
  ).toString();

  /// Uploads [file] with [method], streaming it from disk.
  ///
  /// {@template storage_fetch_idempotent}
  /// [idempotent] marks an upload that replaces the object, which is retried
  /// even after its whole body was sent.
  /// {@endtemplate}
  Future<Map<String, dynamic>> uploadFile(
    HttpMethod method,
    String url,
    File file,
    FileOptions fileOptions, {
    FetchOptions? options,
    required SupabaseRetryOptions retryOptions,
    required bool idempotent,
    Future<void>? abortSignal,
    UploadProgressCallback? onProgress,
  }) async {
    final int contentLength = await file.length();
    return _handleUploadRequest(
      method,
      url,
      () => file.openRead(),
      contentLength,
      _uploadContentType(fileOptions, file.path, Uri.parse(url).path),
      fileOptions,
      options,
      retryOptions,
      abortSignal,
      onProgress,
      idempotent: idempotent,
    );
  }

  /// Uploads [data] with [method].
  ///
  /// {@macro storage_fetch_idempotent}
  Future<Map<String, dynamic>> uploadBytes(
    HttpMethod method,
    String url,
    Uint8List data,
    FileOptions fileOptions, {
    FetchOptions? options,
    required SupabaseRetryOptions retryOptions,
    required bool idempotent,
    Future<void>? abortSignal,
    UploadProgressCallback? onProgress,
  }) {
    return _handleUploadRequest(
      method,
      url,
      () => Stream.value(data),
      data.length,
      _uploadContentType(fileOptions, Uri.parse(url).path),
      fileOptions,
      options,
      retryOptions,
      abortSignal,
      onProgress,
      idempotent: idempotent,
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
    UploadProgressCallback? onProgress,
  }) {
    return _handleUploadRequest(
      method,
      url,
      () => data,
      contentLength,
      _uploadContentType(fileOptions, Uri.parse(url).path),
      fileOptions,
      options,
      const SupabaseRetryOptions(enabled: false),
      abortSignal,
      onProgress,
    );
  }
}

/// Passes [body] through and calls [onDone] once all of it was read.
Stream<List<int>> _onDone(
  Stream<List<int>> body,
  void Function() onDone,
) async* {
  yield* body;
  onDone();
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

/// Reports the progress of the bodies an upload sends, one per attempt.
///
/// Only the body of the latest attempt reports, and nothing reports once the
/// upload is [finish]ed. A body sent after an earlier one has reported starts
/// with a report of `0`, and a body that yields no bytes reports `0` once.
final class _UploadProgress {
  _UploadProgress(this._onProgress, this._totalBytes);

  final UploadProgressCallback _onProgress;
  final int? _totalBytes;
  var _attempt = 0;
  var _reported = false;
  var _finished = false;

  /// What the callback threw, which fails the upload instead of an error of
  /// the HTTP client.
  (Object, StackTrace)? callbackError;

  Stream<List<int>> watch(Stream<List<int>> body) =>
      _watch(++_attempt, sliceRequestBody(body));

  Stream<List<int>> _watch(int attempt, Stream<List<int>> body) async* {
    var reported = false;
    if (_reported) {
      reported = _report(attempt, 0);
    }
    var sentBytes = 0;
    await for (final chunk in body) {
      yield chunk;
      if (chunk.isEmpty) continue;
      sentBytes += chunk.length;
      reported = _report(attempt, sentBytes);
    }
    if (!reported) _report(attempt, 0);
  }

  bool _report(int attempt, int sentBytes) {
    if (_finished || attempt != _attempt) return false;
    _reported = true;
    try {
      _onProgress(sentBytes, _totalBytes);
    } catch (error, stackTrace) {
      callbackError ??= (error, stackTrace);
      rethrow;
    }
    return true;
  }

  void finish() => _finished = true;

  void rethrowCallbackError() {
    final callbackError = this.callbackError;
    if (callbackError == null) return;
    Error.throwWithStackTrace(callbackError.$1, callbackError.$2);
  }
}
