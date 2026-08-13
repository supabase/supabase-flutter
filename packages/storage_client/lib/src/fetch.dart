import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:mime/mime.dart';
import 'package:storage_client/src/types.dart';
import 'package:supabase_common/supabase_common.dart';

import 'file_stub.dart' if (dart.library.io) './file_io.dart';

@internal
class Fetch {
  final Client? httpClient;
  final _log = Logger('supabase.storage');

  Fetch([this.httpClient]);

  MediaType _parseMediaType(String path) {
    final mime = lookupMimeType(path);
    return MediaType.parse(mime ?? 'application/octet-stream');
  }

  StorageException _handleError(
    dynamic error,
    StackTrace stackTrace,
    Uri? url,
    FetchOptions? options,
  ) {
    if (error is! http.Response) {
      // No response was received, so there is neither a status nor a service
      // error code to report. The error's own toString names its type.
      _log.fine('StorageException for $url', error, stackTrace);
      return StorageException(error.toString());
    }

    final data = tryDecodeJsonObject(error.body);

    if (data == null) {
      _log.fine('StorageException for $url', error.body, stackTrace);
      return StorageApiException(
        error.body.isEmpty ? (error.reasonPhrase ?? '') : error.body,
        statusCode: error.statusCode,
      );
    }

    final exception = StorageApiException.fromJson(data, error.statusCode);
    _log.fine('StorageException for $url', exception, stackTrace);
    return exception;
  }

  Future<dynamic> _handleRequest(
    HttpMethod method,
    String url,
    Map<String, dynamic>? body,
    FetchOptions? options,
  ) async {
    final request = http.Request(method.value, Uri.parse(url))
      ..headers.addAll({...?options?.headers});
    if (method != HttpMethod.get) {
      request.headers.putIfAbsent('Content-Type', () => 'application/json');
    }
    if (body != null) {
      request.body = json.encode(body);
    }

    _log.finest('Request: ${method.value} $url ${request.headers}');
    final streamedResponse = await request.sendWith(httpClient);
    return _handleResponse(streamedResponse, options);
  }

  Future<dynamic> _handleFileRequest(
    HttpMethod method,
    String url,
    File file,
    FileOptions fileOptions,
    FetchOptions? options,
    int retryAttempts,
    StorageRetryController? retryController,
  ) {
    final contentType = fileOptions.contentType != null
        ? MediaType.parse(fileOptions.contentType!)
        : _parseMediaType(file.path);
    final bytes = file.readAsBytesSync();
    return _handleMultipartRequest(
      method,
      url,
      () => http.MultipartFile.fromBytes(
        '',
        bytes,
        filename: file.path,
        contentType: contentType,
      ),
      fileOptions,
      options,
      retryAttempts,
      retryController,
    );
  }

  Future<dynamic> _handleBinaryFileRequest(
    HttpMethod method,
    String url,
    Uint8List data,
    FileOptions fileOptions,
    FetchOptions? options,
    int retryAttempts,
    StorageRetryController? retryController,
  ) {
    final contentType = fileOptions.contentType != null
        ? MediaType.parse(fileOptions.contentType!)
        : _parseMediaType(Uri.parse(url).path);
    return _handleMultipartRequest(
      method,
      url,
      () => http.MultipartFile.fromBytes(
        '',
        data,
        // request fails with null filename so set it empty instead.
        filename: '',
        contentType: contentType,
      ),
      fileOptions,
      options,
      retryAttempts,
      retryController,
    );
  }

