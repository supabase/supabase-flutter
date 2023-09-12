part of 'postgrest_builder.dart';

class PostgrestTransformBuilder<T> extends RawPostgrestBuilder<T, T, T> {
  PostgrestTransformBuilder(super.builder);

  PostgrestTransformBuilder<T> copyWithUrl(Uri url) =>
      PostgrestTransformBuilder(_copyWith(url: url));

  /// Performs horizontal filtering with SELECT.
  ///
  /// ```dart
  /// supabase.from('users').insert().select('id, messages');
  /// ```
  /// ```dart
  /// supabase.from('users').insert().select('id, messages').count(CountOption.exact);
  /// ```
  ///
  /// By appending [count] the return type is [PostgrestResponse]. Otherwise it's the data directly without the wrapper.
  ///
  /// There are optional typedefs for typical types: [PostgrestMap], [PostgrestList], [PostgrestMapResponse], [PostgrestListResponse]
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) {
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
    final newHeaders = {..._headers};

    final url = overrideSearchParams('select', cleanedColumns);
    if (newHeaders['Prefer'] != null) {
      newHeaders['Prefer'] = '${newHeaders['Prefer']},';
    }
    newHeaders['Prefer'] = '${newHeaders['Prefer']}return=representation';
    return PostgrestTransformBuilder<PostgrestList>(
      _copyWithType(
        url: url,
        headers: newHeaders,
      ),
    );
  }

  /// Orders the result with the specified [column].
  ///
  /// When [ascending] is true, the result will be in ascending order.
  /// When [nullsFirst] is true, `null`s appear first.
  /// ```dart
  /// final data = await supabase
  ///     .from('users')
  ///     .select()
  ///     .order('username', ascending: false);
  /// ````
  /// If [column] is a foreign column, [foreignTable] has to be set
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
    final url = overrideSearchParams(key, value);
    return PostgrestTransformBuilder(copyWithUrl(url));
  }

  /// Limits the result with the specified [count].
  ///
  /// ```dart
  /// final data = await supabase.from('users').select().limit(1);
  /// ```
  ///
  /// If we want to limit a foreign column, [foreignTable] has to be set
  /// ```dart
  /// final data = await supabase
  ///   .from('users')
  ///   .select('messages(*)')
  ///   .limit(1, foreignTable: 'messages');
  /// ```
  PostgrestTransformBuilder<T> limit(int count, {String? foreignTable}) {
    final key = foreignTable == null ? 'limit' : '$foreignTable.limit';

    final url = appendSearchParams(key, '$count');
    return PostgrestTransformBuilder(copyWithUrl(url));
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
  /// If we want to limit a foreign column, [foreignTable] has to be set
  /// ```dart
  /// final data = await supabase
  ///     .from('users')
  ///     .select('messages(*)')
  ///     .range(1, 1, foreignTable: 'messages');
  /// ```
  PostgrestTransformBuilder<T> range(int from, int to, {String? foreignTable}) {
    final keyOffset = foreignTable == null ? 'offset' : '$foreignTable.offset';
    final keyLimit = foreignTable == null ? 'limit' : '$foreignTable.limit';

    var url = appendSearchParams(keyOffset, '$from');
    url = appendSearchParams(keyLimit, '${to - from + 1}', url);
    return PostgrestTransformBuilder(copyWithUrl(url));
  }

  /// Retrieves only one row from the result.
  ///
  /// Result must be one row (e.g. using `limit`), otherwise this will result in an error.
  /// ```dart
  /// final data = await supabase
  ///     .from('users')
  ///     .select()
  ///     .limit(1)
  ///     .single();
  /// ```
  RawPostgrestBuilder<PostgrestMap, PostgrestMap, PostgrestMap> single() {
    final newHeaders = {..._headers};
    newHeaders['Accept'] = 'application/vnd.pgrst.object+json';

    return _copyWithType(
      headers: newHeaders,
    );
  }

  /// Retrieves at most one row from the result.
  ///
  /// Result must be at most one row or nullable
  /// (e.g. using `eq` on a UNIQUE column or `limit(1)`),
  /// otherwise this will result in an error.
  RawPostgrestBuilder<PostgrestMap?, PostgrestMap?, PostgrestMap?>
      maybeSingle() {
    // Temporary fix for https://github.com/supabase/supabase-flutter/issues/560
    // Issue persists e.g. for `.insert([...]).select().maybeSingle()`
    final newHeaders = {..._headers};

    if (_method?.toUpperCase() == 'GET') {
      newHeaders['Accept'] = 'application/json';
    } else {
      newHeaders['Accept'] = 'application/vnd.pgrst.object+json';
    }

    return _copyWithType(
      maybeSingle: true,
      headers: newHeaders,
    );
  }

  /// Retrieves the response as CSV.
  ///
  /// This will skip object parsing.
  ///
  /// ```dart
  /// supabase.from('users').select().csv()
  /// ```
  RawPostgrestBuilder<String, String, String> csv() {
    final newHeaders = {..._headers};
    newHeaders['Accept'] = 'text/csv';

    return _copyWithType(
      headers: newHeaders,
    );
  }

  /// Performs additionally to the [select] a count query.
  ///
  /// It's used to retrieve the total number of rows that satisfy the
  /// query. The value for count respects any filters (e.g. eq, gt), but ignores
  /// modifiers (e.g. limit, range).
  ///
  /// This changes the return type from the data only to a [PostgrestResponse] with the data and the count.
  ///
  /// ```dart
  /// final res = await postgrest
  ///    .from('users')
  ///    .select()
  ///    .count(CountOption.exact);
  /// final users = res.data;
  /// int count = res.count;
  /// ```
  ResponsePostgrestBuilder<PostgrestResponse<T>, T, T> count(
      CountOption count) {
    return ResponsePostgrestBuilder(
      _copyWithType(count: count),
    );
  }

  PostgrestBuilder<void, void, void> head() {
    return _copyWithType(method: METHOD_HEAD);
  }
}
