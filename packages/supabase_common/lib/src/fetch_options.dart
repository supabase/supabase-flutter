/// Options for a single HTTP request made by the Supabase client packages.
class FetchOptions {
  /// Extra headers to send with the request.
  ///
  /// Defaults to an empty, unmodifiable map when none are provided.
  final Map<String, String> headers;

  /// Whether to skip JSON decoding and return the raw response bytes.
  ///
  /// Defaults to `false`, meaning the response body is decoded as JSON.
  final bool noResolveJson;

  /// Creates a set of request options.
  ///
  /// [headers] are the extra headers to send, defaulting to an empty map.
  /// [noResolveJson] toggles returning the raw response bytes instead of
  /// decoded JSON, defaulting to `false`.
  const FetchOptions(
    Map<String, String>? headers, {
    bool? noResolveJson,
  }) : headers = headers ?? const {},
       noResolveJson = noResolveJson ?? false;
}
