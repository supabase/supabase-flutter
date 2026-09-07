import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

extension type const Order(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

extension type const Todo(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

class Orders {
  static const id = PostgrestColumn<Order, int>('id');
  static const amount = PostgrestColumn<Order, double>('amount');
  static const shippedAt = PostgrestNullableColumn<Order, DateTime>(
    'shipped_at',
  );
  static const todo = PostgrestToOneRelation<Order, Todo>('todo');
}

class Todos {
  static const id = PostgrestColumn<Todo, int>('id');
  static const title = PostgrestColumn<Todo, String>('title');
  static const amount = PostgrestColumn<Todo, double>('amount');
  static const orders = PostgrestToManyRelation<Todo, Order>('orders');
}

void main() {
  test('a projected column wraps in the embed name', () {
    expect(Todos.orders(Orders.amount).expression, 'orders(amount)');
    expect(Orders.todo(Todos.title).expression, 'todo(title)');
    expect(Orders.todo.name, 'todo');
  });

  test('a projected column keeps its value type', () {
    expect(
      Todos.orders(Orders.amount),
      isA<PostgrestColumnExpression<Todo, double>>(),
    );
    expect(
      Todos.orders(Orders.amount).sum(),
      isA<PostgrestDerivedExpression<Todo, double>>(),
    );
    expect(
      Todos.orders(Orders.shippedAt),
      isA<PostgrestColumnExpression<Todo, DateTime>>(),
    );
  });

  test('an aggregate over an embed renders inside the parentheses', () {
    // `orders(amount).sum()` is a 200 with the `.sum()` silently ignored.
    expect(
      Todos.orders(Orders.amount).sum().expression,
      'orders(amount.sum())',
    );
    expect(Todos.orders(Orders.id).count().expression, 'orders(id.count())');
    expect(
      Todos.orders(Orders.amount).avg().expression,
      'orders(amount.avg())',
    );
    expect(Todos.orders(Orders.id).min().expression, 'orders(id.min())');
    expect(Todos.orders(Orders.id).max().expression, 'orders(id.max())');
    expect(Orders.todo(Todos.id).sum().expression, 'todo(id.sum())');
  });

  test('a cast over an embed renders inside the parentheses', () {
    expect(
      Todos.orders(Orders.amount).cast(PostgrestCastTarget.text).expression,
      'orders(amount::text)',
    );
    expect(
      Orders.todo(Todos.id).cast(PostgrestCastTarget.text).expression,
      'todo(id::text)',
    );
  });

  test('a JSON path over an embed renders inside the parentheses', () {
    expect(
      Todos.orders(Orders.amount).jsonText('k').expression,
      'orders(amount->>k)',
    );
    expect(
      Todos.orders(Orders.amount).jsonObject('k').expression,
      'orders(amount->k)',
    );
    expect(Orders.todo(Todos.id).jsonText('k').expression, 'todo(id->>k)');
    expect(Orders.todo(Todos.id).jsonObject('k').expression, 'todo(id->k)');
  });

  test('a derivation chained onto a derivation stays inside the embed', () {
    expect(
      Orders.todo(Todos.amount).sum().cast(PostgrestCastTarget.text).expression,
      'todo(amount.sum()::text)',
    );
  });

  test('the filter form is dotted and separate', () {
    final Object projected = Todos.orders(Orders.id);

    expect(Todos.orders(Orders.id).embeddedFilterName, 'orders.id');
    expect(Orders.todo(Todos.title).embeddedFilterName, 'todo.title');
    final Object toOne = Orders.todo(Todos.title);

    expect(projected, isNot(isA<PostgrestFilterableExpression<Todo, int>>()));
    expect(toOne, isNot(isA<PostgrestFilterableExpression<Order, String>>()));
  });

  test('a to-one projection is orderable but a to-many projection is not', () {
    // `order=children(amount).desc` is PGRST118 on the server.
    final Object toMany = Todos.orders(Orders.amount);

    expect(Orders.todo(Todos.title).asc().orderKey, 'todo(title).asc');
    expect(Orders.todo(Todos.title).desc().orderKey, 'todo(title).desc');
    expect(Orders.todo(Todos.title).orderKey, 'todo(title)');
    expect(toMany, isNot(isA<PostgrestOrderableExpression<Todo, double>>()));
  });

  test('a to-one cast is not orderable but a to-one JSON path is', () {
    final Object cast = Orders.todo(Todos.id).cast(PostgrestCastTarget.text);
    final Object sum = Orders.todo(Todos.id).sum();

    expect(cast, isNot(isA<PostgrestOrderableExpression<Order, String>>()));
    expect(sum, isNot(isA<PostgrestOrderableExpression<Order, double>>()));
    expect(
      Orders.todo(Todos.id).jsonText('k').asc().orderKey,
      'todo(id->>k).asc',
    );
  });

  test('embeds nest', () {
    expect(
      Orders.todo(Todos.orders(Orders.amount)).expression,
      'todo(orders(amount))',
    );
  });
}
