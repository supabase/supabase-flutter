/// The HTTP methods the Supabase client packages send requests with.
enum HttpMethod {
  get,
  head,
  post,
  put,
  patch,
  delete;

  /// The method as it appears on the wire, for example `GET`.
  String get value => name.toUpperCase();
}
