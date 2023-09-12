part of 'postgrest_builder.dart';

class PostgrestRpcBuilder extends PostgrestBuilder {
  PostgrestRpcBuilder(
    String url, {
    Map<String, String>? headers,
    String? schema,
    Client? httpClient,
    required YAJsonIsolate isolate,
  }) : super(
          url: Uri.parse(url),
          headers: headers ?? {},
          schema: schema,
          httpClient: httpClient,
          isolate: isolate,
        );

  /// Performs stored procedures on the database.
  PostgrestFilterBuilder rpc([
    Object? params,
  ]) {
    return PostgrestFilterBuilder(_copyWith(
      method: METHOD_POST,
      body: params,
    ));
  }
}
