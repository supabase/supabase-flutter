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
/// stack filter functions before the request is sent, except insert() and
/// upsert(), which have no existing rows to filter and so return a transform
/// builder that only shapes the rows they create.
///
/// The query builder itself is not executable: a request without one of the
/// table operations above is meaningless, so awaiting it is a compile-time
/// error rather than a runtime one.
/// {@endtemplate}
@immutable
class PostgrestQueryBuilder {
  /// {@macro postgrest_query_builder}
  PostgrestQueryBuilder({
    required Uri url,
    Map<String, String>? headers,
    String? schema,
    Client? httpClient,
    AsyncJsonCodec? jsonCodec,
    SupabaseRetryOptions retryOptions = const SupabaseRetryOptions(),
    Duration? requestTimeout,
  }) : _config = _RequestConfig(
         url: url,
         headers: {...?headers},
         schema: schema,
         httpClient: httpClient,
         jsonCodec: jsonCodec,
         retry: retryOptions,
         requestTimeout: requestTimeout,
       );

  const PostgrestQueryBuilder._(this._config);
  final _RequestConfig _config;

  /// Perform a SELECT query on the table or view.
  ///
  /// ```dart
  /// supabase.from('users').select('id, messages');
  /// ```
  ///
  /// Append [PostgrestBuilder.count] to also receive the total number of rows:
  ///
  /// ```dart
  /// supabase.from('users').select('id, messages').count(CountOption.exact);
  /// ```
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    final cleanedColumns = _removeUnquotedWhitespace(columns);

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
  PostgrestTransformBuilder<void> insert(
    Object values, {
    bool defaultToNull = true,
  }) {
    final newHeaders = {..._config.headers};
    if (!defaultToNull) {
      _mergePrefer(newHeaders, [
        'missing=default',
      ]);
    }

    Uri url = _config.url;
    Object body = values;
    if (values is List) {
      final rows = _jsonRows(values);
      url = _setColumnsSearchParam(rows);
      body = rows;
    }

    return _transformBuilder(
      _config.copyWith(
        method: HttpMethod.post,
        headers: newHeaders,
        body: body,
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
  PostgrestTransformBuilder<void> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    final newHeaders = {..._config.headers};
    _mergePrefer(newHeaders, [
      'resolution=${ignoreDuplicates ? 'ignore' : 'merge'}-duplicates',
      if (!defaultToNull) 'missing=default',
    ]);

    Uri url = _config.url;
    Object body = values;
    if (values is List) {
      final rows = _jsonRows(values);
      url = _setColumnsSearchParam(rows);
      body = rows;
    }

    if (onConflict != null) {
      url = url.replace(
        queryParameters: {
          'on_conflict': onConflict,
          ...url.queryParameters,
        },
      );
    }

    return _transformBuilder(
      _config.copyWith(
        method: HttpMethod.post,
        headers: newHeaders,
        body: body,
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
  PostgrestFilterBuilder<void> update(Object values) {
    final newHeaders = {..._config.headers};

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
    final newHeaders = {..._config.headers};
    return _filterBuilder(
      _config.copyWith(
        method: HttpMethod.delete,
        headers: newHeaders,
      ),
    );
  }

  Uri _setColumnsSearchParam(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return _config.url;
    final columns = {for (final row in rows) ...row.keys};
    final uniqueColumns = columns.map((e) => '"$e"').join(',');
    return _config.url.appendSearchParameters("columns", uniqueColumns);
  }

  /// [values] as JSON objects, calling `toJson()` once on a row that is not
  /// a map, so that the columns and the body come from the same keys.
  List<Map<String, dynamic>> _jsonRows(List<dynamic> values) => [
    for (final row in values) _jsonRow(row),
  ];

  Map<String, dynamic> _jsonRow(Object? row) {
    Object? json = row;
    if (row is! Map) {
      try {
        // ignore: avoid_dynamic_calls
        json = (row as dynamic).toJson();
      } on NoSuchMethodError {
        json = null;
      }
    }
    if (json is Map<String, dynamic>) {
      return json;
    }
    if (json is! Map || json.keys.any((key) => key is! String)) {
      throw ArgumentError.value(row, 'values', 'Every row must be an object');
    }
    return Map.from(json);
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
      decode: _rowCountDecoder,
    );
  }

  /// Overrides the retry behavior of the requests built by this builder.
  ///
  /// See [PostgrestBuilder.retry] for the parameters.
  PostgrestQueryBuilder retry({bool enabled = true, int? count}) {
    return PostgrestQueryBuilder._(
      _config.copyWith(
        retry: _config.retry.copyWith(enabled: enabled, count: count),
      ),
    );
  }

  /// Bounds how long a single attempt of the requests built by this builder
  /// may go without progress.
  ///
  /// See [PostgrestBuilder.requestTimeout].
  PostgrestQueryBuilder requestTimeout(Duration timeout) {
    return PostgrestQueryBuilder._(_config.copyWith(requestTimeout: timeout));
  }

  /// Cancels the requests built by this builder when [abortSignal]
  /// completes.
  ///
  /// See [PostgrestBuilder.abortSignal].
  PostgrestQueryBuilder abortSignal(Future<void> abortSignal) {
    return PostgrestQueryBuilder._(_config.copyWith(abortSignal: abortSignal));
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
