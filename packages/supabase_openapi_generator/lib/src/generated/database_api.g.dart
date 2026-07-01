// GENERATED CODE - DO NOT MODIFY BY HAND.
// Generated from openapi/DatabaseService.openapi.json by bin/generate.dart.
// ignore_for_file: prefer_final_locals, unnecessary_brace_in_string_interps

import 'package:http/http.dart' as http;

import '../runtime.dart';

class DatabaseErrorResponseContent {
  DatabaseErrorResponseContent({
    this.code,
    this.message,
    this.details,
    this.hint,
  });

  final String? code;
  final String? message;
  final String? details;
  final String? hint;

  factory DatabaseErrorResponseContent.fromJson(Map<String, dynamic> json) =>
      DatabaseErrorResponseContent(
        code: json['code'] as String?,
        message: json['message'] as String?,
        details: json['details'] as String?,
        hint: json['hint'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (code != null) 'code': code,
        if (message != null) 'message': message,
        if (details != null) 'details': details,
        if (hint != null) 'hint': hint,
      };
}

/// Generated HTTP client. Every operation goes through the
/// hand-written [ApiClient] runtime for headers and transport.
class DatabaseApi {
  DatabaseApi(this._client);

  final ApiClient _client;

  Future<StreamedApiResponse> callRpcGet(
      {required String functionName,
      String? acceptProfile,
      String? select,
      String? args}) async {
    final uri = _client.uri('/rpc/${Uri.encodeComponent(functionName)}', {
      'select': select,
      'args': args,
    });
    final headers = await _client.headers({
      if (acceptProfile != null) 'Accept-Profile': acceptProfile,
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

  Future<StreamedApiResponse> callRpcPost(
      {required String functionName,
      String? contentProfile,
      String? prefer,
      String? select,
      required Stream<List<int>> body,
      int? contentLength}) async {
    final uri = _client.uri('/rpc/${Uri.encodeComponent(functionName)}', {
      'select': select,
    });
    final headers = await _client.headers({
      if (contentProfile != null) 'Content-Profile': contentProfile,
      if (prefer != null) 'Prefer': prefer,
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

  Future<StreamedApiResponse> deleteRows(
      {required String table,
      String? contentProfile,
      String? prefer,
      String? select,
      String? filters}) async {
    final uri = _client.uri('/${Uri.encodeComponent(table)}', {
      'select': select,
      'filters': filters,
    });
    final headers = await _client.headers({
      if (contentProfile != null) 'Content-Profile': contentProfile,
      if (prefer != null) 'Prefer': prefer,
    });
    final request = http.Request('DELETE', uri);
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

  Future<StreamedApiResponse> selectRows(
      {required String table,
      String? accept,
      String? acceptProfile,
      String? prefer,
      String? range,
      String? rangeUnit,
      String? select,
      String? order,
      int? limit,
      int? offset,
      String? filters}) async {
    final uri = _client.uri('/${Uri.encodeComponent(table)}', {
      'select': select,
      'order': order,
      'limit': limit?.toString(),
      'offset': offset?.toString(),
      'filters': filters,
    });
    final headers = await _client.headers({
      if (accept != null) 'Accept': accept,
      if (acceptProfile != null) 'Accept-Profile': acceptProfile,
      if (prefer != null) 'Prefer': prefer,
      if (range != null) 'Range': range,
      if (rangeUnit != null) 'Range-Unit': rangeUnit,
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

  Future<StreamedApiResponse> updateRows(
      {required String table,
      String? contentProfile,
      String? prefer,
      String? select,
      String? filters,
      required Stream<List<int>> body,
      int? contentLength}) async {
    final uri = _client.uri('/${Uri.encodeComponent(table)}', {
      'select': select,
      'filters': filters,
    });
    final headers = await _client.headers({
      if (contentProfile != null) 'Content-Profile': contentProfile,
      if (prefer != null) 'Prefer': prefer,
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

  Future<StreamedApiResponse> insertRows(
      {required String table,
      String? contentProfile,
      String? prefer,
      String? select,
      String? columns,
      required Stream<List<int>> body,
      int? contentLength}) async {
    final uri = _client.uri('/${Uri.encodeComponent(table)}', {
      'select': select,
      'columns': columns,
    });
    final headers = await _client.headers({
      if (contentProfile != null) 'Content-Profile': contentProfile,
      if (prefer != null) 'Prefer': prefer,
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

  Future<StreamedApiResponse> upsertRows(
      {required String table,
      String? contentProfile,
      String? prefer,
      String? select,
      String? onConflict,
      String? filters,
      required Stream<List<int>> body,
      int? contentLength}) async {
    final uri = _client.uri('/${Uri.encodeComponent(table)}', {
      'select': select,
      'on_conflict': onConflict,
      'filters': filters,
    });
    final headers = await _client.headers({
      if (contentProfile != null) 'Content-Profile': contentProfile,
      if (prefer != null) 'Prefer': prefer,
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
