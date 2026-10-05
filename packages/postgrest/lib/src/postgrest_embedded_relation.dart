part of 'postgrest_typed_builder.dart';

/// A foreign key seen from the table whose rows are [Row], pointing at the
/// table whose rows are [Target].
///
/// [columns] are on this table and [referencedColumns] on [referencedTable],
/// paired by index: the embedded rows are the rows of [referencedTable]
/// whose [referencedColumns] equal this row's [columns]. A to-one relation
/// holds the key itself, a to-many relation is pointed at by it.
///
/// A relation is put into a `select` list either column by column, by
/// calling it with a column of [Target], or as a whole with [select]. Entries
/// of the same relation in one list are sent as a single embed, so
/// `[Books.author(Authors.id), Books.author(Authors.name)]` renders
/// `author(id,name)`. The embedded rows come back under [key] in the parent
/// row.
///
/// The embedded rows are read from a [PostgrestPartialRow] through the
/// relation, as a nested partial row of [Target] for a
/// [PostgrestToOneRelation] and a list of them for a
/// [PostgrestToManyRelation]:
///
/// ```dart
/// final book = await client
///     .table(Books.table)
///     .selectOnly([Books.id, Books.author.select([Authors.name])])
///     .single();
/// final String? authorName = book.read(Books.author)?.read(Authors.name);
/// ```
///
/// A computed relationship, a function whose only argument is this table's
/// row type and that returns rows of [referencedTable], embeds the same way
/// and is declared with [PostgrestToOneRelation.computed] or
/// [PostgrestToManyRelation.computed]. It joins on no key, so [columns] and
/// [referencedColumns] are empty, and the function name is both the embed
/// name and the key the rows come back under.
///
/// `package:supabase_typegen` generates one relation constant per foreign
/// key on each side and per computed relationship, and lists them in
/// [PostgrestTable.relations].
@experimental
sealed class PostgrestRelation<Row, Target> {
  const PostgrestRelation(
    this.name, {
    required this.columns,
    required this.referencedTable,
    required this.referencedColumns,
    this.alias,
  });

  /// A computed relationship through the function called [name], returning
  /// rows of [referencedTable].
  const PostgrestRelation.computed(
    this.name, {
    required this.referencedTable,
    this.alias,
  }) : columns = const [],
       referencedColumns = const [];

  /// The name PostgREST addresses the embed by: the table name, including
  /// any disambiguating foreign key hint such as
  /// `authors!books_author_id_fkey`, or the function name of a computed
  /// relationship.
  final String name;

  /// The name the embed is renamed to, `alias:authors!books_author_id_fkey`
  /// in the `select` list, or `null` to keep the table name.
  ///
  /// Two hinted embeds of one table both come back under the table name, so
  /// each needs an alias to be told apart. An aliased embed is addressed by
  /// the alias in `order` and in a filter, which the rendering takes care of.
  final String? alias;

  /// The key the embedded rows come back under in the parent row: [alias]
  /// when set, otherwise the table or function name in [name].
  String get key => alias ?? name.split('!').first;

  /// The same as [key]: where the embedded rows are read from.
  String get responseKey => key;

  /// The partial rows of [Target] under [json], the embedded object or list
  /// as decoded, shaped by [nested].
  List<PostgrestPartialRow<Target>> _partialRows(
    Iterable<Object?> json,
    _NestedSelection nested,
  ) => [
    for (final row in json)
      PostgrestPartialRow<Target>._(
        row as Map<String, dynamic>,
        nested.selections,
        allColumns: nested.allColumns,
      ),
  ];

  /// How the embed is spelled in the `select` list.
  String get _selectName => alias == null ? name : '$alias:$name';

  /// How the embed is addressed outside the `select` list.
  String get _reference => alias ?? name;

  /// The columns of this table the relation joins on; empty for a computed
  /// relationship.
  final List<PostgrestStoredColumn<Row, Object>> columns;

  /// The name of the table the relation points at.
  final String referencedTable;

  /// The columns of [referencedTable] the relation joins on, paired with
  /// [columns] by index; empty for a computed relationship.
  final List<PostgrestStoredColumn<Target, Object>> referencedColumns;

  /// Selects the embedded table as a whole: [selections] of it, or every
  /// column when none are given.
  ///
  /// ```dart
  /// Books.author.select([Authors.id, Authors.name]) // author(id,name)
  /// Books.author.select()                           // author(*)
  /// ```
  ///
  /// [selections] can hold embeds of their own, so
  /// `Books.author.select([Authors.id, Authors.publisher.select()])` renders
  /// `author(id,publisher(*))`. An empty list is rejected; leave [selections]
  /// out to select every column.
  PostgrestEmbed<Row, Target> select([
    List<PostgrestSelectable<Target>>? selections,
  ]);
}

