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
  /// If [column] is a referenced table column, [referencedTable] has to be set
  /// ```dart
  /// final data = await supabase
  ///     .from('users')
  ///     .select('messages(*)')
  ///     .order('channel_id',
  ///         referencedTable: 'messages', ascending: false);
  /// ```
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    final key = referencedTable == null ? 'order' : '$referencedTable.order';
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
  /// If we want to limit a referenced table column, [referencedTable]
  /// has to beset
  /// ```dart
  /// final data = await supabase
  ///   .from('users')
  ///   .select('messages(*)')
  ///   .limit(1, referencedTable: 'messages');
  /// ```
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) {
    final key = referencedTable == null ? 'limit' : '$referencedTable.limit';

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
  /// If we want to limit a referenced table column, [referencedTable]
  /// has to be set
  /// ```dart
  /// final data = await supabase
  ///     .from('users')
  ///     .select('messages(*)')
  ///     .range(1, 1, referencedTable: 'messages');
  /// ```
  PostgrestTransformBuilder<T> range(int from, int to,
      {String? referencedTable}) {
    final keyOffset =
        referencedTable == null ? 'offset' : '$referencedTable.offset';
    final keyLimit =
        referencedTable == null ? 'limit' : '$referencedTable.limit';

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
  PostgrestTransformBuilder<PostgrestMap> single() {
    final newHeaders = {..._headers};
    newHeaders['Accept'] = 'application/vnd.pgrst.object+json';

    return PostgrestTransformBuilder(
      _copyWithType(
        headers: newHeaders,
      ),
    );
  }

  /// Retrieves at most one row from the result.
  ///
  /// Result must be at most one row or nullable
  /// (e.g. using `eq` on a UNIQUE column or `limit(1)`),
  /// otherwise this will result in an error.
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    // Temporary fix for https://github.com/supabase/supabase-flutter/issues/560
    // Issue persists e.g. for `.insert([...]).select().maybeSingle()`
    final newHeaders = {..._headers};

    if (_method?.toUpperCase() == 'GET') {
      newHeaders['Accept'] = 'application/json';
    } else {
      newHeaders['Accept'] = 'application/vnd.pgrst.object+json';
    }

    return PostgrestTransformBuilder(
      _copyWithType(
        maybeSingle: true,
        headers: newHeaders,
      ),
    );
  }

  /// Retrieves the response as CSV.
  ///
  /// This will skip object parsing.
  ///
  /// ```dart
  /// supabase.from('users').select().csv()
  /// ```
  PostgrestTransformBuilder<String> csv() {
    final newHeaders = {..._headers};
    newHeaders['Accept'] = 'text/csv';

    return PostgrestTransformBuilder(
      _copyWithType(
        headers: newHeaders,
      ),
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
      [CountOption count = CountOption.exact]) {
    return ResponsePostgrestBuilder(
      _copyWithType(count: count),
    );
  }

  /// Performs a head request.
  ///
  /// This will not return any data, but can only be used for either
  /// ```dart
  /// supabase.from("table").select().head();
  /// ```
  /// or
  /// ```dart
  /// supabase.rpc("function").head();
  ///```
  PostgrestBuilder<void, void, void> head() {
    return _copyWithType(method: METHOD_HEAD);
  }

  /// Enables support for GeoJSON for use with PostGIS data types
  /// Used when you need the complete response to be in GeoJSON format.
  /// You will need to enable the PostGIS extension for this to work.
  ///
  /// https://supabase.com/docs/guides/database/extensions/postgis
  ///
  ResponsePostgrestBuilder<Map<String, dynamic>, Map<String, dynamic>,
      Map<String, dynamic>> geojson() {
    final newHeaders = {..._headers};
    newHeaders['Accept'] = 'application/geo+json;';
    return ResponsePostgrestBuilder(_copyWithType(headers: newHeaders));
  }

  /// Obtains the EXPLAIN plan for this request.
  ///
  /// Before using this method, you need to enable `explain()` on your
  /// Supabase instance by following the guide below. Note that `explain()`
  /// should only be enabled on an development environment.
  ///
  /// https://supabase.com/docs/guides/api/rest/debugging-performance#enabling-explain
  ///
  /// [analyze] If `true`, the query will be executed and the actual run time will be displayed.
  ///
  /// [verbose] If `true`, the query identifier will be displayed and the result will include the output columns of the query.
  ///
  /// [settings] If `true`, include information on configuration parameters that affect query planning.
  ///
  /// [buffers] If `true`, include information on buffer usage.
  ///
  /// [wal] If `true`, include information on WAL record generation
  PostgrestBuilder<String, String, String> explain({
    bool analyze = false,
    bool verbose = false,
    bool settings = false,
    bool buffers = false,
    bool wal = false,
  }) {
    final options = [
      if (analyze) 'analyze',
      if (verbose) 'verbose',
      if (settings) 'settings',
      if (buffers) 'buffers',
      if (wal) 'wal',
    ].join('|');

    // An Accept header can carry multiple media types but postgrest-js always sends one
    final forMediatype = _headers['Accept'] ?? 'application/json';
    final newHeaders = {..._headers};
    newHeaders['Accept'] =
        'application/vnd.pgrst.plan+text; for="$forMediatype"; options=$options;';
    return _copyWithType(headers: newHeaders);
  }
}
