import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:supabase_common/supabase_common.dart';

/// The response of a successful [FunctionsClient.invoke] call.
class FunctionsResponse {
  const FunctionsResponse({
    this.data,
    required this.statusCode,
    this.headers = const {},
  });

  /// The data returned by the function. Type depends on the header
  /// `Content-Type`:
  /// - `application/json` and any `+json` type, such as
  ///   `application/problem+json`: the decoded JSON, or `null` for an empty
  ///   body
  /// - `application/octet-stream`: [Uint8List]
  /// - `text/event-stream`: [ByteStream]
  /// - anything else: [String]
  final dynamic data;

  /// HTTP status code of the response.
  final int statusCode;

  /// The headers of the response.
  ///
  /// The names are lowercased by the `package:http` clients, use
  /// `headers['content-type']` for example.
  final Map<String, String> headers;
}

/// The region an Edge Function is invoked in.
///
/// Pass one of the constants, or [FunctionsRegion.custom] for a region that
/// has no constant yet. [any] lets Supabase pick the region, which is also
/// what happens when no region is given.
///
/// ```dart
/// await functions.invoke('hello', region: FunctionsRegion.euWest1);
/// ```
extension type const FunctionsRegion._(String _value) implements Object {
  /// A region that has no constant, named the way Supabase names it, for
  /// example `'eu-west-1'`.
  const FunctionsRegion.custom(String value) : this._(value);

  /// The name Supabase gives the region, for example `'eu-west-1'`.
  String get value => _value;

  static const any = FunctionsRegion._('any');
  static const apNortheast1 = FunctionsRegion._('ap-northeast-1');
  static const apNortheast2 = FunctionsRegion._('ap-northeast-2');
  static const apSouth1 = FunctionsRegion._('ap-south-1');
  static const apSoutheast1 = FunctionsRegion._('ap-southeast-1');
  static const apSoutheast2 = FunctionsRegion._('ap-southeast-2');
  static const caCentral1 = FunctionsRegion._('ca-central-1');
  static const euCentral1 = FunctionsRegion._('eu-central-1');
  static const euWest1 = FunctionsRegion._('eu-west-1');
  static const euWest2 = FunctionsRegion._('eu-west-2');
  static const euWest3 = FunctionsRegion._('eu-west-3');
  static const saEast1 = FunctionsRegion._('sa-east-1');
  static const usEast1 = FunctionsRegion._('us-east-1');
  static const usWest1 = FunctionsRegion._('us-west-1');
  static const usWest2 = FunctionsRegion._('us-west-2');

  /// Every region that has a constant, [any] included.
  static const values = [
    any,
    apNortheast1,
    apNortheast2,
    apSouth1,
    apSoutheast1,
    apSoutheast2,
    caCentral1,
    euCentral1,
    euWest1,
    euWest2,
    euWest3,
    saEast1,
    usEast1,
    usWest1,
    usWest2,
  ];
}

/// Thrown when invoking an Edge Function fails.
///
/// The response body, or the originating error when no response or no body
/// was received, is available in [details].
///
/// Use pattern matching over the specific subtypes:
/// - [FunctionsFetchException]: The request could not be sent (e.g. network
///   failure).
/// - [FunctionsApiException]: The Edge Function answered with a non-2xx status
///   code.
/// - [FunctionsRelayException]: The Supabase relay returned an error
///   (`x-relay-error`).
sealed class FunctionsException extends SupabaseException {
  const FunctionsException({
    required String message,
    this.details,
    super.errorCode,
    super.requestId,
  }) : super(message);

  /// The response body, or the originating error when no response or no body
  /// was received.
  final dynamic details;

  @override
  String toString() =>
      '$exceptionName(message: $message, requestId: $requestId, '
      'details: $details)';
}

/// Thrown when the request to the Edge Function could not be sent, for example
/// because of a network or transport failure, or because the request body could
/// not be encoded.
///
/// The originating error is available in [cause], and in [details] for the
/// shape the sealed hierarchy shares.
class FunctionsFetchException extends FunctionsException
    with SupabaseTransportException {
  const FunctionsFetchException({
    this.cause,
    String? message,
  }) : super(
         message: message ?? 'Failed to send a request to the Edge Function',
         details: cause,
       );

  @override
  final Object? cause;

  @override
  String get exceptionName => 'FunctionsFetchException';

  @override
  String toString() =>
      '$exceptionName(message: $message, requestId: $requestId, '
      'details: $details)';
}

/// Thrown when the Edge Function responded with a non-2xx status code.
///
/// When the body is a JSON object, its `message` (or `error`) string becomes
/// the [message] and its `code` (or `error_code`) string the [errorCode].
/// Otherwise the [message] is the reason phrase of the response.
///
/// The decoded response body is available in [details], and the text it was
/// decoded from in [body]. When the body stopped arriving, [details] is the
/// error that cut it short and [body] is `null`.
class FunctionsApiException extends FunctionsException
    with SupabaseApiException {
  const FunctionsApiException({
    required this.statusCode,
    super.details,
    super.errorCode,
    super.requestId,
    this.headers = const {},
    this.body,
    String? message,
  }) : super(
         message: message ?? 'Edge Function returned a non-2xx status code',
       );

  @override
  final int statusCode;

  @override
  final Map<String, String> headers;

  @override
  final String? body;

  @override
  String get exceptionName => 'FunctionsApiException';

  @override
  String toString() =>
      '$exceptionName(message: $message, statusCode: $statusCode, '
      'errorCode: $errorCode, requestId: $requestId, details: $details)';
}

/// Thrown when the Supabase relay returns an error while invoking the Edge
/// Function, indicated by the `x-relay-error` response header.
///
/// The function itself may never have run.
class FunctionsRelayException extends FunctionsApiException {
  const FunctionsRelayException({
    required super.statusCode,
    super.details,
    super.errorCode,
    super.requestId,
    super.headers,
    super.body,
    String? message,
  }) : super(message: message ?? 'Relay error invoking the Edge Function');

  @override
  String get exceptionName => 'FunctionsRelayException';
}
