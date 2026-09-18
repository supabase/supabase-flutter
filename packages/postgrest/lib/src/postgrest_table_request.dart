part of 'postgrest_typed_builder.dart';

/// The database operation a [PostgrestTableRequest] performs.
@experimental
enum PostgrestTableOperation {
  /// Reads rows.
  select,

  /// Inserts the payload rows.
  insert,

  /// Inserts the payload rows, merging or skipping the ones that conflict.
  upsert,

  /// Updates the matching rows with the payload.
  update,

  /// Deletes the matching rows.
  delete,

  /// Counts the matching rows without reading them.
  count;

  /// Whether the operation writes to the table.
  bool get isMutation => switch (this) {
    select || count => false,
    insert || upsert || update || delete => true,
  };
}

/// The form a [PostgrestTableRequest] asks its result back in.
@experimental
enum PostgrestResultShape {
  /// Every matching row.
  rows,

  /// Exactly one row; anything else is an error.
  single,

  /// At most one row, or nothing.
  maybeSingle,

  /// No rows; the request runs for its effect only.
  none,

  /// No rows and no body, a `HEAD` request.
  head,

  /// The rows rendered as csv text.
  csv,

  /// The rows as one GeoJSON object.
  geojson,

  /// The query plan instead of the rows.
  explain,
}

/// A `limit` or `range` applied to an embedded relation rather than to the
/// table itself.
@experimental
final class PostgrestEmbeddedPage {
  const PostgrestEmbeddedPage(this.referencedTable, {this.limit, this.offset});

  /// The embedded relation the page applies to.
  final String referencedTable;

  /// The maximum number of embedded rows.
  final int? limit;

  /// The number of embedded rows to skip.
  final int? offset;
}

/// The options of a [PostgrestResultShape.explain] request, see
/// [PostgrestTransformBuilder.explain].
@experimental
final class PostgrestExplainOptions {
  const PostgrestExplainOptions({
    this.analyze = false,
    this.verbose = false,
    this.settings = false,
    this.buffers = false,
    this.wal = false,
    this.format = ExplainFormat.text,
  });

  /// Runs the query and reports actual run times.
  final bool analyze;

  /// Includes additional plan detail.
  final bool verbose;

  /// Includes the configuration parameters that affect the plan.
  final bool settings;

  /// Includes buffer usage.
  final bool buffers;

  /// Includes write-ahead log usage.
  final bool wal;

  /// The output format of the plan.
  final ExplainFormat format;
}

/// Everything a typed table builder has collected, ready to be run by a
/// [PostgrestTableExecutor].
///
/// The value is immutable: every builder method returns a copy through
/// [copyWith]. [PostgrestHttpTableExecutor] renders it into the PostgREST
/// request the untyped builders would have sent; another executor can run it
/// anywhere
/// else, against a local store for example, because the filters, orderings
/// and payload are still structured values rather than URL text.
@experimental
final class PostgrestTableRequest {
  const PostgrestTableRequest({
    required this.table,
    required this.operation,
    this.schema,
    this.columns,
    this.filter,
    this.orderings = const [],
    this.limit,
    this.offset,
    this.embeddedPages = const [],
    this.shape = PostgrestResultShape.rows,
    this.countOption,
    this.payload,
    this.onConflict,
    this.ignoreDuplicates = false,
    this.defaultToNull = true,
    this.maxAffected,
    this.stripNulls = false,
    this.dryRun = false,
    this.explainOptions,
  });

  /// The table the request addresses.
  final PostgrestTable<Object?, Object?, Object?> table;

  /// What the request does to [table].
  final PostgrestTableOperation operation;

  /// The database schema of [table], or `null` for the client default.
  final String? schema;

  /// The expressions to read back, or `null` for every column.
  ///
  /// For a mutation these are the columns of the returned rows, and only
  /// apply when [shape] is not [PostgrestResultShape.none].
  final List<PostgrestColumnExpression<Object?, Object>>? columns;

  /// The rows to act on, or `null` for every row.
  final PostgrestFilter<Object?>? filter;

  /// The sort keys, first key first.
  final List<PostgrestOrdering<Object?>> orderings;

  /// The maximum number of rows to return.
  final int? limit;