/// A to-one embedded relation (many-to-one or one-to-one) of the table whose
/// rows are [Row], pointing at the table whose rows are [Target].
///
/// Calling it with a column of the target projects that column into the
/// parent's `select` list:
///
/// ```dart
/// class Orders {
///   static const todoId = PostgrestColumn<Order, int>('todo_id');
///   static const todo = PostgrestToOneRelation<Order, Todo>(
///     'todo',
///     columns: [todoId],
///     referencedTable: 'todos',
///     referencedColumns: [Todos.id],
///   );
/// }
///
/// Orders.todo(Todos.title).expression // todo(title)
/// ```
///
/// Projections of a to-one embed can be ordered by, unlike those of a
/// [PostgrestToManyRelation].
@experimental
final class PostgrestToOneRelation<Row, Target>
    extends PostgrestRelation<Row, Target>
    implements PostgrestReadable<Row, PostgrestPartialRow<Target>?> {
  const PostgrestToOneRelation(
    super.name, {
    required super.columns,
    required super.referencedTable,
    required super.referencedColumns,
    super.alias,
  });

  /// A to-one computed relationship: the function called [name] takes a row
  /// of this table and returns one row of [referencedTable], either a single
  /// row or a set declared `ROWS 1`.
  ///
  /// ```dart
  /// class Channels {
  ///   static const latestMessage =
  ///       PostgrestToOneRelation<ChannelsRow, MessagesRow>.computed(
  ///         'latest_message',
  ///         referencedTable: 'messages',
  ///       );
  /// }
  ///
  /// Channels.latestMessage.select().expression // latest_message(*)
  /// ```
  const PostgrestToOneRelation.computed(
    super.name, {
    required super.referencedTable,
    super.alias,
  }) : super.computed();

  /// Projects [column] of the embedded table into the parent's frame.
  PostgrestToOneColumn<Row, Value> call<Value extends Object>(
    PostgrestColumnExpression<Target, Value> column,
  ) => PostgrestToOneColumn._(this, column);

  @override
  PostgrestToOneEmbed<Row, Target> select([
    List<PostgrestSelectable<Target>>? selections,
  ]) =>
      PostgrestToOneEmbed._(this, _checkedSelections(selections, 'selections'));

  @override
  PostgrestPartialRow<Target>? _read(Object? json, _NestedSelection nested) =>
      json == null ? null : _partialRows([json], nested).single;

  @override
  bool get _selectedByStar => false;
}

/// A to-many embedded relation (one-to-many or many-to-many) of the table
/// whose rows are [Row], pointing at the table whose rows are [Target].
///
/// Its projections are select position only: PostgREST answers
/// `order=children(amount).desc` with PGRST118.
@experimental
final class PostgrestToManyRelation<Row, Target>
    extends PostgrestRelation<Row, Target>
    implements PostgrestReadable<Row, List<PostgrestPartialRow<Target>>> {
  const PostgrestToManyRelation(
    super.name, {
    required super.columns,
    required super.referencedTable,
    required super.referencedColumns,
    super.alias,
  });

  /// A to-many computed relationship: the function called [name] takes a row
  /// of this table and returns a set of rows of [referencedTable].
  ///
  /// ```dart
  /// class Channels {
  ///   static const recentMessages =
  ///       PostgrestToManyRelation<ChannelsRow, MessagesRow>.computed(
  ///         'recent_messages',
  ///         referencedTable: 'messages',
  ///       );
  /// }
  ///
  /// Channels.recentMessages(Messages.id).expression // recent_messages(id)
  /// ```
  const PostgrestToManyRelation.computed(
    super.name, {
    required super.referencedTable,
    super.alias,
  }) : super.computed();

  /// Projects [column] of the embedded table into the parent's frame.
  PostgrestToManyColumn<Row, Value> call<Value extends Object>(
    PostgrestColumnExpression<Target, Value> column,
  ) => PostgrestToManyColumn._(this, column);

  @override
  PostgrestToManyEmbed<Row, Target> select([
    List<PostgrestSelectable<Target>>? selections,
  ]) => PostgrestToManyEmbed._(
    this,
    _checkedSelections(selections, 'selections'),
  );

  @override
  List<PostgrestPartialRow<Target>> _read(
    Object? json,
    _NestedSelection nested,
  ) => _partialRows(json as List<Object?>, nested);

  @override
  bool get _selectedByStar => false;
}

/// A `select` entry that goes through a relation: it renders as that
/// relation's embed, and entries of one relation in the same list are
/// rendered as a single embed.
base mixin _Embedded<Row> on PostgrestSelectable<Row> {
  /// The relation the entry is projected through.
  PostgrestRelation<Row, Object?> get relation;

  /// What goes inside the parentheses; empty for every column, `*`.
  List<PostgrestSelectable<Object?>> get _selections;

  @override
  String get expression => _embedExpression(relation._selectName, _selections);

  @override
  String get responseKey => relation.key;

  /// The filter form, `parent.title`, dotted through every level of a
  /// nested projection.
  String get _filterName {
    final inner = _selections.single;
    final innerName = inner is _Embedded<Object?>
        ? inner._filterName
        : inner.expression;
    return '${relation._reference}.$innerName';
  }
}

