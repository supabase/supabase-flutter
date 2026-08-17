import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:supabase_common/supabase_common.dart';

class FunctionResponse {
  /// The data returned by the function. Type depends on the header
  /// `Content-Type`:
  /// - 'text/plain': [String]
  /// - 'application/octet-stream': [Uint8List]
  /// - 'application/json': dynamic ([jsonDecode] is used)
  /// - 'text/event-stream': [ByteStream]
  final dynamic data;

  /// HTTP status code of the response.
  final int statusCode;

  const FunctionResponse({
    this.data,
    required this.statusCode,
  });
}

/// Thrown when invoking an Edge Function fails.
///
/// The response body, or the originating error when no response was received,
/// is available in [details].
///
/// Use pattern matching over the specific subtypes:
/// - [FunctionsFetchException]: The request could not be sent (e.g. network
///   failure).
/// - [FunctionsApiException]: The Edge Function answered with a non-2xx status
///   code.
/// - [FunctionsRelayException]: The Supabase relay returned an error
///   (`x-relay-error`).
sealed class FunctionException extends SupabaseException {
  final dynamic details;

  const FunctionException({
    required String message,
    this.details,
  }) : super(message);

  @override
  String toString() => '$runtimeType(message: $message, details: $details)';
}

/// Thrown when the request to the Edge Function could not be sent, for example
/// because of a network or transport failure.
///
/// The originating error is available in [details].
class FunctionsFetchException extends FunctionException {
  const FunctionsFetchException({
    super.details,
    String? message,
  }) : super(
         message: message ?? 'Failed to send a request to the Edge Function',
       );
}

/// Thrown when the Edge Function responded with a non-2xx status code.
///
/// The response body is available in [details].
class FunctionsApiException extends FunctionException
    with SupabaseApiException {
  @override
  final int statusCode;

  const FunctionsApiException({
    required this.statusCode,
    super.details,
    String? message,
  }) : super(
         message: message ?? 'Edge Function returned a non-2xx status code',
       );

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode, '
      'details: $details)';
}

/// Thrown when the Supabase relay returns an error while invoking the Edge
/// Function, indicated by the `x-relay-error` response header.
///
/// The function itself may never have run.
class FunctionsRelayException extends FunctionsApiException {
  const FunctionsRelayException({
    required super.statusCode,
    super.details,
    String? message,
  }) : super(message: message ?? 'Relay error invoking the Edge Function');
}
