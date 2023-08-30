enum ResponseType {
  json,
  text,
  arraybuffer,
  blob,
}

enum HttpMethod {
  get,
  post,
  put,
  delete,
  patch,
}

class FunctionInvokeOptions {
  final Map<String, String>? headers;
  final Object? body;
  final ResponseType? responseType;

  FunctionInvokeOptions({
    this.headers,
    this.body,
    this.responseType,
  });
}

class FunctionResponse {
  final dynamic data;
  final int? status;

  FunctionResponse({
    this.data,
    this.status,
  });
}
