/// A media type more than one Supabase client sends or reads in the
/// `Content-Type` and `Accept` headers.
enum HttpMediaType {
  /// A JSON document.
  json('application/json'),

  /// Raw bytes of no particular type.
  octetStream('application/octet-stream');

  const HttpMediaType(this.value);

  /// The media type sent on the wire, for example `'application/json'`.
  final String value;
}
