import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:mime/mime.dart';
import 'package:retry/retry.dart';
import 'package:storage_client/src/types.dart';

import 'file_io.dart' if (dart.library.js) './file_stub.dart';

Fetch storageFetch = Fetch();

class Fetch {
  final Client? httpClient;

  Fetch([this.httpClient]);

  bool _isSuccessStatusCode(int code) {
    return code >= 200 && code <= 299;
  }

  MediaType? _parseMediaType(String path) {
    final mime = lookupMimeType(path);
    return MediaType.parse(mime ?? 'application/octet-stream');
  }

  StorageException _handleError(dynamic error, StackTrace stack) {
    if (error is http.Response) {
      try {
        final data = json.decode(error.body) as Map<String, dynamic>;
        return StorageException.fromJson(data, '${error.statusCode}');
      } on FormatException catch (_) {
        return StorageException(
          error.body,
          statusCode: '${error.statusCode}',
        );
      }
    } else {
      return StorageException(
        error.toString(),
        statusCode: error.runtimeType.toString(),
      );
    }
  }

  Future<dynamic> _handleRequest(
    String method,
    String url,
    Map<String, dynamic>? body,
    FetchOptions? options,
  ) async {
    final headers = options?.headers ?? {};
    if (method != 'GET') {
      headers['Content-Type'] = 'application/json';
    }

    final request = http.Request(method, Uri.parse(url))
      ..headers.addAll(headers);
    if (body != null) {
      request.body = json.encode(body);
    }

    final http.StreamedResponse streamedResponse;
    if (httpClient != null) {
      streamedResponse = await httpClient!.send(request);
    } else {
      streamedResponse = await request.send();
    }
    return _handleResponse(streamedResponse, options);
  }

  Future<dynamic> _handleMultipartRequest(
    String method,
    String url,
    File file,
    FileOptions fileOptions,
    FetchOptions? options,
    int retryAttempts,
    StorageRetryController? retryController,
  ) async {
    final headers = options?.headers ?? {};
    final contentType = fileOptions.contentType != null
        ? MediaType.parse(fileOptions.contentType!)
        : _parseMediaType(file.path);
    final multipartFile = http.MultipartFile.fromBytes(
      '',
      file.readAsBytesSync(),
      filename: file.path,
      contentType: contentType,
    );
    final request = http.MultipartRequest(method, Uri.parse(url))
      ..headers.addAll(headers)
      ..files.add(multipartFile)
      ..fields['cacheControl'] = fileOptions.cacheControl
      ..headers['x-upsert'] = fileOptions.upsert.toString();

    final http.StreamedResponse streamedResponse;
    final r = RetryOptions(maxAttempts: (retryAttempts + 1));
    streamedResponse = await r.retry<http.StreamedResponse>(
      () async {
        if (httpClient != null) {
          return httpClient!.send(request);
        } else {
          return request.send();
        }
      },
      retryIf: (error) =>
          retryController?.cancelled != true &&
          (error is ClientException || error is TimeoutException),
    );

    return _handleResponse(streamedResponse, options);
  }

  Future<dynamic> _handleBinaryFileRequest(
    String method,
    String url,
    Uint8List data,
    FileOptions fileOptions,
    FetchOptions? options,
    int retryAttempts,
    StorageRetryController? retryController,
  ) async {
    final headers = options?.headers ?? {};
    final contentType = fileOptions.contentType != null
        ? MediaType.parse(fileOptions.contentType!)
        : _parseMediaType(url);
    final multipartFile = http.MultipartFile.fromBytes(
      '',
      data,
      // request fails with null filename so set it empty instead.
      filename: '',
      contentType: contentType,
    );
    final request = http.MultipartRequest(method, Uri.parse(url))
      ..headers.addAll(headers)
      ..files.add(multipartFile)
      ..fields['cacheControl'] = fileOptions.cacheControl
      ..headers['x-upsert'] = fileOptions.upsert.toString();

    final http.StreamedResponse streamedResponse;
    final r = RetryOptions(maxAttempts: (retryAttempts + 1));
    streamedResponse = await r.retry<http.StreamedResponse>(
      () async {
        if (httpClient != null) {
          return httpClient!.send(request);
        } else {
          return request.send();
        }
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
    if (_isSuccessStatusCode(response.statusCode)) {
      if (options?.noResolveJson == true) {
        return response.bodyBytes;
      } else {
        final jsonBody = json.decode(response.body);
        return jsonBody;
      }
    } else {
      throw _handleError(response, StackTrace.current);
    }
  }

  Future<dynamic> get(String url, {FetchOptions? options}) async {
    return _handleRequest('GET', url, null, options);
  }

  Future<dynamic> post(
    String url,
    Map<String, dynamic>? body, {
    FetchOptions? options,
  }) async {
    return _handleRequest('POST', url, body, options);
  }

  Future<dynamic> put(
    String url,
    Map<String, dynamic>? body, {
    FetchOptions? options,
  }) async {
    return _handleRequest('PUT', url, body, options);
  }

  Future<dynamic> delete(
    String url,
    Map<String, dynamic>? body, {
    FetchOptions? options,
  }) async {
    return _handleRequest('DELETE', url, body, options);
  }

  Future<dynamic> postFile(
    String url,
    File file,
    FileOptions fileOptions, {
    FetchOptions? options,
    required int retryAttempts,
    required StorageRetryController? retryController,
  }) async {
    return _handleMultipartRequest('POST', url, file, fileOptions, options,
        retryAttempts, retryController);
  }

  Future<dynamic> putFile(
    String url,
    File file,
    FileOptions fileOptions, {
    FetchOptions? options,
    required int retryAttempts,
    required StorageRetryController? retryController,
  }) async {
    return _handleMultipartRequest(
      'PUT',
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
  }) async {
    return _handleBinaryFileRequest(
      'POST',
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
  }) async {
    return _handleBinaryFileRequest(
      'PUT',
      url,
      data,
      fileOptions,
      options,
      retryAttempts,
      retryController,
    );
  }
}
