/// Base class for the exceptions thrown by the Supabase client packages.
///
/// A plain [SupabaseException] is a failure the client raised on its own,
/// without or before a request, such as a missing session or an unparsable
/// JWT. A failure a service reported is a [SupabaseApiException].
///
/// The auth, postgrest, storage and functions exceptions all extend this:
///
/// ```dart
/// try {
///   await supabase.from('countries').select();
/// } on SupabaseException catch (error) {
///   print(error.message);
/// }
/// ```
///
/// `RealtimeSubscribeException` and `IcebergException` are not part of this
/// hierarchy.
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

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode, '
      'errorCode: $errorCode, requestId: $requestId)';
}
