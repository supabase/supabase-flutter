part of 'postgrest_builder.dart';

class ResponsePostgrestBuilder<T, S, R> extends PostgrestBuilder<T, S, R> {
  ResponsePostgrestBuilder(PostgrestBuilder<T, S, R> builder)
      : super(
          url: builder._url,
          method: builder._method,
          headers: builder._headers,
          schema: builder._schema,
          body: builder._body,
          httpClient: builder._httpClient,
          options: builder._options,
          isolate: builder._isolate,
          maybeSingle: builder._maybeSingle,
          converter: builder._converter,
        );

  PostgrestBuilder<PostgrestResponse<U>, U, R> withConverter<U>(
      PostgrestConverter<U, R> converter) {
    return PostgrestBuilder(
      url: _url,
      headers: _headers,
      schema: _schema,
      method: _method,
      body: _body,
      isolate: _isolate,
      httpClient: _httpClient,
      options: _options,
      maybeSingle: _maybeSingle,
      converter: converter,
    );
  }
}
