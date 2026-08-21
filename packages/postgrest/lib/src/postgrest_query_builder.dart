part of 'postgrest_builder.dart';

/// {@template postgrest_query_builder}
/// The query builder class provides a convenient interface to creating request
/// queries.
///
/// Call one of
/// * select() - "get"
/// * insert() - "post"
/// * upsert() - "post"
/// * update() - "patch"
/// * delete() - "delete"
/// * count() - "head"
/// first. Each of these returns a filter builder that allows the user to
/// stack filter functions before the request is sent.
///
/// The query builder itself is not executable: a request without one of the
/// table operations above is meaningless, so awaiting it is a compile-time
/// error rather than a runtime one.
/// {@endtemplate}
@immutable
class PostgrestQueryBuilder {
  final _RequestConfig _config;

  /// {@macro postgrest_query_builder}
  PostgrestQueryBuilder({
    required Uri url,
    Map<String, String>? headers,
    String? schema,
    Client? httpClient,
    YAJsonIsolate? isolate,
    SupabaseRetryOptions retryOptions = const SupabaseRetryOptions(),
    Duration? requestTimeout,
  }) : _config = _RequestConfig(
         url: url,
         headers: {...?headers},
         schema: schema,
         httpClient: httpClient,
         isolate: isolate,
         retry: retryOptions,
         requestTimeout: requestTimeout,
       );

  const PostgrestQueryBuilder._(this._config);

  /// Perform a SELECT query on the table or view.
  ///
  /// ```dart
  /// supabase.from('users').select('id, messages');
  /// ```
  ///
  /// ```dart
  /// supabase.from('users').select('id, messages').count(CountOption.exact);
  /// ```
  /// By appending [count] the return type is [PostgrestResponse]. Otherwise
  /// it's the data directly without the wrapper.
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    // Remove whitespaces except when quoted
    var quoted = false;
    final whitespaceRegularExpression = RegExp(r'\s');
    final cleanedColumns = columns.split('').map((c) {
      if (whitespaceRegularExpression.hasMatch(c) && !quoted) {
        return '';
      }
      if (c == '"') {
        quoted = !quoted;
      }
      return c;
    }).join();

