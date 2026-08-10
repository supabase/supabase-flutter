enum HttpMethod {
  get,
  head,
  post,
  put,
  patch,
  delete;

  String get value => name.toUpperCase();
}