/// An embedded relation selected as a whole into the parent's `select` list:
/// some entries of the embedded table, or every column of it.
///
/// Created by [PostgrestRelation.select]. Select position only: a whole embed
/// is neither an order key nor a filter operand, and PostgREST applies no
/// cast, JSON path or aggregate to one. The embedded rows come back under
/// [PostgrestRelation.key] in the parent row, one object for a
/// [PostgrestToOneEmbed] and a list for a [PostgrestToManyEmbed], and are
/// read from a [PostgrestPartialRow] through the relation.
@experimental
sealed class PostgrestEmbed<Row, Target> extends PostgrestSelectable<Row>
    with _Embedded<Row> {
  PostgrestEmbed._(this.relation, List<PostgrestSelectable<Target>> selections)
    : selections = List.unmodifiable(selections),
      super._();

  /// The relation the embed goes through.
  @override
  final PostgrestRelation<Row, Target> relation;

  /// The entries selected of the embedded table; empty for every column.
  final List<PostgrestSelectable<Target>> selections;

  @override
  List<PostgrestSelectable<Object?>> get _selections => selections;

  @override
  String get _filterName => relation._reference;
}

/// A to-one relation selected as a whole, `author(id,name)`.
///
/// The parent row carries one embedded object, or `null` when the key is
/// `NULL` or points at no row.
@experimental
final class PostgrestToOneEmbed<Row, Target>
    extends PostgrestEmbed<Row, Target> {
  PostgrestToOneEmbed._(super.relation, super.selections) : super._();
}

/// A to-many relation selected as a whole, `books(id,title)`.
///
/// The parent row carries a list of embedded objects, empty when no row
/// points at it.
@experimental
final class PostgrestToManyEmbed<Row, Target>
    extends PostgrestEmbed<Row, Target> {
  PostgrestToManyEmbed._(super.relation, super.selections) : super._();
}

/// A column of an embedded relation, seen from the parent.
///
/// A single-column embed: renders and merges the same way a
/// [PostgrestEmbed] with one selection does, and on top of that keeps the
/// column's [Value] so it can be derived from or, for a to-one relation,
/// ordered by. It is read through its relation, like every embedded entry.
sealed class _EmbeddedColumn<Row, Value extends Object>
    extends PostgrestColumnExpression<Row, Value>
    with _Embedded<Row> {
  const _EmbeddedColumn(this.relation, this._inner) : super._();

  /// The relation the column is projected through.
  @override
  final PostgrestRelation<Row, Object?> relation;

  final PostgrestColumnExpression<Object?, Value> _inner;

  @override
  List<PostgrestSelectable<Object?>> get _selections => [_inner];

  @override
  Value Function(Object json)? get _fromJson => _inner._fromJson;

  @override
  String? get _castKey => _inner._castKey;

  /// The filter form, `parent.title`, dotted through every level of a
  /// nested projection.
  String get embeddedFilterName => _filterName;

  /// The `order` form, `parent(title)`, addressing an aliased embed by its
  /// alias.
  @override
  String get _orderKey => '${relation._reference}(${_inner._orderKey})';

  /// Places the derivation on the projected column, inside the embed's
  /// parentheses, where PostgREST applies it.
  @override
  PostgrestDerivedExpression<Row, Derived> _derive<Derived extends Object>(
    String derivation, {
    required String? key,
    required Derived Function(Object json)? fromJson,
  }) => _EmbeddedDerivation._(
    relation,
    _inner._derive(derivation, key: key, fromJson: fromJson),
  );
}

/// A column of a to-one embedded relation, seen from the parent.
///
/// Selectable and orderable; filtering inside an embed is not supported.
@experimental
final class PostgrestToOneColumn<Row, Value extends Object>
    extends _EmbeddedColumn<Row, Value>
    with PostgrestOrderableExpression<Row, Value> {
  const PostgrestToOneColumn._(super.relation, super.inner);

  @override
  PostgrestToOneColumn<Row, String> jsonText(String path) =>
      PostgrestToOneColumn._(relation, _inner.jsonText(path));

  @override
  PostgrestToOneColumn<Row, Value> jsonObject(String path) =>
      PostgrestToOneColumn._(relation, _inner.jsonObject(path));
}

/// A column of a to-many embedded relation, seen from the parent.
///
/// Select position only: PostgREST rejects a to-many embed in `order`, and
/// filtering inside an embed is not supported.
@experimental
final class PostgrestToManyColumn<Row, Value extends Object>
    extends _EmbeddedColumn<Row, Value> {
  const PostgrestToManyColumn._(super.relation, super.inner);

  @override
  PostgrestToManyColumn<Row, String> jsonText(String path) =>
      PostgrestToManyColumn._(relation, _inner.jsonText(path));

  @override
  PostgrestToManyColumn<Row, Value> jsonObject(String path) =>
      PostgrestToManyColumn._(relation, _inner.jsonObject(path));
}
