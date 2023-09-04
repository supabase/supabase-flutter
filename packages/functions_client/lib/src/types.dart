enum HttpMethod {
  get,
  post,
  put,
  delete,
  patch,
}

class FunctionResponse {
  final dynamic data;
  final int? status;

  FunctionResponse({
    this.data,
    this.status,
  });
}
