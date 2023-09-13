part of 'postgrest_builder.dart';

class PostgrestRpcBuilder extends RawPostgrestBuilder {
  PostgrestRpcBuilder(
    String url, {
    Map<String, String>? headers,
    String? schema,
    Client? httpClient,
    required YAJsonIsolate isolate,
  }) : super(
          PostgrestBuilder(
            url: Uri.parse(url),
            headers: headers ?? {},
            schema: schema,
            httpClient: httpClient,
            isolate: isolate,
          ),
        );

  /// Performs stored procedures on the database.
  PostgrestFilterBuilder<T> rpc<T>([
    Object? params,
  ]) {
    return PostgrestFilterBuilder(_copyWithType(
      method: METHOD_POST,
      body: params,
    ));
  }
}
