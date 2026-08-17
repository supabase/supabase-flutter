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
  /// Human readable error message associated with the error.
  final String message;

  /// Identifier for the error, for example `weak_password` (auth), `PGRST116`
  /// (postgrest) or `NoSuchKey` (storage).
  ///
  /// `null` when neither the service nor the client named the failure.
  final String? errorCode;

  const SupabaseException(this.message, {this.errorCode});

  @override
  String toString() => '$runtimeType(message: $message, errorCode: $errorCode)';
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
      'errorCode: $errorCode)';
}
