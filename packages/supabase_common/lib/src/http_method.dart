/// An HTTP request method.
enum HttpMethod {
  /// Retrieves a resource without side effects.
  get,

  /// Like [get], but without a response body.
  head,

  /// Creates a resource or submits data for processing.
  post,

  /// Replaces a resource in its entirety.
  put,

  /// Applies a partial update to a resource.
  patch,

  /// Deletes a resource.
  delete;

  /// The uppercase method name sent on the wire, for example `'GET'`.
  String get value => name.toUpperCase();
}
