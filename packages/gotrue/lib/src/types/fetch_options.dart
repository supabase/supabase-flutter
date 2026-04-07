class FetchOptions {
  final Map<String, String> headers;
  final bool noResolveJson;

  const FetchOptions(
    Map<String, String>? headers, {
    bool? noResolveJson,
  })  : headers = headers ?? const {},
        noResolveJson = noResolveJson ?? false;
}

class GotrueRequestOptions extends FetchOptions {
  final String? jwt;
  final String? redirectTo;
  final Map<String, dynamic>? body;
  final Map<String, String>? query;

  GotrueRequestOptions({
    this.jwt,
    this.redirectTo,
    this.body,
    this.query,
    required Map<String, String> headers,
    bool? noResolveJson,
  }) : super(headers, noResolveJson: noResolveJson);
}
