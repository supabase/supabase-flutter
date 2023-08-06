part of 'postgrest_builder.dart';

class PostgrestRpcBuilder extends PostgrestBuilder {
  PostgrestRpcBuilder(
    String url, {
    Map<String, String>? headers,
    String? schema,
    Client? httpClient,
    FetchOptions? options,
    required YAJsonIsolate isolate,
  }) : super(
          url: Uri.parse(url),
          headers: headers ?? {},
          schema: schema,
          httpClient: httpClient,
          options: options,
          isolate: isolate,
        );

  /// Performs stored procedures on the database.
  PostgrestFilterBuilder rpc([
    dynamic params,
    FetchOptions options = const FetchOptions(),
  ]) {
    return PostgrestFilterBuilder(copyWith(
      method: METHOD_POST,
      body: params,
      options: options.ensureNotHead(),
    ));
  }
}
