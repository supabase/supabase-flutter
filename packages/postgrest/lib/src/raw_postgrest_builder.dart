part of 'postgrest_builder.dart';

/// Needed as a wrapper around [PostgrestBuilder] to allow for the different return type of [withConverter] than in [ResponsePostgrestBuilder.withConverter].
class RawPostgrestBuilder<T, S, R> extends PostgrestBuilder<T, S, R> {
  RawPostgrestBuilder(PostgrestBuilder<T, S, R> builder)
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

  /// Very similar to [_copyWith], but allows changing the generics, therefore [_converter] is omitted
  RawPostgrestBuilder<O, P, Q> _copyWithType<O, P, Q>({
    Uri? url,
    Headers? headers,
    String? schema,
    String? method,
    Object? body,
    Client? httpClient,
    YAJsonIsolate? isolate,
    CountOption? count,
    bool? maybeSingle,
  }) {
    return RawPostgrestBuilder<O, P, Q>(PostgrestBuilder(
      url: url ?? _url,
      headers: headers ?? _headers,
      schema: schema ?? _schema,
      method: method ?? _method,
      body: body ?? _body,
      httpClient: httpClient ?? _httpClient,
      isolate: isolate ?? _isolate,
      count: count ?? _count,
      maybeSingle: maybeSingle ?? _maybeSingle,
    ));
  }

  /// Converts any response that comes from the server into a type-safe response.
  ///
  /// ```dart
  /// List<User> users = await postgrest
  ///     .from('users')
  ///     .select()
  ///     .withConverter(
  ///       (users) => users.map(User.fromJson).toList(),
  ///     );
  /// ```
  PostgrestBuilder<U, U, R> withConverter<U>(
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
