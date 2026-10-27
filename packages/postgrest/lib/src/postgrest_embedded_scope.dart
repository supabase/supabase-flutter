part of 'postgrest_typed_builder.dart';

/// Filters, sort keys and a row window applied to the rows of one embed,
/// built in the callback of [PostgrestTypedTransformBuilder.embedded] or
/// [PostgrestTypedTransformBuilder.requiring].
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
///       (books) => books
///           .where(Books.title.ilike('%dune%'))
///           .order(Books.createdAt.desc())
///           .limit(1),
///     );
/// // books.title=ilike.%dune%&books.order=created_at.desc&books.limit=1
/// ```
///
/// The parameters are named after the embed, its alias when it has one, and
/// PostgREST rejects them for an embed the `select` list does not include.
@experimental
final class PostgrestEmbeddedScope<Row> {
  PostgrestEmbeddedScope._(
    this.relation, {
    this.requiresMatch = false,
    this.filter,
    List<PostgrestOrdering<Row>> orderings = const [],
    this.rowLimit,
    this.rowOffset,
    List<PostgrestEmbeddedScope<Object?>> scopes = const [],
  }) : orderings = List.unmodifiable(orderings),
       scopes = List.unmodifiable(scopes);

  /// The embed whose rows the scope applies to.
  final PostgrestRelation<Object?, Row> relation;

  /// Whether the parent rows without a matching embedded row are dropped,
  /// sent as `!inner` on the embed's `select` entry.
  final bool requiresMatch;

  /// The filter on the embedded rows, or `null` for every one of them.
  final PostgrestFilter<Row>? filter;

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
    PostgrestFilter<Row>? rowFilter,
    List<PostgrestOrdering<Row>>? sortKeys,
    int? limitCount,
    int? offsetCount,
    List<PostgrestEmbeddedScope<Object?>>? nested,
  }) => PostgrestEmbeddedScope._(
    relation,
    requiresMatch: requiresMatch,
    filter: rowFilter ?? filter,
    orderings: sortKeys ?? orderings,
    rowLimit: limitCount ?? rowLimit,
    rowOffset: offsetCount ?? rowOffset,
    scopes: nested ?? scopes,
  );

  /// Only the embedded rows satisfying [condition].
  ///
  /// The parent rows stay as they are, with an empty list or `null` where
  /// no embedded row matches, unless the scope was opened with `requiring`.
  /// [condition] can name a column the `select` list leaves out. Repeated
  /// calls combine with logical AND.
  PostgrestEmbeddedScope<Row> where(PostgrestFilter<Row> condition) {
    final current = filter;
    return _copyWith(
      rowFilter: current == null ? condition : current & condition,
    );
  }

  /// Sorts the embedded rows by [ordering].
  ///
  /// Repeated calls append, so the second key breaks ties in the first.
  /// Throws an [UnsupportedError] for a to-one embed, which has one row.
  PostgrestEmbeddedScope<Row> order(PostgrestOrdering<Row> ordering) {
    _checkToMany('order');
    return _copyWith(sortKeys: [...orderings, ordering]);
  }

  /// Limits the embedded rows of each parent row to [count].
  ///
  /// Throws an [UnsupportedError] for a to-one embed, which has one row.
  PostgrestEmbeddedScope<Row> limit(int count) {
    _checkToMany('limit');
    return _copyWith(limitCount: count);
  }

  /// Limits the embedded rows of each parent row to the ones within the
  /// specified range, inclusive.
  ///
  /// Throws an [ArgumentError] when [to] is less than [from], and an
  /// [UnsupportedError] for a to-one embed, which has one row.
  PostgrestEmbeddedScope<Row> range(int from, int to) {
    _checkToMany('range');
    checkPostgrestRange(from, to);
    return _copyWith(offsetCount: from, limitCount: to - from + 1);
  }

  /// Applies [scope] to the rows of [embed], an embed nested in this one,
  /// under a dotted path such as `books.reviews.limit=3`.
  PostgrestEmbeddedScope<Row> embedded<Target>(
    PostgrestRelation<Row, Target> embed,
    PostgrestEmbeddedScope<Target> Function(
      PostgrestEmbeddedScope<Target> scope,
    )
    scope,
  ) => _copyWith(
    nested: [...scopes, scope(PostgrestEmbeddedScope._(embed))],
  );

  /// The same as [embedded], and drops the rows of this embed that have no
  /// matching row in [embed].
  ///
  /// Only this embed's rows are dropped, not the top-level parent rows,
  /// unless this scope was opened with `requiring` as well.
  PostgrestEmbeddedScope<Row> requiring<Target>(
    PostgrestRelation<Row, Target> embed, [
    PostgrestEmbeddedScope<Target> Function(
      PostgrestEmbeddedScope<Target> scope,
    )?
    scope,
  ]) => _copyWith(
    nested: [...scopes, _requiringScope<Row, Target>(embed, scope)],
  );

  void _checkToMany(String method) {
    if (relation is PostgrestToOneRelation) {
      throw UnsupportedError(
        '$method() on the to-one embed `${relation.key}`, which has one row',
      );
    }
  }

  /// The filters, order keys, limit and offset of this scope and every
  /// nested one, each under the dotted path of its embed, with [prefix] in
  /// front.
  Iterable<_ScopedTransforms> _flattened([String prefix = '']) sync* {
    final path = '$prefix${relation._reference}';
    yield (
      path: path,
      filterParameters: filter?.queryParameters ?? const [],
      orderKeys: [for (final ordering in orderings) ordering.orderKey],
      limit: rowLimit,
      offset: rowOffset,
    );
    for (final scope in scopes) {
      yield* scope._flattened('$path.');
    }
  }
}

