/// The names of the HTTP headers more than one Supabase client sends or reads.
abstract final class HttpHeader {
  /// The media types the client accepts in the response.
  static const accept = 'Accept';

  /// The schema PostgREST reads from.
  static const acceptProfile = 'Accept-Profile';

  /// The project API key the gateway authenticates every request with.
  static const apiKey = 'apikey';

  /// The bearer token that identifies the user making the request.
  static const authorization = 'Authorization';

  /// The name and version of the client library, built by
  /// `buildClientInfoHeader`.
  static const clientInfo = 'X-Client-Info';

  /// The schema PostgREST writes to.
  static const contentProfile = 'Content-Profile';

  /// The media type of the request body.
  static const contentType = 'Content-Type';

  /// The preferences PostgREST applies to the request, such as how many rows
  /// to return or how to resolve a conflict.
  static const prefer = 'Prefer';

  /// How long the server asks the client to wait before repeating a request.
  static const retryAfter = 'Retry-After';
}
