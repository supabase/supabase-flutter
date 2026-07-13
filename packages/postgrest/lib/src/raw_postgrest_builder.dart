part of 'postgrest_builder.dart';

/// Needed as a wrapper around [PostgrestBuilder] to allow for the different return type of [withConverter] than in [ResponsePostgrestBuilder.withConverter].
class RawPostgrestBuilder<T, S, R> extends PostgrestBuilder<T, S, R> {
  // ignore: use_super_parameters, builder is also read for its converter
  RawPostgrestBuilder(PostgrestBuilder<T, S, R> builder)
    : super._copy(builder, converter: builder._converter);

  /// Very similar to [_copyWith], but allows changing the generics, therefore [_converter] is omitted
  RawPostgrestBuilder<O, P, Q> _copyWithType<O, P, Q>({
    Uri? url,
    // ignore: avoid-unnecessary-nullable-parameters
    Headers? headers,
    String? schema,
    HttpMethod? method,
    Object? body,
    Client? httpClient,
    YAJsonIsolate? isolate,
    CountOption? count,
    bool? maybeSingle,
  }) {
    return RawPostgrestBuilder(
      PostgrestBuilder<O, P, Q>._copy(
        this,
        converter: null,
        url: url,
        headers: headers,
        schema: schema,
        method: method,
        body: body,
        httpClient: httpClient,
        isolate: isolate,
        count: count,
        maybeSingle: maybeSingle,
      ),
    );
  }

  @override
  RawPostgrestBuilder<T, S, R> setHeader(String key, String value) {
    return PostgrestFilterBuilder(
      _copyWithType(headers: {..._headers, key: value}),
    );
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
    PostgrestConverter<U, R> converter,
  ) {
    return PostgrestBuilder<U, U, R>._copy(this, converter: converter);
  }
}
