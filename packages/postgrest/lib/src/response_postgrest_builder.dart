part of 'postgrest_builder.dart';

/// Needed as a wrapper around [PostgrestBuilder] to allow for the different return type of [withConverter] than in [RawPostgrestBuilder.withConverter].
class ResponsePostgrestBuilder<T, S, R> extends PostgrestBuilder<T, S, R> {
  ResponsePostgrestBuilder(PostgrestBuilder<T, S, R> builder)
      : super(
          url: builder._url,
          method: builder._method,
          headers: builder._headers,
          schema: builder._schema,
          body: builder._body,
          httpClient: builder._httpClient,
          count: builder._count,
          isolate: builder._isolate,
          maybeSingle: builder._maybeSingle,
          converter: builder._converter,
        );

  /// Converts any response that comes from the server into a type-safe response.
  ///
  /// ```dart
  /// final res = await postgrest
  ///     .from('users')
  ///     .select()
  ///     .count(CountOption.exact)
  ///     .withConverter(
  ///       (users) => users.map(User.fromJson).toList(),
  ///     );
  /// List<User> users = res.data;
  /// int count = res.count;
  /// ```
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
      count: _count,
      maybeSingle: _maybeSingle,
      converter: converter,
    );
  }
}