/// A scope on [relation] that drops the parent rows without a match, with
/// [scope] applied when given.
PostgrestEmbeddedScope<Target> _requiringScope<Row, Target>(
  PostgrestRelation<Row, Target> relation,
  PostgrestEmbeddedScope<Target> Function(
    PostgrestEmbeddedScope<Target> scope,
  )?
  scope,
) {
  final opened = PostgrestEmbeddedScope._(
    relation,
    requiresMatch: true,
  );
  return scope == null ? opened : scope(opened);
}

typedef _ScopedTransforms = ({
  String path,
  List<({String key, String value})> filterParameters,
  List<String> orderKeys,
  int? limit,
  int? offset,
});

/// The embeds the scopes of a request address, keyed by how each is spelled
/// in the `select` list, for adding `!inner` to the ones that require a
/// match and rejecting the ones the list leaves out.
final class _JoinTree {
  _JoinTree._();

  /// The tree of [scopes], or `null` when there are none, so the `select`
  /// list renders as it would without scopes.
  static _JoinTree? of(List<PostgrestEmbeddedScope<Object?>> scopes) =>
      scopes.isEmpty ? null : (_JoinTree._().._add(scopes));

  bool _requiresMatch = false;

  /// Whether the `select` list holds the embed, set as it is rendered.
  bool _rendered = false;

  /// The embeds a [PostgrestRelation.isNull] in a scope of this embed
  /// addresses.
  final Set<String> _filteredEmbeds = {};

  /// The embeds selected inside this embed, collected as it is rendered.
  final Set<String> _selectedEmbeds = {};

  final Map<String, _JoinTree> _children = {};

  void _add(List<PostgrestEmbeddedScope<Object?>> scopes) {
    for (final scope in scopes) {
      final child = _children.putIfAbsent(
        scope.relation._selectName,
        _JoinTree._,
      );
      child._requiresMatch |= scope.requiresMatch;
      child._filteredEmbeds.addAll(scope.filter?._embedReferences ?? const []);
      child._add(scope.scopes);
    }
  }

  /// The tree of the embed spelled [name], marked as rendered.
  _JoinTree? _render(String name) => _children[name]?.._rendered = true;

  /// How the embed spelled [name] is sent: with `!inner` after any foreign
  /// key hint when it requires a match.
  String _head(String name) => _requiresMatch ? '$name!inner' : name;

  /// Records the embeds among [members], the entries selected inside this
  /// embed.
  void _select(List<PostgrestSelectable<Object?>> members) {
    for (final member in members) {
      if (member case _Embedded(:final relation)) {
        _selectedEmbeds.add(relation._reference);
      }
    }
  }

  /// Throws an [ArgumentError] for a scope whose embed is not in the
  /// `select` list, which PostgREST rejects, or which for a `requiring`
  /// scope would leave the parent rows unfiltered, and for a
  /// [PostgrestRelation.isNull] in a scope on an embed not selected inside
  /// it.
  void checkRendered([String prefix = '']) {
    for (final MapEntry(key: name, value: child) in _children.entries) {
      final path = '$prefix$name';
      if (!child._rendered) {
        throw ArgumentError.value(
          path,
          'relation',
          'The embed is not in the select list',
        );
      }
      for (final reference in child._filteredEmbeds) {
        if (!child._selectedEmbeds.contains(reference)) {
          throw ArgumentError.value(
            '$path.$reference',
            'filter',
            'The relation is not in the select list',
          );
        }
      }
      child.checkRendered('$path.');
    }
  }
}
