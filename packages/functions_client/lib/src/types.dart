import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:supabase_common/supabase_common.dart';

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

/// Thrown when invoking an Edge Function fails.
///
/// The response body, or the originating error when no response was received,
/// is available in [details].
class FunctionException extends SupabaseException {
  final dynamic details;

  const FunctionException({
    required String message,
    super.statusCode,
    this.details,
  }) : super(message);

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode, '
      'details: $details)';
}

/// Thrown when the request to the Edge Function could not be sent, for example
/// because of a network or transport failure, before any response was received.
///
/// The originating error is available in [details] and [statusCode] is `null`
/// since no response reached the client.
class FunctionsFetchException extends FunctionException {
  const FunctionsFetchException({
    super.details,
    String? message,
  }) : super(
         message: message ?? 'Failed to send a request to the Edge Function',
       );
}

/// Thrown when the Supabase relay returns an error while invoking the Edge
/// Function, indicated by the `x-relay-error` response header.
class FunctionsRelayException extends FunctionException {
  const FunctionsRelayException({
    required super.statusCode,
    super.details,
    String? message,
  }) : super(message: message ?? 'Relay error invoking the Edge Function');
}

/// Thrown when the Edge Function itself responds with a non-2xx status code.
class FunctionsHttpException extends FunctionException {
  const FunctionsHttpException({
    required super.statusCode,
    super.details,
    String? message,
  }) : super(
         message: message ?? 'Edge Function returned a non-2xx status code',
       );
}
