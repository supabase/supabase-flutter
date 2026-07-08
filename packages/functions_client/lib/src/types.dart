import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';

enum HttpMethod {
  get,
  post,
  put,
  delete,
  patch,
}

class FunctionResponse {
  /// The data returned by the function. Type depends on the header `Content-Type`:
  /// - 'text/plain': [String]
  /// - 'octet/stream': [Uint8List]
  /// - 'application/json': dynamic ([jsonDecode] is used)
  /// - 'text/event-stream': [ByteStream]
  final dynamic data;
  final int status;

  const FunctionResponse({
    this.data,
    required this.status,
  });
}

class FunctionException implements Exception {
  final int status;
  final dynamic details;
  final String? reasonPhrase;

  const FunctionException({
    required this.status,
    this.details,
    this.reasonPhrase,
  });

  @override
  String toString() =>
      '$runtimeType(status: $status, details: $details, reasonPhrase: $reasonPhrase)';
}

/// Thrown when the request to the Edge Function could not be sent, for example
/// because of a network or transport failure, before any response was received.
///
/// The originating error is available in [details] and [status] is `0` since no
/// response reached the client.
class FunctionsFetchError extends FunctionException {
  const FunctionsFetchError({
    super.details,
    super.reasonPhrase,
  }) : super(status: 0);
}

/// Thrown when the Supabase relay returns an error while invoking the Edge
/// Function, indicated by the `x-relay-error` response header.
class FunctionsRelayError extends FunctionException {
  const FunctionsRelayError({
    required super.status,
    super.details,
    super.reasonPhrase,
  });
}

/// Thrown when the Edge Function itself responds with a non-2xx status code.
class FunctionsHttpError extends FunctionException {
  const FunctionsHttpError({
    required super.status,
    super.details,
    super.reasonPhrase,
  });
}
