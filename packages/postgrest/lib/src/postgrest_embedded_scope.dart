part of 'postgrest_typed_builder.dart';

/// Sort keys and a row window applied to the rows of one to-many embed,
/// built in the callback of [PostgrestTypedTransformBuilder.embedded].
///
/// Everything here applies per parent row and targets the embedded table,
/// whose rows are [Row], so a column of another table does not compile:
///
/// ```dart
/// await client
///     .table(Authors.table)
///     .selectOnly([Authors.name, Authors.books.select([Books.title])])
///     .embedded(
///       Authors.books,
///       (books) => books.order(Books.createdAt.desc()).limit(1),
///     );
/// // books.order=created_at.desc&books.limit=1
/// ```
///
/// The parameters are named after the embed, its alias when it has one, and
/// PostgREST rejects them for an embed the `select` list does not include.
@experimental
final class PostgrestEmbeddedScope<Row> {
  PostgrestEmbeddedScope._(
    this.relation, {
    List<PostgrestOrdering<Row>> orderings = const [],
    this.rowLimit,
    this.rowOffset,
    List<PostgrestEmbeddedScope<Object?>> scopes = const [],
  }) : orderings = List.unmodifiable(orderings),
       scopes = List.unmodifiable(scopes);

  /// The embed whose rows the scope applies to.
  final PostgrestToManyRelation<Object?, Row> relation;

  /// The sort keys of the embedded rows, first key first.
  final List<PostgrestOrdering<Row>> orderings;

  /// The maximum number of embedded rows per parent row, set by [limit] and
  /// [range].
  final int? rowLimit;

  /// The number of embedded rows to skip per parent row, set by [range].
  final int? rowOffset;

  /// The scopes of embeds nested in this one.
  final List<PostgrestEmbeddedScope<Object?>> scopes;

  PostgrestEmbeddedScope<Row> _copyWith({
    List<PostgrestOrdering<Row>>? sortKeys,
    int? limitCount,
    int? offsetCount,
    List<PostgrestEmbeddedScope<Object?>>? nested,
  }) => PostgrestEmbeddedScope._(
    relation,
    orderings: sortKeys ?? orderings,
    rowLimit: limitCount ?? rowLimit,
    rowOffset: offsetCount ?? rowOffset,
    scopes: nested ?? scopes,
  );

  /// Sorts the embedded rows by [ordering].
  ///
  /// Repeated calls append, so the second key breaks ties in the first.
  PostgrestEmbeddedScope<Row> order(PostgrestOrdering<Row> ordering) =>
      _copyWith(sortKeys: [...orderings, ordering]);

  /// Limits the embedded rows of each parent row to [count].
  PostgrestEmbeddedScope<Row> limit(int count) => _copyWith(limitCount: count);

  /// Limits the embedded rows of each parent row to the ones within the
  /// specified range, inclusive.
  PostgrestEmbeddedScope<Row> range(int from, int to) =>
      _copyWith(offsetCount: from, limitCount: to - from + 1);

  /// Applies [scope] to the rows of [embed], an embed nested in this one,
  /// under a dotted path such as `books.reviews.limit=3`.
  PostgrestEmbeddedScope<Row> embedded<Target>(
    PostgrestToManyRelation<Row, Target> embed,
    PostgrestEmbeddedScope<Target> Function(
      PostgrestEmbeddedScope<Target> scope,
    )
    scope,
  ) => _copyWith(
    nested: [...scopes, scope(PostgrestEmbeddedScope._(embed))],
  );

  /// The order keys, limit and offset of this scope and every nested one,
  /// each under the dotted path of its embed, with [prefix] in front.
  Iterable<_ScopedTransforms> _flattened([String prefix = '']) sync* {
    final path = '$prefix${relation._reference}';
    yield (
      path: path,
      orderKeys: [for (final ordering in orderings) ordering.orderKey],
      limit: rowLimit,
      offset: rowOffset,
    );
    for (final scope in scopes) {
      yield* scope._flattened('$path.');
    }
  }
}

typedef _ScopedTransforms = ({
  String path,
  List<String> orderKeys,
  int? limit,
  int? offset,
});
