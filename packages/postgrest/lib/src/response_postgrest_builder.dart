part of 'postgrest_builder.dart';

/// Needed as a wrapper around [PostgrestBuilder] to allow for the different return type of [withConverter] than in [RawPostgrestBuilder.withConverter].
class ResponsePostgrestBuilder<T, S, R> extends PostgrestBuilder<T, S, R> {
  // ignore: use_super_parameters, builder is also read for its converter
  ResponsePostgrestBuilder(PostgrestBuilder<T, S, R> builder)
    : super._copy(builder, converter: builder._converter);

  @override
  ResponsePostgrestBuilder<T, S, R> setHeader(String key, String value) {
    return ResponsePostgrestBuilder(
      _copyWith(headers: {..._headers, key: value}),
    );
  }

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
    PostgrestConverter<U, R> converter,
  ) {
    return PostgrestBuilder<PostgrestResponse<U>, U, R>._copy(
      this,
      converter: converter,
    );
  }
}
