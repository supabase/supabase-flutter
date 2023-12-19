part of 'postgrest_builder.dart';

/// {@template postgrest_query_builder}
/// The query builder class provides a convenient interface to creating request queries.
///
/// Allows the user to stack the filter functions before they call any of
/// * select() - "get"
/// * insert() - "post"
/// * update() - "patch"
/// * delete() - "delete"
/// Once any of these are called the filters are passed down to the Request.
/// {@endtemplate}
class PostgrestQueryBuilder<T> extends RawPostgrestBuilder<T, T, T> {
  /// {@macro postgrest_query_builder}
  PostgrestQueryBuilder({
    required Uri url,
    String? method,
    Map<String, String>? headers,
    String? schema,
    Client? httpClient,
    YAJsonIsolate? isolate,
  }) : super(
          PostgrestBuilder(
            url: url,
            method: method,
            headers: headers ?? {},
            schema: schema,
            httpClient: httpClient,
            isolate: isolate,
          ),
        );

  /// Perform a SELECT query on the table or view.
  ///
  /// ```dart
  /// supabase.from('users').select('id, messages');
  /// ```
  ///
  /// ```dart
  /// supabase.from('users').select('id, messages').count(CountOption.exact);
  /// ```
  /// By appending [count] the return type is [PostgrestResponse]. Otherwise it's the data directly without the wrapper.
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
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

    final url = overrideSearchParams('select', cleanedColumns);
    return PostgrestFilterBuilder(_copyWithType(
      url: url,
      method: METHOD_GET,
    ));
  }

  /// Perform an INSERT into the table or view.
  ///
  /// By default no data is returned. Use a trailing [select] to return data.
  ///
  /// When inserting multiple rows in bulk, [defaultToNull] is used to set the values of fields missing in a proper subset of rows
  /// to be either `NULL` or the default value of these columns.
  /// Fields missing in all rows always use the default value of these columns.
  ///
  /// For single row insertions, missing fields will be set to default values when applicable.
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
  PostgrestFilterBuilder<T> insert(
    Object values, {
    bool defaultToNull = true,
  }) {
    final newHeaders = {..._headers};
    newHeaders['Prefer'] = '';

    if (!defaultToNull) {
      newHeaders['Prefer'] = 'missing=default';
    }

    Uri url = _url;
    if (values is List) {
      url = _setColumnsSearchParam(values);
    }

    return PostgrestFilterBuilder(_copyWith(
      method: METHOD_POST,
      headers: newHeaders,
      body: values,
      url: url,
    ));
  }

  /// Perform an UPSERT on the table or view.
  ///
  /// By specifying the [onConflict] parameter, you can make UPSERT work on a column(s) that has a UNIQUE constraint.
  /// [ignoreDuplicates] Specifies if duplicate rows should be ignored and not inserted.
  ///
  /// By default no data is returned. Use a trailing `select` to return data.
  ///
  /// When inserting multiple rows in bulk, [defaultToNull] is used to set the values of fields missing in a proper subset of rows
  /// to be either `NULL` or the default value of these columns.
  /// Fields missing in all rows always use the default value of these columns.
  ///
  /// For single row insertions, missing fields will be set to default values when applicable.
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
  PostgrestFilterBuilder<T> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    final newHeaders = {..._headers};
    newHeaders['Prefer'] =
        'resolution=${ignoreDuplicates ? 'ignore' : 'merge'}-duplicates';

    if (!defaultToNull) {
      newHeaders['Prefer'] = '${newHeaders['Prefer']!},missing=default';
    }
    Uri url = _url;
    if (onConflict != null) {
      url = _url.replace(
        queryParameters: {
          'on_conflict': onConflict,
          ..._url.queryParameters,
        },
      );
    }

    if (values is List) {
      url = _setColumnsSearchParam(values);
    }

    return PostgrestFilterBuilder<T>(_copyWith(
      method: METHOD_POST,
      headers: newHeaders,
      body: values,
      url: url,
    ));
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
  PostgrestFilterBuilder<T> update(Map values) {
    final newHeaders = {..._headers};
    newHeaders['Prefer'] = '';

    return PostgrestFilterBuilder<T>(_copyWith(
      method: METHOD_PATCH,
      headers: newHeaders,
      body: values,
    ));
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
  PostgrestFilterBuilder<T> delete() {
    final newHeaders = {..._headers};
    newHeaders['Prefer'] = '';
    return PostgrestFilterBuilder<T>(_copyWith(
      method: METHOD_DELETE,
      headers: newHeaders,
    ));
  }

  Uri _setColumnsSearchParam(List values) {
    final newValues = PostgrestList.from(values);
    final columns = newValues.fold<List<String>>(
        [], (value, element) => value..addAll(element.keys));
    if (newValues.isNotEmpty) {
      final uniqueColumns = {...columns}.map((e) => '"$e"').join(',');
      return appendSearchParams("columns", uniqueColumns);
    }
    return _url;
  }

  /// Only performs a count query on the table or view.
  /// ```dart
  /// int count = await supabase.from('users').count();
  /// ```
  PostgrestFilterBuilder<int> count([CountOption option = CountOption.exact]) {
    return PostgrestFilterBuilder<int>(_copyWithType(
      method: METHOD_HEAD,
      count: option,
    ));
  }
}