    return _filterBuilder(
      _config.copyWith(
        url: _config.url.overrideSearchParameters('select', cleanedColumns),
        method: HttpMethod.get,
      ),
    );
  }

  /// Perform an INSERT into the table or view.
  ///
  /// By default no data is returned. Use a trailing [select] to return data.
  ///
  /// When inserting multiple rows in bulk, [defaultToNull] is used to set the
  /// values of fields missing in a proper subset of rows to be either `NULL` or
  /// the default value of these columns. Fields missing in all rows always use
  /// the default value of these columns.
  ///
  /// For single row insertions, missing fields will be set to default values
  /// when applicable.
  ///
  /// Default (not returning data):
  /// ```dart
  /// await supabase.from('messages').insert(
  ///     {'message': 'foo', 'username': 'supabot', 'channel_id': 1});
  /// ```
  ///
  /// Returning data:
  /// ```dart
  /// final data = await supabase.from('messages').insert({
  ///   'message': 'foo',
  ///   'username': 'supabot',
  ///   'channel_id': 1
  /// }).select();
  /// ```
  PostgrestFilterBuilder<void> insert(
    Object values, {
    bool defaultToNull = true,
  }) {
    final newHeaders = {..._config.headers};
    if (defaultToNull) {
      newHeaders.remove('Prefer');
    } else {
      newHeaders['Prefer'] = 'missing=default';
    }

    Uri url = _config.url;
    if (values is List) {
      url = _setColumnsSearchParam(values);
    }

    return _filterBuilder(
      _config.copyWith(
        method: HttpMethod.post,
        headers: newHeaders,
        body: values,
        url: url,
      ),
    );
  }

  /// Perform an UPSERT on the table or view.
  ///
  /// By specifying the [onConflict] parameter, you can make UPSERT work on a
  /// column(s) that has a UNIQUE constraint. [ignoreDuplicates] Specifies if
  /// duplicate rows should be ignored and not inserted.
  ///
  /// By default no data is returned. Use a trailing `select` to return data.
  ///
  /// When inserting multiple rows in bulk, [defaultToNull] is used to set the
  /// values of fields missing in a proper subset of rows to be either `NULL` or
  /// the default value of these columns. Fields missing in all rows always use
  /// the default value of these columns.
  ///
  /// For single row insertions, missing fields will be set to default values
  /// when applicable.
  ///
  /// Default (not returning data):
  /// ```dart
  /// await supabase.from('messages').upsert({
  ///   'id': 3,
  ///   'message': 'foo',
  ///   'username': 'supabot',
  ///   'channel_id': 2
  /// });
  /// ```
  ///
  /// Returning data:
  /// ```dart
  /// final data = await supabase.from('messages').upsert({
  ///   'message': 'foo',
  ///   'username': 'supabot',
  ///   'channel_id': 1
  /// }).select();
  /// ```
  PostgrestFilterBuilder<void> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    final newHeaders = {..._config.headers};
    newHeaders['Prefer'] =
        'resolution=${ignoreDuplicates ? 'ignore' : 'merge'}-duplicates';

    if (!defaultToNull) {
      newHeaders['Prefer'] = '${newHeaders['Prefer']!},missing=default';
    }

    Uri url = _config.url;

    if (values is List) {
      url = _setColumnsSearchParam(values);
    }

    if (onConflict != null) {
      url = url.replace(
        queryParameters: {
          'on_conflict': onConflict,
          ...url.queryParameters,
        },
      );
    }

    return _filterBuilder(
      _config.copyWith(
        method: HttpMethod.post,
        headers: newHeaders,
        body: values,
        url: url,
      ),
    );
  }

  /// Perform an UPDATE on the table or view.
  ///
  /// By default no data is returned. Use a trailing [select] to return data.
  ///
  /// Default (not returning data):
  /// ```dart
  /// await supabase
  ///     .from('messages')
  ///     .update({'channel_id': 2})
  ///     .eq('message', 'foo');
  /// ```
  ///
  /// Returning data:
  /// ```dart
  /// await supabase
  ///     .from('messages')
  ///     .update({'channel_id': 2})
  ///     .eq('message', 'foo')
  ///     .select();
  /// ```
  PostgrestFilterBuilder<void> update(Map<dynamic, dynamic> values) {
    final newHeaders = {..._config.headers}..remove('Prefer');

    return _filterBuilder(
      _config.copyWith(
        method: HttpMethod.patch,
        headers: newHeaders,
        body: values,
      ),
    );
  }

  /// Perform a DELETE on the table or view.
  ///
  /// By default no data is returned. Use a trailing [select] to return data.
  ///
  /// Default (not returning data):
  /// ```dart
  /// await supabase
  ///     .from('messages')
  ///     .delete()
  ///     .eq('message', 'foo');
  /// ```
  ///
  /// Returning data:
  /// ```dart
  /// await supabase
  ///     .from('messages')
  ///     .delete()
  ///     .eq('message', 'foo')
  ///     .select();
  /// ```
  PostgrestFilterBuilder<void> delete() {
    final newHeaders = {..._config.headers}..remove('Prefer');
    return _filterBuilder(
      _config.copyWith(
        method: HttpMethod.delete,
        headers: newHeaders,
      ),
    );
  }

  Uri _setColumnsSearchParam(List<dynamic> values) {
    final newValues = PostgrestList.from(values);
    final columns = [for (final element in newValues) ...element.keys];
    if (newValues.isNotEmpty) {
      final uniqueColumns = {...columns}.map((e) => '"$e"').join(',');
      return _config.url.appendSearchParameters("columns", uniqueColumns);
    }
    return _config.url;
  }

  /// Only performs a count query on the table or view.
  /// ```dart
  /// int count = await supabase.from('users').count();
  /// ```
  PostgrestFilterBuilder<int> count([CountOption option = CountOption.exact]) {
    return _filterBuilder(
      _config.copyWith(
        method: HttpMethod.head,
        count: option,
      ),
    );
  }

  /// Overrides the retry behavior of the requests built by this builder.
  ///
  /// See [PostgrestBuilder.retry] for the parameters.
  PostgrestQueryBuilder retry({
    bool enabled = true,
    int? count,
    Duration? requestTimeout,
  }) {
    return PostgrestQueryBuilder._(
      _config.copyWith(
        retry: _config.retry.copyWith(enabled: enabled, count: count),
        requestTimeout: requestTimeout,
      ),
    );
  }

  /// Sets a header on the requests built by this builder.
  PostgrestQueryBuilder setHeader(String key, String value) {
    return PostgrestQueryBuilder._(
      _config.copyWith(
        headers: {..._config.headers, key: value},
      ),
    );
  }
}
