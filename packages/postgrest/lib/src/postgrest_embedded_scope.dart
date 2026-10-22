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
    this._relation, {
    List<PostgrestOrdering<Row>> orderings = const [],
    int? limit,
    int? offset,
    List<PostgrestEmbeddedScope<Object?>> scopes = const [],
  }) : _orderings = List.unmodifiable(orderings),
       _limit = limit,
       _offset = offset,
       _scopes = List.unmodifiable(scopes);

  final PostgrestToManyRelation<Object?, Row> _relation;
  final List<PostgrestOrdering<Row>> _orderings;
  final int? _limit;
  final int? _offset;
  final List<PostgrestEmbeddedScope<Object?>> _scopes;

  PostgrestEmbeddedScope<Row> _copyWith({
    List<PostgrestOrdering<Row>>? orderings,
    int? limit,
    int? offset,
    List<PostgrestEmbeddedScope<Object?>>? scopes,
  }) => PostgrestEmbeddedScope._(
    _relation,
    orderings: orderings ?? _orderings,
    limit: limit ?? _limit,
    offset: offset ?? _offset,
    scopes: scopes ?? _scopes,
  );

  /// Sorts the embedded rows by [ordering].
  ///
  /// Repeated calls append, so the second key breaks ties in the first.
  PostgrestEmbeddedScope<Row> order(PostgrestOrdering<Row> ordering) =>
      _copyWith(orderings: [..._orderings, ordering]);

  /// Limits the embedded rows of each parent row to [count].
  PostgrestEmbeddedScope<Row> limit(int count) => _copyWith(limit: count);

  /// Limits the embedded rows of each parent row to the ones within the
  /// specified range, inclusive.
  ///
  /// Throws an [ArgumentError] when [to] is less than [from].
  PostgrestEmbeddedScope<Row> range(int from, int to) {
    checkPostgrestRange(from, to);
    return _copyWith(offset: from, limit: to - from + 1);
  }

  /// Applies [scope] to the rows of [relation], an embed nested in this one,
  /// under a dotted path such as `books.reviews.limit=3`.
  PostgrestEmbeddedScope<Row> embedded<Target>(
    PostgrestToManyRelation<Row, Target> relation,
    PostgrestEmbeddedScope<Target> Function(
      PostgrestEmbeddedScope<Target> scope,
    )
    scope,
  ) => _copyWith(
    scopes: [..._scopes, scope(PostgrestEmbeddedScope._(relation))],
  );

  /// The order keys, limit and offset of this scope and every nested one,
  /// each under the dotted path of its embed, with [prefix] in front.
  Iterable<_ScopedTransforms> _flattened([String prefix = '']) sync* {
    final path = '$prefix${_relation._reference}';
    yield (
      path: path,
      orderKeys: [for (final ordering in _orderings) ordering.orderKey],
      limit: _limit,
      offset: _offset,
    );
    for (final scope in _scopes) {
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
