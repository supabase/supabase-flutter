part of 'postgrest_builder.dart';

const _objectMediaType = 'application/vnd.pgrst.object+json';

/// A builder for shaping the result of a query, such as ordering or limiting
/// it.
class PostgrestTransformBuilder<T> extends PostgrestBuilder<T> {
  PostgrestTransformBuilder(PostgrestBuilder<T> builder)
    : super._(config: builder._config, decode: builder._decode);

  /// Like [_copyWith], but for a step that changes what the request resolves
  /// to, so the result is decoded from the response body as [P] instead.
  PostgrestTransformBuilder<P> _copyWithType<P>({
    Uri? url,
    Headers? headers,
    HttpMethod? method,
    bool? maybeSingle,
  }) => PostgrestTransformBuilder(
    PostgrestBuilder._(
      config: _config.copyWith(
        url: url,
        headers: headers,
        method: method,
        maybeSingle: maybeSingle,
      ),
      decode: _bodyDecoder<P>(),
    ),
  );

  /// Returns a copy of this request pointed at [url].
  PostgrestTransformBuilder<T> _copyWithUrl(Uri url) =>
      PostgrestTransformBuilder(_copyWith(url: url));

  @override
  PostgrestTransformBuilder<T> retry({bool enabled = true, int? count}) =>
      PostgrestTransformBuilder(super.retry(enabled: enabled, count: count));

  @override
  PostgrestTransformBuilder<T> requestTimeout(Duration timeout) =>
      PostgrestTransformBuilder(super.requestTimeout(timeout));

  @override
  PostgrestTransformBuilder<T> abortSignal(Future<void> abortSignal) =>
      PostgrestTransformBuilder(super.abortSignal(abortSignal));

  @override
  PostgrestTransformBuilder<T> setHeader(String key, String value) =>
      PostgrestTransformBuilder(super.setHeader(key, value));

