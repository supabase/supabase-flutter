// GENERATED CODE - DO NOT MODIFY BY HAND.
// Generated from openapi/FunctionsService.openapi.json by bin/generate.dart.
// ignore_for_file: prefer_final_locals, unnecessary_brace_in_string_interps

import 'package:http/http.dart' as http;

import '../runtime.dart';

class FunctionsErrorResponseContent {
  FunctionsErrorResponseContent({
    this.message,
  });

  final String? message;

  factory FunctionsErrorResponseContent.fromJson(Map<String, dynamic> json) =>
      FunctionsErrorResponseContent(
        message: json['message'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (message != null) 'message': message,
      };
}

/// Generated HTTP client. Every operation goes through the
/// hand-written [ApiClient] runtime for headers and transport.
class FunctionsApi {
  FunctionsApi(this._client);

  final ApiClient _client;

  Future<StreamedApiResponse> invokeFunctionDelete(
      {required String functionName,
      String? xRegion,
      required Stream<List<int>> body,
      int? contentLength}) async {
    final uri = _client.uri('/functions/v1/${functionName}');
    final headers = await _client.headers({
      if (xRegion != null) 'x-region': xRegion,
    });
    final request = streamingRequest('DELETE', uri,
        body: body, contentLength: contentLength);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      await readOrThrow(streamed);
    }
    return StreamedApiResponse(
      statusCode: streamed.statusCode,
      headers: streamed.headers,
      stream: streamed.stream,
    );
  }

  Future<StreamedApiResponse> invokeFunctionGet(
      {required String functionName, String? xRegion}) async {
    final uri = _client.uri('/functions/v1/${functionName}');
    final headers = await _client.headers({
      if (xRegion != null) 'x-region': xRegion,
    });
    final request = http.Request('GET', uri);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      await readOrThrow(streamed);
    }
    return StreamedApiResponse(
      statusCode: streamed.statusCode,
      headers: streamed.headers,
      stream: streamed.stream,
    );
  }

  Future<StreamedApiResponse> invokeFunctionPatch(
      {required String functionName,
      String? xRegion,
      required Stream<List<int>> body,
      int? contentLength}) async {
    final uri = _client.uri('/functions/v1/${functionName}');
    final headers = await _client.headers({
      if (xRegion != null) 'x-region': xRegion,
    });
    final request = streamingRequest('PATCH', uri,
        body: body, contentLength: contentLength);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      await readOrThrow(streamed);
    }
    return StreamedApiResponse(
      statusCode: streamed.statusCode,
      headers: streamed.headers,
      stream: streamed.stream,
    );
  }

  Future<StreamedApiResponse> invokeFunctionPost(
      {required String functionName,
      String? xRegion,
      required Stream<List<int>> body,
      int? contentLength}) async {
    final uri = _client.uri('/functions/v1/${functionName}');
    final headers = await _client.headers({
      if (xRegion != null) 'x-region': xRegion,
    });
    final request =
        streamingRequest('POST', uri, body: body, contentLength: contentLength);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      await readOrThrow(streamed);
    }
    return StreamedApiResponse(
      statusCode: streamed.statusCode,
      headers: streamed.headers,
      stream: streamed.stream,
    );
  }

  Future<StreamedApiResponse> invokeFunctionPut(
      {required String functionName,
      String? xRegion,
      required Stream<List<int>> body,
      int? contentLength}) async {
    final uri = _client.uri('/functions/v1/${functionName}');
    final headers = await _client.headers({
      if (xRegion != null) 'x-region': xRegion,
    });
    final request =
        streamingRequest('PUT', uri, body: body, contentLength: contentLength);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      await readOrThrow(streamed);
    }
    return StreamedApiResponse(
      statusCode: streamed.statusCode,
      headers: streamed.headers,
      stream: streamed.stream,
    );
  }
}
