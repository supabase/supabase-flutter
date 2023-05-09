part of 'postgrest_builder.dart';

class PostgrestTransformBuilder<T> extends PostgrestBuilder<T, T> {
  PostgrestTransformBuilder(PostgrestBuilder<T, T> builder)
      : super(
          url: builder._url,
          method: builder._method,
          headers: builder._headers,
          schema: builder._schema,
          body: builder._body,
          httpClient: builder._httpClient,
          options: builder._options,
          isolate: builder._isolate,
        );

  /// Performs horizontal filtering with SELECT.
  ///
  /// ```dart
  /// postgrest.from('users').insert().select<PostgrestList>('id, messages');
  /// ```
  /// ```dart
  /// postgrest.from('users').insert().select<PostgrestListResponse>('id, messages', FetchOptions(count: CountOption.exact));
  /// ```
  ///
  /// By setting [FetchOptions.count] to non null or [FetchOptions.forceResponse] to `true`, the return type is [PostgrestResponse<T>]. Otherwise it's `T` directly.
  ///
  /// The type specification for [R] is optional and enhances the type safety of the return value. But use with care as a wrong type specification will result in a runtime error.
  ///
  /// `T` is
  /// - [List<Map<String, dynamic>>] for queries without `.single()` or `maybeSingle()`
  /// - [Map<String, dynamic>] for queries with `.single()`
  /// - [Map<String, dynamic>?] for queries with `.maybeSingle()`
  ///
  /// Allowed types for [R] are:
  /// - [List<Map<String, dynamic>>]
  /// - [Map<String, dynamic>]
  /// - [Map<String, dynamic>?]
  /// - [PostgrestResponse<List<Map<String, dynamic>>>]
  /// - [PostgrestResponse<Map<String, dynamic>>]
  /// - [PostgrestResponse<Map<String, dynamic>?>]
  /// - [PostgrestResponse]
  ///
  /// There are optional typedefs for [R]: [PostgrestMap], [PostgrestList], [PostgrestMapResponse], [PostgrestListResponse]
  PostgrestTransformBuilder<R> select<R>([String columns = '*']) {
    _assertCorrectGeneric(R);
    // Remove whitespaces except when quoted
    var quoted = false;
    final re = RegExp(r'\s');
    final cleanedColumns = columns.split('').map((c) {
      if (re.hasMatch(c) && !quoted) {
        return '';
      }
      if (c == '"') {
        quoted = !quoted;
      }
      return c;
    }).join();

    overrideSearchParams('select', cleanedColumns);
    if (_headers['Prefer'] != null) {
      _headers['Prefer'] = '${_headers['Prefer']},';
    }
    _headers['Prefer'] = '${_headers['Prefer']}return=representation';
    return PostgrestTransformBuilder<R>(
      PostgrestBuilder(
        headers: _headers,
        url: _url,
        httpClient: _httpClient,
        isolate: _isolate,
        options: _options,
        body: _body,
        method: _method,
        schema: _schema,
      ),
    );
  }

  /// Orders the result with the specified [column].
  ///
  /// When [options] has `ascending` value true, the result will be in ascending order.
  /// When [options] has `nullsFirst` value true, `null`s appear first.
  /// ```dart
  /// final data = await supabase
  ///     .from('users')
  ///     .select()
  ///     .order('username', ascending: false);
  /// ````
  /// If [column] is a foreign column, the [options] need to have `foreignTable` value provided
  /// ```dart
  /// final data = await supabase
  ///     .from('users')
  ///     .select('messages(*)')
  ///     .order('channel_id',
  ///         foreignTable: 'messages', ascending: false);
  /// ```
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? foreignTable,
  }) {
    final key = foreignTable == null ? 'order' : '$foreignTable.order';
    final existingOrder = _url.queryParameters[key];
    final value = '${existingOrder == null ? '' : '$existingOrder,'}'
        '$column.${ascending ? 'asc' : 'desc'}.${nullsFirst ? 'nullsfirst' : 'nullslast'}';

    overrideSearchParams(key, value);
    return this;
  }

  /// Limits the result with the specified `count`.
  ///
  /// ```dart
  /// final data = await supabase.from('users').select().limit(1);
  /// ```
  ///
  /// If we want to limit a foreign column, the [options] need to have `foreignTable` value provided
  /// ```dart
  /// final data = await supabase
  ///   .from('users')
  ///   .select('messages(*)')
  ///   .limit(1, foreignTable: 'messages');
  /// ```
  PostgrestTransformBuilder<T> limit(int count, {String? foreignTable}) {
    final key = foreignTable == null ? 'limit' : '$foreignTable.limit';

    appendSearchParams(key, '$count');
    return this;
  }

  /// Limits the result to rows within the specified range, inclusive.
  ///
  /// ```dart
  /// final data = await supabase
  ///     .from('users')
  ///     .select('messages(*)')
  ///     .range(1, 1);
  /// ```
  ///
  /// If we want to limit a foreign column, the [options] need to have `foreignTable` value provided
  /// ```dart
  /// final data = await supabase
  ///     .from('users')
  ///     .select('messages(*)')
  ///     .range(1, 1, foreignTable: 'messages');
  /// ```
  PostgrestTransformBuilder<T> range(int from, int to, {String? foreignTable}) {
    final keyOffset = foreignTable == null ? 'offset' : '$foreignTable.offset';
    final keyLimit = foreignTable == null ? 'limit' : '$foreignTable.limit';

    appendSearchParams(keyOffset, '$from');
    appendSearchParams(keyLimit, '${to - from + 1}');
    return this;
  }

  /// Retrieves only one row from the result.
  ///
  /// Result must be one row (e.g. using `limit`), otherwise this will result in an error.
  /// ```dart
  /// final data = await supabase
  ///     .from('users')
  ///     .select<PostgrestMap>()
  ///     .limit(1)
  ///     .single();
  /// ```
  ///
  /// Data type is `Map<String, dynamic>`.
  ///
  /// By specifying this type via `.select<Map<String,dynamic>>()` you get more type safety.
  PostgrestTransformBuilder<T> single() {
    _headers['Accept'] = 'application/vnd.pgrst.object+json';
    return this;
  }

  /// Retrieves at most one row from the result.
  ///
  /// Result must be at most one row or nullable
  /// (e.g. using `eq` on a UNIQUE column), otherwise this will result in an error.
  ///
  ///
  /// Data type is `Map<String, dynamic>?`.
  ///
  /// By specifying this type via `.select<Map<String,dynamic>?>()` you get more type safety.
  PostgrestTransformBuilder<T> maybeSingle() {
    _headers['Accept'] = 'application/vnd.pgrst.object+json';
    _maybeEmpty = true;
    return this;
  }

  /// Retrieves the response as CSV.
  /// This will skip object parsing.
  ///
  /// ```dart
  /// postgrest.from('users').select().csv()
  /// ```
  PostgrestTransformBuilder<T> csv() {
    _headers['Accept'] = 'text/csv';
    return this;
  }
}