  /// Performs horizontal filtering with SELECT.
  ///
  /// ```dart
  /// supabase.from('users').insert().select('id, messages');
  /// ```
  ///
  /// Append [count] to also receive the total number of rows.
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) {
    final cleanedColumns = _removeUnquotedWhitespace(columns);
    final newHeaders = {..._headers};

    final url = _url.overrideSearchParameters('select', cleanedColumns);
    _mergePrefer(newHeaders, [
      'return=representation',
    ]);
    return PostgrestTransformBuilder(
      _copyWithType(
        url: url,
        headers: newHeaders,
      ),
    );
  }

  /// Orders the result with the specified [column].
  ///
  /// [ascending] defaults to `true`, matching SQL's `ORDER BY`, so results come
  /// back in ascending order unless `ascending: false` is passed.
  ///
  /// [nullsFirst] places `null`s before (`true`) or after (`false`) the other
  /// values. When it is left out no placement is sent and PostgreSQL's
  /// default applies: last for an ascending sort and first for a descending
  /// one.
  ///
  /// ```dart
  /// // Ascending is the default.
  /// final data = await supabase
  ///     .from('users')
  ///     .select()
  ///     .order('username');
  /// ```
  ///
  /// ```dart
  /// // Descending has to be requested explicitly.
  /// final data = await supabase
  ///     .from('users')
  ///     .select()
  ///     .order('username', ascending: false);
  /// ```
  ///
  /// If [column] is a referenced table column, [referencedTable] has to be set
  ///
  /// ```dart
  /// final data = await supabase
  ///     .from('users')
  ///     .select('messages(*)')
  ///     .order('channel_id',
  ///         referencedTable: 'messages', ascending: false);
  /// ```
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = true,
    bool? nullsFirst,
    String? referencedTable,
  }) {
    final placement = switch (nullsFirst) {
      null => '',
      true => '.nullsfirst',
      false => '.nullslast',
    };
    return appendOrderKey(
      '$column.${ascending ? 'asc' : 'desc'}$placement',
      referencedTable: referencedTable,
    );
  }

  /// Appends [value] as another value of the query parameter [key].
  @internal
  PostgrestTransformBuilder<T> appendSearchParameter(
    String key,
    String value,
  ) => _copyWithUrl(_url.appendSearchParameters(key, value));

  /// Merges the rendered sort key [key] into the `order` parameter, or into
  /// `referencedTable.order` when [referencedTable] is given, which PostgREST
  /// reads once, adding nothing to [key].
  @internal
  PostgrestTransformBuilder<T> appendOrderKey(
    String key, {
    String? referencedTable,
  }) {
    final parameter = referencedTable == null
        ? 'order'
        : '$referencedTable.order';
    final existingOrder = _url.queryParameters[parameter];
    final value = existingOrder == null ? key : '$existingOrder,$key';
    return _copyWithUrl(_url.overrideSearchParameters(parameter, value));
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

    final url = _url.overrideSearchParameters(key, '$count');
    return _copyWithUrl(url);
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
  ///
  /// Throws an [ArgumentError] when [to] is less than [from].
  PostgrestTransformBuilder<T> range(
    int from,
    int to, {
    String? referencedTable,
  }) {
    checkPostgrestRange(from, to);
    return window(from, to - from + 1, referencedTable: referencedTable);
  }

  /// Skips [offset] rows and limits the result to the [count] rows after
  /// them, or the rows of [referencedTable] when it is given.
  @internal
  PostgrestTransformBuilder<T> window(
    int offset,
    int count, {
    String? referencedTable,
  }) {
    final prefix = referencedTable == null ? '' : '$referencedTable.';
    final url = _url
        .overrideSearchParameters('${prefix}offset', '$offset')
        .overrideSearchParameters('${prefix}limit', '$count');
    return _copyWithUrl(url);
  }

  /// Retrieves only one row from the result.
  ///
  /// Result must be one row (e.g. using `limit`), otherwise this will result in
  /// an error.
  /// ```dart
  /// final data = await supabase
  ///     .from('users')
  ///     .select()
  ///     .limit(1)
  ///     .single();
  /// ```
  PostgrestTransformBuilder<PostgrestMap> single() {
    final newHeaders = {..._headers};
    newHeaders[HttpHeader.accept] = _objectMediaType;

    return PostgrestTransformBuilder(
      _copyWithType(
        headers: newHeaders,
        maybeSingle: false,
      ),
    );
  }

  /// Retrieves at most one row from the result.
  ///
  /// Result must be at most one row or nullable
  /// (e.g. using `eq` on a UNIQUE column or `limit(1)`),
  /// otherwise this will result in an error.
  ///
  /// An insert, upsert, update or delete asks PostgREST for a single object,
  /// so a write that affects more than one row is rolled back before the
  /// error is thrown.
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    // A read, or a function call, enforces the single-row constraint
    // client-side, so that matching zero rows resolves to `null` without
    // PostgREST answering 406 and polluting the API logs.
    final isRead =
        _method == HttpMethod.get ||
        _method == HttpMethod.head ||
        _config.functionCall;
    return PostgrestTransformBuilder(
      _copyWithType(
        headers: isRead
            ? null
            : {..._headers, HttpHeader.accept: _objectMediaType},
        maybeSingle: true,
      ),
    );
  }

  /// Omits `null`-valued properties from the response objects.
  ///
  /// This uses the `nulls=stripped` variant of the `Accept` header and
  /// requires PostgREST 11.2 or higher. It applies to row and [single]
  /// responses, in either call order.
  ///
  /// ```dart
  /// supabase.from('users').select().stripNulls();
  /// ```
  PostgrestTransformBuilder<T> stripNulls() =>
      PostgrestTransformBuilder(_copyWith(stripNulls: true));

  /// Runs the query but rolls back the transaction, so no changes are
  /// persisted.
  ///
  /// The data that would have resulted from the query is still returned,
  /// which is useful for previewing the effect of a mutation.
  ///
  /// ```dart
  /// await supabase.from('users').insert({'username': 'foo'}).dryRun();
  /// ```
  PostgrestTransformBuilder<T> dryRun() {
    final newHeaders = {..._headers};
    _mergePrefer(newHeaders, ['tx=rollback']);

    return PostgrestTransformBuilder(_copyWith(headers: newHeaders));
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
    newHeaders[HttpHeader.accept] = 'text/csv';

    return PostgrestTransformBuilder(
      _copyWithType(
        headers: newHeaders,
      ),
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
  ///
  /// The arguments of a function call are sent as query parameters, so they
  /// have to be a [Map] that PostgREST passes on to the function: no `null`
  /// values, no names such as `limit` or `order`, and no values that read
  /// as a filter, such as `eq.1`. Anything else throws an [ArgumentError].
  ///
  /// Throws a [StateError] after an insert, upsert, update or delete, which a
  /// head request cannot perform.
  PostgrestBuilder<void> head() {
    final method = _method;
    if (method == HttpMethod.get || method == HttpMethod.head) {
      return _copyWithType(method: HttpMethod.head);
    }
    if (_config.functionCall) {
      checkPostgrestHeadArguments(_body);
      return _copyWithType(
        method: HttpMethod.head,
        url: _appendArguments(_url, _body),
      );
    }
    throw StateError(
      'head() only applies to a select or a function call, not to a '
      '${method?.value} request',
    );
  }

  /// Enables support for GeoJSON for use with PostGIS data types
  /// Used when you need the complete response to be in GeoJSON format.
  /// You will need to enable the PostGIS extension for this to work.
  ///
  /// https://supabase.com/docs/guides/database/extensions/postgis
  ///
  PostgrestBuilder<Map<String, dynamic>> geojson() {
    final newHeaders = {..._headers};
    newHeaders[HttpHeader.accept] = 'application/geo+json;';
    return _copyWithType(headers: newHeaders);
  }

  /// Sets the maximum number of rows that can be affected by the query.
  ///
  /// Only available with PATCH and DELETE operations. Requires PostgREST v13 or
  /// higher. When the limit is exceeded, the query will fail with an error.
  ///
  /// ```dart
  /// supabase
  ///     .from('users')
  ///     .update({'active': false})
  ///     .eq('status', 'inactive')
  ///     .maxAffected(5);
  /// ```
  ///
  /// ```dart
  /// supabase.from('users').delete().eq('active', false).maxAffected(10);
  /// ```
  PostgrestTransformBuilder<T> maxAffected(int value) {
    final newHeaders = {..._headers};

    _mergePrefer(newHeaders, [
      'handling=strict',
      'max-affected=$value',
    ]);

    return PostgrestTransformBuilder(_copyWith(headers: newHeaders));
  }

  /// Obtains the EXPLAIN plan for this request.
  ///
  /// Before using this method, you need to enable `explain()` on your
  /// Supabase instance by following the guide below. Note that `explain()`
  /// should only be enabled on an development environment.
  ///
  /// https://supabase.com/docs/guides/api/rest/debugging-performance#enabling-explain
  ///
  /// [analyze] If `true`, the query will be executed and the actual run time
  /// will be displayed.
  ///
  /// [verbose] If `true`, the query identifier will be displayed and the result
  /// will include the output columns of the query.
  ///
  /// [settings] If `true`, include information on configuration parameters that
  /// affect query planning.
  ///
  /// [buffers] If `true`, include information on buffer usage.
  ///
  /// [wal] If `true`, include information on WAL record generation
  ///
  /// [format] The format of the returned plan. Defaults to
  /// [ExplainFormat.text]. When [ExplainFormat.json] is used the plan is
  /// returned as a JSON string.
  PostgrestBuilder<String> explain({
    bool analyze = false,
    bool verbose = false,
    bool settings = false,
    bool buffers = false,
    bool wal = false,
    ExplainFormat format = ExplainFormat.text,
  }) {
    final options = [
      if (analyze) 'analyze',
      if (verbose) 'verbose',
      if (settings) 'settings',
      if (buffers) 'buffers',
      if (wal) 'wal',
    ].join('|');

    // An Accept header can carry multiple media types but postgrest-js always
    // sends one
    final newHeaders = {..._headers};
    if (_stripNulls) _applyStripNulls(newHeaders);
    final forMediatype = newHeaders[HttpHeader.accept] ?? 'application/json';
    newHeaders[HttpHeader.accept] =
        'application/vnd.pgrst.plan+${format.name}; for="$forMediatype"; options=$options;';
    return _copyWithType(headers: newHeaders);
  }
}