  /// The number of rows to skip.
  final int? offset;

  /// Limits and offsets applied to embedded relations.
  final List<PostgrestEmbeddedPage> embeddedPages;

  /// The form the result is asked back in.
  final PostgrestResultShape shape;

  /// The count to compute next to the result, or `null` for none.
  ///
  /// For [PostgrestTableOperation.count] this is the count algorithm, and
  /// `null` means exact.
  final CountOption? countOption;

  /// The rows a mutation sends: one JSON object, or a list of them.
  final Object? payload;

  /// The columns of the unique constraint an upsert merges on, or `null` for
  /// the primary key.
  final List<PostgrestColumn<Object?, Object>>? onConflict;

  /// Whether an upsert skips conflicting rows instead of merging them.
  final bool ignoreDuplicates;

  /// Whether columns missing from an insert payload become `null` rather
  /// than their database default.
  final bool defaultToNull;

  /// The maximum number of rows a mutation may affect.
  final int? maxAffected;

  /// Whether `null` values are omitted from the returned rows.
  final bool stripNulls;

  /// Whether the transaction is rolled back after the request.
  final bool dryRun;

  /// The options of an explain request.
  final PostgrestExplainOptions? explainOptions;

  /// Whether the request returns rows.
  bool get returnsRows => switch (shape) {
    PostgrestResultShape.rows ||
    PostgrestResultShape.single ||
    PostgrestResultShape.maybeSingle => true,
    PostgrestResultShape.none ||
    PostgrestResultShape.head ||
    PostgrestResultShape.csv ||
    PostgrestResultShape.geojson ||
    PostgrestResultShape.explain => false,
  };

  /// A copy with the given fields replaced.
  PostgrestTableRequest copyWith({
    PostgrestTable<Object?, Object?, Object?>? table,
    PostgrestTableOperation? operation,
    String? schema,
    List<PostgrestColumnExpression<Object?, Object>>? columns,
    PostgrestFilter<Object?>? filter,
    List<PostgrestOrdering<Object?>>? orderings,
    int? limit,
    int? offset,
    List<PostgrestEmbeddedPage>? embeddedPages,
    PostgrestResultShape? shape,
    CountOption? countOption,
    Object? payload,
    List<PostgrestColumn<Object?, Object>>? onConflict,
    bool? ignoreDuplicates,
    bool? defaultToNull,
    int? maxAffected,
    bool? stripNulls,
    bool? dryRun,
    PostgrestExplainOptions? explainOptions,
  }) => PostgrestTableRequest(
    table: table ?? this.table,
    operation: operation ?? this.operation,
    schema: schema ?? this.schema,
    columns: columns ?? this.columns,
    filter: filter ?? this.filter,
    orderings: orderings ?? this.orderings,
    limit: limit ?? this.limit,
    offset: offset ?? this.offset,
    embeddedPages: embeddedPages ?? this.embeddedPages,
    shape: shape ?? this.shape,
    countOption: countOption ?? this.countOption,
    payload: payload ?? this.payload,
    onConflict: onConflict ?? this.onConflict,
    ignoreDuplicates: ignoreDuplicates ?? this.ignoreDuplicates,
    defaultToNull: defaultToNull ?? this.defaultToNull,
    maxAffected: maxAffected ?? this.maxAffected,
    stripNulls: stripNulls ?? this.stripNulls,
    dryRun: dryRun ?? this.dryRun,
    explainOptions: explainOptions ?? this.explainOptions,
  );
}

/// What a [PostgrestTableExecutor] produced for a [PostgrestTableRequest].
///
/// [data] follows the request's [PostgrestTableRequest.shape]: a
/// `List<Map<String, dynamic>>` for rows, a `Map<String, dynamic>` (or
/// `null`) for a single row, a `String` for csv and explain, a
/// `Map<String, dynamic>` for GeoJSON, and `null` when nothing was asked
/// back. The typed builder converts it into the table's row type.
@experimental
final class PostgrestTableResult {
  const PostgrestTableResult({this.data, this.count});

  /// The decoded result, shaped as described on the class.
  final Object? data;

  /// The row count, when the request asked for one.
  final int? count;
}
