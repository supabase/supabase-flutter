/// Base class for the exceptions thrown by the Supabase client packages.
///
/// A plain [SupabaseException] is a failure the client raised on its own,
/// without or before a request, such as a missing session or an unparsable
/// JWT. A failure a service reported is a [SupabaseApiException], and a
/// request that never received a response is a [SupabaseTransportException].
///
/// The auth, postgrest, storage, functions, realtime and iceberg exceptions
/// all extend this:
///
/// ```dart
/// try {
///   await supabase.from('countries').select();
/// } on SupabaseException catch (error) {
///   print(error.message);
/// }
/// ```
abstract class SupabaseException implements Exception {
  const SupabaseException(this.message, {this.errorCode, this.requestId});

  /// Human readable error message associated with the error.
  final String message;

  /// Identifier for the error, for example `weak_password` (auth), `PGRST116`
  /// (postgrest) or `NoSuchKey` (storage).
  ///
  /// `null` when neither the service nor the client named the failure.
  final String? errorCode;

  /// The identifier the Supabase gateway assigned to the request, read from
  /// the `sb-request-id` response header.
  ///
  /// Quote it in a support thread or paste it into the log explorer of the
  /// dashboard to find the server side logs of the failed request.
  ///
  /// `null` when no response was received, or when the response carried no
  /// request id, as one from a self-hosted stack without a gateway does.
  final String? requestId;

  @override
  String toString() =>
      '$runtimeType(message: $message, errorCode: $errorCode, '
      'requestId: $requestId)';
}

/// Mixed into the exceptions that report a response from a Supabase service.
///
/// Catch it to handle a failure any service answered with:
///
/// ```dart
/// try {
///   await supabase.from('countries').select();
/// } on SupabaseApiException catch (error) {
///   print('${error.statusCode}: ${error.message}');
/// }
/// ```
mixin SupabaseApiException on SupabaseException {
  /// HTTP status code of the response that caused the error.
  int get statusCode;

  /// The headers of the response that caused the error.
  ///
  /// Empty when the exception was built without a response, as a test or a
  /// client-side check does.
  Map<String, String> get headers;

  /// The body of the response that caused the error, as text.
  ///
  /// `null` when the exception was built without a response. The body is kept
  /// as the service sent it, so a decoded form of it, where the exception
  /// offers one, is found in a field of its own.
  String? get body;

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode, '
      'errorCode: $errorCode, requestId: $requestId)';
}

/// Mixed into the exceptions thrown when a request never received a response,
/// because the connection failed or the request timed out.
///
/// The request may still have reached the service, so the outcome of an
/// operation that is not idempotent is unknown. Catch it to handle an offline
/// client for every service at once:
///
/// ```dart
/// try {
///   await supabase.from('countries').select();
/// } on SupabaseTransportException catch (error) {
///   print('No response: ${error.cause}');
/// }
/// ```
mixin SupabaseTransportException on SupabaseException {
  /// The error that failed the request, such as a `ClientException` from the
  /// HTTP client or a `TimeoutException`.
  ///
  /// `null` when the exception was built without one.
  Object? get cause;

  @override
  String toString() =>
      '$runtimeType(message: $message, errorCode: $errorCode, '
      'requestId: $requestId, cause: $cause)';
}
