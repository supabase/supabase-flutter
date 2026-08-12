/// Base class for the exceptions thrown by the Supabase client packages.
///
/// A plain [SupabaseException] is a failure the client raised on its own,
/// without or before a request: a missing session, an unparsable JWT, a
/// redirect url without an access token. It carries a human readable [message]
/// and, when the client can name the failure, an [errorCode].
///
/// A failure reported by a Supabase service is a [SupabaseApiException] and
/// additionally carries the response's HTTP [SupabaseApiException.statusCode],
/// so the layer an exception came from is visible from its type alone.
///
/// The auth, postgrest, storage and functions exceptions all extend this, so
/// one catch handles a failure from any of them without knowing which one
/// produced it:
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
/// hierarchy; they keep shapes of their own.
abstract class SupabaseException implements Exception {
  /// Human readable error message associated with the error.
  final String message;

  /// Identifier for the error, for example `weak_password` (auth), `PGRST116`
  /// (postgrest) or `not_found` (storage).
  ///
  /// `null` when neither the service nor the client named the failure.
  final String? errorCode;

  const SupabaseException(this.message, {this.errorCode});

  @override
  String toString() => '$runtimeType(message: $message, errorCode: $errorCode)';
}

/// Mixed into the exceptions that report a response from a Supabase service,
/// as opposed to a failure the client raised on its own.
///
/// Catch it to handle any failure that a service answered with, whichever
/// service that was:
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
      'errorCode: $errorCode)';
}
