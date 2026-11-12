/// The media types more than one Supabase client sends or reads in the
/// `Content-Type` and `Accept` headers.
abstract final class HttpMediaType {
  /// A JSON document.
  static const json = 'application/json';

  /// Raw bytes of no particular type.
  static const octetStream = 'application/octet-stream';
}