  Future<dynamic> _handleMultipartRequest(
    HttpMethod method,
    String url,
    MultipartFile Function() createMultipartFile,
    FileOptions fileOptions,
    FetchOptions? options,
    int retryAttempts,
    StorageRetryController? retryController,
  ) async {
    final headers = options?.headers ?? {};

    // Create a factory function that generates a fresh MultipartRequest for
    // each attempt
    http.MultipartRequest createRequest() {
      final request = http.MultipartRequest(method.value, Uri.parse(url))
        ..headers.addAll(headers)
        ..files.add(createMultipartFile())
        ..fields['cacheControl'] = fileOptions.cacheControl
        ..headers['x-upsert'] = fileOptions.upsert.toString();
      if (fileOptions.metadata != null) {
        request.fields['metadata'] = json.encode(fileOptions.metadata);
      }
      if (fileOptions.headers != null) {
        request.headers.addAll(fileOptions.headers!);
      }
      return request;
    }

    final http.StreamedResponse streamedResponse;
    final r = RetryOptions(maxAttempts: (retryAttempts + 1));
    var attempts = 0;
    streamedResponse = await r.retry<http.StreamedResponse>(
      () async {
        attempts++;
        _log.finest(
          'Request: attempt: $attempts ${method.value} $url $headers',
        );

        // Create a fresh request for each retry attempt
        return createRequest().sendWith(httpClient);
      },
      retryIf: (error) =>
          retryController?.cancelled != true &&
          (error is ClientException || error is TimeoutException),
    );

    return _handleResponse(streamedResponse, options);
  }

  Future<dynamic> _handleResponse(
    http.StreamedResponse streamedResponse,
    FetchOptions? options,
  ) async {
    final response = await http.Response.fromStream(streamedResponse);
    if (isSuccessStatusCode(response.statusCode)) {
      if (options?.noResolveJson == true) {
        return response.bodyBytes;
      }
      if (response.body.isEmpty) {
        return null;
      }
      final jsonBody = json.decode(response.body);
      return jsonBody;
    }
    throw _handleError(
      response,
      StackTrace.current,
      response.request?.url,
      options,
    );
  }

  Future<dynamic> head(String url, {FetchOptions? options}) {
    return _handleRequest(
      HttpMethod.head,
      url,
      null,
      FetchOptions(options?.headers, noResolveJson: true),
    );
  }

  Future<dynamic> get(String url, {FetchOptions? options}) {
    return _handleRequest(HttpMethod.get, url, null, options);
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
  }) async* {
    final request = http.Request(HttpMethod.get.value, Uri.parse(url))
      ..headers.addAll({...?options?.headers});

    _log.finest('Request: GET (stream) $url ${request.headers}');
    final streamedResponse = await request.sendWith(httpClient);

    if (!isSuccessStatusCode(streamedResponse.statusCode)) {
      final response = await http.Response.fromStream(streamedResponse);
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

  Future<dynamic> post(
    String url,
    Map<String, dynamic>? body, {
    FetchOptions? options,
  }) {
    return _handleRequest(HttpMethod.post, url, body, options);
  }

  Future<dynamic> put(
    String url,
    Map<String, dynamic>? body, {
    FetchOptions? options,
  }) {
    return _handleRequest(HttpMethod.put, url, body, options);
  }

  Future<dynamic> delete(
    String url,
    Map<String, dynamic>? body, {
    FetchOptions? options,
  }) {
    return _handleRequest(HttpMethod.delete, url, body, options);
  }

  Future<dynamic> postFile(
    String url,
    File file,
    FileOptions fileOptions, {
    FetchOptions? options,
    required int retryAttempts,
    required StorageRetryController? retryController,
  }) {
    return _handleFileRequest(
      HttpMethod.post,
      url,
      file,
      fileOptions,
      options,
      retryAttempts,
      retryController,
    );
  }

  Future<dynamic> putFile(
    String url,
    File file,
    FileOptions fileOptions, {
    FetchOptions? options,
    required int retryAttempts,
    required StorageRetryController? retryController,
  }) {
    return _handleFileRequest(
      HttpMethod.put,
      url,
      file,
      fileOptions,
      options,
      retryAttempts,
      retryController,
    );
  }

  Future<dynamic> postBinaryFile(
    String url,
    Uint8List data,
    FileOptions fileOptions, {
    FetchOptions? options,
    required int retryAttempts,
    required StorageRetryController? retryController,
  }) {
    return _handleBinaryFileRequest(
      HttpMethod.post,
      url,
      data,
      fileOptions,
      options,
      retryAttempts,
      retryController,
    );
  }

  Future<dynamic> putBinaryFile(
    String url,
    Uint8List data,
    FileOptions fileOptions, {
    FetchOptions? options,
    required int retryAttempts,
    required StorageRetryController? retryController,
  }) {
    return _handleBinaryFileRequest(
      HttpMethod.put,
      url,
      data,
      fileOptions,
      options,
      retryAttempts,
      retryController,
    );
  }
}
