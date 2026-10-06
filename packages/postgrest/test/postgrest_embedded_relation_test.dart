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
  static const todoId = PostgrestColumn<Order, int>('todo_id');
  static const todo = PostgrestToOneRelation<Order, Todo>(
    'todo',
    columns: [todoId],
    referencedTable: 'todos',
    referencedColumns: [Todos.id],
  );
  static const parentId = PostgrestColumn<Order, int>('parent_id');
  static const parentTodo = PostgrestToOneRelation<Order, Todo>(
    'todo!orders_parent_id_fkey',
    columns: [parentId],
    referencedTable: 'todos',
    referencedColumns: [Todos.id],
    alias: 'parent_todo',
  );
}

class Todos {
  static const id = PostgrestColumn<Todo, int>('id');
  static const title = PostgrestColumn<Todo, String>('title');
  static const amount = PostgrestColumn<Todo, double>('amount');
  static const orders = PostgrestToManyRelation<Todo, Order>(
    'orders',
    columns: [id],
    referencedTable: 'orders',
    referencedColumns: [Orders.todoId],
  );
}

void main() {
  test('a relation knows the columns of both sides of its key', () {
    expect(Orders.todo.columns, [Orders.todoId]);
    expect(Orders.todo.referencedTable, 'todos');
    expect(Orders.todo.referencedColumns, [Todos.id]);
    expect(Todos.orders.columns, [Todos.id]);
    expect(Todos.orders.referencedColumns, [Orders.todoId]);
  });

  test('a projected column keeps its relation', () {
    expect(Todos.orders(Orders.amount).relation, same(Todos.orders));
    expect(Orders.todo(Todos.title).jsonText('k').relation, same(Orders.todo));
  });

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
      'orders("amount->>k":amount->>k)',
    );
    expect(
      Todos.orders(Orders.amount).jsonObject('k').expression,
      'orders("amount->k":amount->k)',
    );
    expect(
      Orders.todo(Todos.id).jsonText('k').expression,
      'todo("id->>k":id->>k)',
    );
  });

  test('a JSON path ending in an index before `)` gets a closing cast', () {
    expect(
      Orders.todo(Todos.title).jsonText('0').expression,
      'todo("title->>0":title->>0::text)',
    );
    expect(
      Orders.todo(Todos.title).jsonObject('-1').expression,
      'todo("title->-1":title->-1::jsonb)',
    );
    expect(
      Orders.todo(
        Todos.title,
      ).jsonText('0').cast(PostgrestCastTarget.integer).expression,
      'todo("title->>0::int":title->>0::int)',
    );
    expect(
      Orders.todo.select([Todos.title.jsonText('0'), Todos.id]).expression,
      'todo("title->>0":title->>0,id)',
    );
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
    expect(
      Orders.todo(Todos.orders(Orders.amount)).embeddedFilterName,
      'todo.orders.amount',
    );
    expect(
      Orders.todo(Todos.orders(Orders.amount).sum()).embeddedFilterName,
      'todo.orders.amount.sum()',
    );
  });

  test('a derivation of a nested projection lands on the innermost column', () {
    expect(
      Orders.todo(Todos.orders(Orders.amount)).sum().expression,
      'todo(orders(amount.sum()))',
    );
    expect(
      Orders.todo(Todos.orders(Orders.amount)).sum().jsonText('k').expression,
      'todo(orders("amount.sum()->>k":amount.sum()->>k))',
    );
  });

  group('alias', () {
    test('the key is the alias, or the table name of the embed', () {
      expect(Orders.todo.key, 'todo');
      expect(Orders.parentTodo.key, 'parent_todo');
      expect(
        const PostgrestToOneRelation<Order, Todo>(
          'todo!orders_parent_id_fkey',
          columns: [Orders.parentId],
          referencedTable: 'todos',
          referencedColumns: [Todos.id],
        ).key,
        'todo',
      );
    });

    test('renames the embed in the select list', () {
      expect(
        Orders.parentTodo(Todos.title).expression,
        'parent_todo:todo!orders_parent_id_fkey(title)',
      );
      expect(
        Orders.parentTodo.select().expression,
        'parent_todo:todo!orders_parent_id_fkey(*)',
      );
      expect(
        Orders.parentTodo(Todos.title).sum().expression,
        'parent_todo:todo!orders_parent_id_fkey(title.sum())',
      );
    });

    test('addresses the embed by the alias in order and filter', () {
      expect(
        Orders.parentTodo(Todos.title).desc().orderKey,
        'parent_todo(title).desc',
      );
      expect(Orders.parentTodo(Todos.title).orderKey, 'parent_todo(title)');
      expect(
        Orders.parentTodo(Todos.title).embeddedFilterName,
        'parent_todo.title',
      );
      expect(
        Orders.parentTodo(Todos.orders(Orders.id)).orderKey,
        'parent_todo(orders(id))',
      );
    });
  });

  group('select', () {
    test('several columns of an embed share one pair of parentheses', () {
      expect(
        Orders.todo.select([Todos.id, Todos.title]).expression,
        'todo(id,title)',
      );
      expect(
        Todos.orders.select([Orders.id, Orders.amount.sum()]).expression,
        'orders(id,amount.sum())',
      );
    });

    test('no selections selects every column of the embed', () {
      expect(Orders.todo.select().expression, 'todo(*)');
      expect(Orders.todo.select().selections, isEmpty);
    });

    test('an empty selection throws, naming the parameter', () {
      expect(
        () => Orders.todo.select([]),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'selections'),
        ),
      );
    });

    test('keeps the relation and its kind', () {
      final toOne = Orders.todo.select();
      final toMany = Todos.orders.select();

      expect(toOne, isA<PostgrestToOneEmbed<Order, Todo>>());
      expect(toOne.relation, same(Orders.todo));
      expect(toMany, isA<PostgrestToManyEmbed<Todo, Order>>());
      expect(toMany.relation, same(Todos.orders));
    });

    test('is selectable and nothing else', () {
      final Object embed = Orders.todo.select();

      expect(embed, isA<PostgrestSelectable<Order>>());
      expect(embed, isNot(isA<PostgrestColumnExpression<Order, Object>>()));
      expect(embed, isNot(isA<PostgrestOrdering<Order>>()));
    });

    test('nests', () {
      expect(
        Orders.todo.select([Todos.id, Todos.orders.select()]).expression,
        'todo(id,orders(*))',
      );
      expect(
        Orders.todo.select([
          Todos.id,
          Todos.orders.select([Orders.id, Orders.amount]),
        ]).expression,
        'todo(id,orders(id,amount))',
      );
    });

    test('merges the projections of one relation inside it', () {
      expect(
        Orders.todo.select([
          Todos.orders(Orders.id),
          Todos.title,
          Todos.orders(Orders.amount),
        ]).expression,
        'todo(orders(id,amount),title)',
      );
    });

    test('a single-column projection renders like a one-entry select', () {
      expect(
        Orders.todo(Todos.title).expression,
        Orders.todo.select([Todos.title]).expression,
      );
    });
  });
}
