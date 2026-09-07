import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

extension type const Order(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

class Orders {
  static const amount = PostgrestColumn<Order, double>('amount');
  static const quantity = PostgrestColumn<Order, int>('quantity');
}

void main() {
  test('aggregates render their function suffix', () {
    expect(Orders.amount.sum().expression, 'amount.sum()');
    expect(Orders.amount.avg().expression, 'amount.avg()');
    expect(Orders.amount.min().expression, 'amount.min()');
    expect(Orders.amount.max().expression, 'amount.max()');
    expect(Orders.amount.count().expression, 'amount.count()');
  });

  test('aggregates carry the right result type', () {
    // sum and avg widen to double whatever the column's type, min and max
    // keep it, and count is always an int.
    expect(
      Orders.quantity.sum(),
      isA<PostgrestDerivedExpression<Order, double>>(),
    );
    expect(
      Orders.quantity.avg(),
      isA<PostgrestDerivedExpression<Order, double>>(),
    );
    expect(
      Orders.quantity.min(),
      isA<PostgrestDerivedExpression<Order, int>>(),
    );
    expect(
      Orders.quantity.max(),
      isA<PostgrestDerivedExpression<Order, int>>(),
    );
    expect(
      Orders.quantity.count(),
      isA<PostgrestDerivedExpression<Order, int>>(),
    );
  });

  test('countAll renders with no column', () {
    expect(PostgrestDerivedExpression.countAll<Order>().expression, 'count()');
  });

  test('an aggregate is selectable and nothing else', () {
    // Neither `Orders.amount.sum().gt(100)` nor `Orders.amount.sum().desc()`
    // compiles: PostgREST has no HAVING and cannot order by an aggregate.
    final Object sum = Orders.amount.sum();

    expect(sum, isA<PostgrestColumnExpression<Order, double>>());
    expect(sum, isNot(isA<PostgrestFilterableExpression<Order, double>>()));
    expect(sum, isNot(isA<PostgrestOrderableExpression<Order, double>>()));
    expect(sum, isNot(isA<PostgrestNullableExpression<Order, double>>()));
  });

  test('a cast on an aggregate lands after the function', () {
    expect(
      Orders.amount.sum().cast(PostgrestCastTarget.text).expression,
      'amount.sum()::text',
    );
  });
}
