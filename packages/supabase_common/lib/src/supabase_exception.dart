/// Base class for the exceptions thrown by the Supabase client packages.
///
/// Subclasses carry a human readable [message], the HTTP [statusCode] of the
/// response that caused the failure when there was one, and the service
/// specific [errorCode] when the service reported one.
///
/// The auth, postgrest, storage and functions exceptions extend this, so one
/// catch handles a failure from any of them without knowing which one produced
/// it:
///
/// ```dart
/// try {
///   await supabase.from('countries').select();
/// } on SupabaseException catch (error) {
///   print('${error.statusCode}: ${error.message}');
/// }
/// ```
///
/// `RealtimeSubscribeException` and `IcebergException` are not part of this
/// hierarchy; they keep shapes of their own.
abstract class SupabaseException implements Exception {
  /// Human readable error message associated with the error.
  final String message;

  /// HTTP status code of the response that caused the error.
  ///
  /// `null` when the error happened before a response was received, for
  /// example on a network failure, or when it was raised by the client itself.
  final int? statusCode;

  /// Service specific identifier for the error, for example `weak_password`
  /// (auth), `PGRST116` (postgrest) or `not_found` (storage).
  ///
  /// `null` when the service did not report one, which is also the case for
  /// errors raised by the client before a response was received.
  final String? errorCode;

  const SupabaseException(
    this.message, {
    this.statusCode,
    this.errorCode,
  });

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode, '
      'errorCode: $errorCode)';
}
