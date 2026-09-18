part of 'postgrest_typed_builder.dart';

/// A foreign key seen from the table whose rows are [Row], pointing at the
/// table whose rows are [Target].
///
/// [columns] are on this table and [referencedColumns] on [referencedTable],
/// paired by index: the embedded rows are the rows of [referencedTable]
/// whose [referencedColumns] equal this row's [columns]. A to-one relation
/// holds the key itself, a to-many relation is pointed at by it.
///
/// `package:supabase_typegen` generates one relation constant per foreign
/// key on each side and lists them in [PostgrestTable.relations].
@experimental
sealed class PostgrestRelation<Row, Target> {
  const PostgrestRelation(
    this.name, {
    required this.columns,
    required this.referencedTable,
    required this.referencedColumns,
  });

  /// The name PostgREST addresses the embed by, including any disambiguating
  /// foreign key hint such as `authors!books_author_id_fkey`.
  final String name;

  /// The columns of this table the relation joins on.
  final List<PostgrestColumn<Row, Object>> columns;

  /// The name of the table the relation points at.
  final String referencedTable;

  /// The columns of [referencedTable] the relation joins on, paired with
  /// [columns] by index.
  final List<PostgrestColumn<Target, Object>> referencedColumns;
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
    extends PostgrestRelation<Row, Target> {
  const PostgrestToOneRelation(
    super.name, {
    required super.columns,
    required super.referencedTable,
    required super.referencedColumns,
  });

  /// Projects [column] of the embedded table into the parent's frame.
  PostgrestToOneColumn<Row, Value> call<Value extends Object>(
    PostgrestColumnExpression<Target, Value> column,
  ) => PostgrestToOneColumn._(this, column.expression);
}

/// A to-many embedded relation (one-to-many or many-to-many) of the table
/// whose rows are [Row], pointing at the table whose rows are [Target].
///
/// Its projections are select position only: PostgREST answers
/// `order=children(amount).desc` with PGRST118.
@experimental
final class PostgrestToManyRelation<Row, Target>
    extends PostgrestRelation<Row, Target> {
  const PostgrestToManyRelation(
    super.name, {
    required super.columns,
    required super.referencedTable,
    required super.referencedColumns,
  });

  /// Projects [column] of the embedded table into the parent's frame.
  PostgrestToManyColumn<Row, Value> call<Value extends Object>(
    PostgrestColumnExpression<Target, Value> column,
  ) => PostgrestToManyColumn._(this, column.expression);
}

/// A column of an embedded relation, seen from the parent.
sealed class _EmbeddedColumn<Row, Value extends Object>
    extends PostgrestColumnExpression<Row, Value> {
  const _EmbeddedColumn(this.relation, this._inner) : super._();

  /// The relation the column is projected through.
  final PostgrestRelation<Row, Object?> relation;

  final String _inner;

  /// The `select` list form, `parent(title)`.
  @override
  String get expression => '${relation.name}($_inner)';

  /// The filter form, `parent.title`.
  String get embeddedFilterName => '${relation.name}.$_inner';

  /// Places the derivation inside the embed's parentheses, where PostgREST
  /// applies it.
  @override
  PostgrestDerivedExpression<Row, Derived> _derive<Derived extends Object>(
    String derivation,
  ) => PostgrestDerivedExpression._(
    embed: relation.name,
    inner: '$_inner$derivation',
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
      PostgrestToOneColumn._(relation, '$_inner->>$path');

  @override
  PostgrestToOneColumn<Row, Value> jsonObject(String path) =>
      PostgrestToOneColumn._(relation, '$_inner->$path');
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
      PostgrestToManyColumn._(relation, '$_inner->>$path');

  @override
  PostgrestToManyColumn<Row, Value> jsonObject(String path) =>
      PostgrestToManyColumn._(relation, '$_inner->$path');
}
