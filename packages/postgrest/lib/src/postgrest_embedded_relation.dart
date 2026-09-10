part of 'postgrest_typed_builder.dart';

/// A to-one embedded relation (many-to-one or one-to-one) of the table whose
/// rows are [Row], pointing at the table whose rows are [Target].
///
/// Calling it with a column of the target projects that column into the
/// parent's `select` list:
///
/// ```dart
/// class Orders {
///   static const todo = PostgrestToOneRelation<Order, Todo>('todo');
/// }
///
/// Orders.todo(Todos.title).expression // todo(title)
/// ```
///
/// Projections of a to-one embed can be ordered by, unlike those of a
/// [PostgrestToManyRelation].
@experimental
final class PostgrestToOneRelation<Row, Target> {
  /// Creates a relation PostgREST addresses as [name], including any
  /// disambiguating foreign key hint such as `authors!books_author_id_fkey`.
  const PostgrestToOneRelation(this.name);

  /// The name PostgREST addresses the embed by.
  final String name;

  /// Projects [column] of the embedded table into the parent's frame.
  PostgrestToOneColumn<Row, Value> call<Value extends Object>(
    PostgrestColumnExpression<Target, Value> column,
  ) => PostgrestToOneColumn._(name, column.expression);
}

/// A to-many embedded relation (one-to-many or many-to-many) of the table
/// whose rows are [Row], pointing at the table whose rows are [Target].
///
/// Its projections are select position only: PostgREST answers
/// `order=children(amount).desc` with PGRST118.
@experimental
final class PostgrestToManyRelation<Row, Target> {
  /// Creates a relation PostgREST addresses as [name], including any
  /// disambiguating foreign key hint.
  const PostgrestToManyRelation(this.name);

  /// The name PostgREST addresses the embed by.
  final String name;

  /// Projects [column] of the embedded table into the parent's frame.
  PostgrestToManyColumn<Row, Value> call<Value extends Object>(
    PostgrestColumnExpression<Target, Value> column,
  ) => PostgrestToManyColumn._(name, column.expression);
}

/// A column of an embedded relation, seen from the parent.
sealed class _EmbeddedColumn<Row, Value extends Object>
    extends PostgrestColumnExpression<Row, Value> {
  const _EmbeddedColumn(this._embed, this._inner) : super._();

  final String _embed;
  final String _inner;

  /// The `select` list form, `parent(title)`.
  @override
  String get expression => '$_embed($_inner)';

  /// The filter form, `parent.title`.
  String get embeddedFilterName => '$_embed.$_inner';

  /// Places the derivation inside the embed's parentheses, where PostgREST
  /// applies it.
  @override
  PostgrestDerivedExpression<Row, Derived> _derive<Derived extends Object>(
    String derivation,
  ) => PostgrestDerivedExpression._(
    embed: _embed,
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
  const PostgrestToOneColumn._(super.embed, super.inner);

  @override
  PostgrestToOneColumn<Row, String> jsonText(String path) =>
      PostgrestToOneColumn._(_embed, '$_inner->>$path');

  @override
  PostgrestToOneColumn<Row, Value> jsonObject(String path) =>
      PostgrestToOneColumn._(_embed, '$_inner->$path');
}

/// A column of a to-many embedded relation, seen from the parent.
///
/// Select position only: PostgREST rejects a to-many embed in `order`, and
/// filtering inside an embed is not supported.
@experimental
final class PostgrestToManyColumn<Row, Value extends Object>
    extends _EmbeddedColumn<Row, Value> {
  const PostgrestToManyColumn._(super.embed, super.inner);

  @override
  PostgrestToManyColumn<Row, String> jsonText(String path) =>
      PostgrestToManyColumn._(_embed, '$_inner->>$path');

  @override
  PostgrestToManyColumn<Row, Value> jsonObject(String path) =>
      PostgrestToManyColumn._(_embed, '$_inner->$path');
}
