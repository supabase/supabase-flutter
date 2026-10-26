part of 'postgrest_typed_builder.dart';

/// Calls Postgres functions, returned by [PostgrestClient.rpc].
///
/// Calling it performs an untyped call, whose result is the decoded response
/// body:
///
/// ```dart
/// final status = await client.rpc('get_status', params: {'name': 'supabot'});
/// ```
///
/// `package:supabase_typegen` generates an extension method on this class for
/// every function of the database, which takes the arguments as typed
/// parameters and resolves to typed results:
///
/// ```dart
/// final List<BooksRow> books = await client.rpc
///     .searchBooks(query: 'dart')
///     .where(Books.publishedOn.isNull().not())
///     .order(Books.title.asc());
/// ```
///
/// The generated methods are built on [rows] and [value].
final class PostgrestRpc {
  /// Calls functions through [client], in [schema] or the schema of the
  /// client when `null`. When [schemaIsExplicit] is set, [schema] also wins
  /// over the schema a generated method passes along. [rows] and [value] run
  /// through [executor], or a [PostgrestHttpTableExecutor] on [client] when
  /// `null`.
  @internal
  const PostgrestRpc(
    this._client, {
    String? schema,
    bool schemaIsExplicit = false,
    PostgrestTableExecutor? executor,
  }) : _schema = schema,
       _schemaIsExplicit = schemaIsExplicit,
       _executor = executor;

  final PostgrestClient _client;
  final String? _schema;
  final bool _schemaIsExplicit;
  final PostgrestTableExecutor? _executor;

  /// A copy of this that runs [rows] and [value] through [executor].
  @internal
  PostgrestRpc withExecutor(PostgrestTableExecutor executor) => PostgrestRpc(
    _client,
    schema: _schema,
    schemaIsExplicit: _schemaIsExplicit,
    executor: executor,
  );

  /// {@template postgrest_rpc}
  /// Performs a stored procedure call.
  ///
  /// [fn] is the name of the function to call.
  ///
  /// [params] is sent as the request body: the JSON object of named
  /// arguments, or the value of a function's sole unnamed `json` or `jsonb`
  /// parameter, such as a list or a number.
  ///
  /// When [get] is set to `true`, the function will be called with read-only
  /// access mode, and [params] has to be a [Map] of named arguments or
  /// `null`.
  /// {@endtemplate}
  ///
  /// ```dart
  /// client.rpc('get_status', params: {'name_param': 'supabot'})
  /// ```
  PostgrestFilterBuilder<T> call<T>(
    String fn, {
    Object? params,
    bool get = false,
  }) =>
      // ignore: invalid_use_of_internal_member
      _client.rpcInSchema(fn, _schema, params: params, get: get);

  /// Calls [function] with [arguments] and reads the rows it returns through
  /// [rowFromJson].
  ///
  /// The result can be filtered, ordered and paged like the rows of a table,
  /// with the column tokens of the row type:
  ///
  /// ```dart
  /// final List<BooksRow> books = await client.rpc
  ///     .rows(
  ///       'search_books',
  ///       arguments: {'query': 'dart'},
  ///       rowFromJson: BooksRow.new,
  ///     )
  ///     .where(Books.id.gt(10));
  /// ```
  ///
  /// [arguments] is sent as the request body: the JSON object of named
  /// arguments, or the value of a function's sole unnamed `json` or `jsonb`
  /// parameter. The call addresses [schema] unless this object was scoped
  /// with [PostgrestClient.schema].
  ///
  /// When [get] is set, the function is called with a `GET` request in
  /// read-only access mode, so that it is retried like a select.
  /// [arguments] are then sent as query parameters, so they have to be a
  /// [Map] of values a query parameter can hold, and not rows or `json`. A
  /// call with an argument PostgREST would read as an option of the request,
  /// such as `limit`, a `null` value, or a value it would read as a filter,
  /// such as `eq.foo`, is sent as a `POST` instead and not retried.
  @experimental
  PostgrestTypedFilterBuilder<Row, List<Row>> rows<Row>(
    String function, {
    Object? arguments,
    required RowConverter<Row> rowFromJson,
    String? schema,
    bool get = false,
  }) => PostgrestTypedFilterBuilder._(
    _request(function, arguments, rowFromJson, schema, get),
    _executor ?? PostgrestHttpTableExecutor(_client),
    (result) => [
      for (final row in result.data! as List<dynamic>)
        rowFromJson(row as Map<String, dynamic>),
    ],
    rowFromJson,
  );

  /// Calls [function] with [arguments] and converts the response body, a
  /// scalar, a single row or a list of scalars, through [fromJson].
  ///
  /// ```dart
  /// final int? count = await client.rpc.value(
  ///   'count_books',
  ///   fromJson: (json) => json as int?,
  /// );
  /// ```
  ///
  /// See [rows] for [arguments], [schema] and [get].
  @experimental
  PostgrestTypedBuilder<T> value<T>(
    String function, {
    Object? arguments,
    required T Function(Object? json) fromJson,
    String? schema,
    bool get = false,
  }) => PostgrestTypedBuilder._(
    _request(
      function,
      arguments,
      _noRows,
      schema,
      get,
    ).copyWith(shape: PostgrestResultShape.value),
    _executor ?? PostgrestHttpTableExecutor(_client),
    (result) => fromJson(result.data),
  );

  PostgrestTableRequest _request<Row>(
    String function,
    Object? arguments,
    RowConverter<Row> rowFromJson,
    String? schema,
    bool get,
  ) {
    if (get && arguments is! Map?) {
      throw ArgumentError.value(
        arguments,
        'arguments',
        'A call with get set takes a map of named arguments',
      );
    }
    return PostgrestTableRequest(
      table: PostgrestTable<Row, Never, Never>(
        function,
        rowFromJson,
        primaryKey: const [],
      ),
      operation: PostgrestTableOperation.rpc,
      schema: _schemaIsExplicit ? _schema : (schema ?? _schema),
      payload: arguments,
      readOnly: get,
    );
  }
}

Never _noRows(Map<String, dynamic> json) =>
    throw StateError('A function call read as a value has no rows');
