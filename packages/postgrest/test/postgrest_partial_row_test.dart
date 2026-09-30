import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

extension type const Order(Map<String, dynamic> _json) implements Object {
  int get id => _json['id'] as int;
}

extension type const Customer(Map<String, dynamic> _json) implements Object {}

extension type const Item(Map<String, dynamic> _json) implements Object {}

enum Status {
  open,
  shipped;

  static Status fromJson(Object json) => values.byName(json as String);
}

double _doubleFromJson(Object json) => (json as num).toDouble();

DateTime _dateTimeFromJson(Object json) => DateTime.parse(json as String);

class Orders {
  static const table = PostgrestTable<Order, Never, Never>(
    'orders',
    Order.new,
    primaryKey: [id],
    relations: [customer, items],
  );
  static const id = PostgrestColumn<Order, int>('id');
  static const customerId = PostgrestNullableColumn<Order, int>('customer_id');
  static const amount = PostgrestColumn<Order, double>(
    'amount',
    fromJson: _doubleFromJson,
  );
  static const status = PostgrestColumn<Order, Status>(
    'status',
    fromJson: Status.fromJson,
  );
  static const placedAt = PostgrestColumn<Order, DateTime>(
    'placed_at',
    fromJson: _dateTimeFromJson,
  );
  static const shippedAt = PostgrestNullableColumn<Order, DateTime>(
    'shipped_at',
    fromJson: _dateTimeFromJson,
  );
  static const note = PostgrestNullableColumn<Order, String>('note');
  static const metadata = PostgrestColumn<Order, Object>('metadata');
  static const customer = PostgrestToOneRelation<Order, Customer>(
    'customers',
    columns: [customerId],
    referencedTable: 'customers',
    referencedColumns: [Customers.id],
  );
  static const items = PostgrestToManyRelation<Order, Item>(
    'items',
    columns: [id],
    referencedTable: 'items',
    referencedColumns: [Items.orderId],
  );
}

class Customers {
  static const table = PostgrestTable<Customer, Never, Never>(
    'customers',
    Customer.new,
    primaryKey: [id],
  );
  static const id = PostgrestColumn<Customer, int>('id');
  static const name = PostgrestColumn<Customer, String>('name');
  static const email = PostgrestNullableColumn<Customer, String>('email');
}

class Items {
  static const table = PostgrestTable<Item, Never, Never>(
    'items',
    Item.new,
    primaryKey: [id],
  );
  static const id = PostgrestColumn<Item, int>('id');
  static const orderId = PostgrestColumn<Item, int>('order_id');
  static const sku = PostgrestColumn<Item, String>('sku');
  static const quantity = PostgrestColumn<Item, int>('quantity');
}

void main() {
  late MockSupabaseHttpClient httpClient;
  late PostgrestClient client;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stub([]);
    client = PostgrestClient(
      'http://localhost/rest/v1',
      httpClient: httpClient,
    );
  });

  tearDown(() async {
    await client.dispose();
  });

  Matcher throwsNotSelected(String key) => throwsA(
    isA<StateError>().having(
      (error) => error.message,
      'message',
      contains('`$key` was not selected'),
    ),
  );

  group('stored columns', () {
    test('read as their value type through the column token', () async {
      httpClient.stub([
        {
          'id': 1,
          'amount': 12,
          'status': 'shipped',
          'placed_at': '2026-09-29T10:00:00Z',
          'shipped_at': null,
          'note': 'gift',
        },
      ]);

      final orders = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.amount,
        Orders.status,
        Orders.placedAt,
        Orders.shippedAt,
        Orders.note,
      ]);

      final order = orders.single;
      final int id = order.read(Orders.id);
      final double amount = order.read(Orders.amount);
      final Status status = order.read(Orders.status);
      final DateTime placedAt = order.read(Orders.placedAt);
      final DateTime? shippedAt = order.read(Orders.shippedAt);
      final String? note = order.read(Orders.note);
      expect(id, 1);
      expect(amount, 12.0);
      expect(status, Status.shipped);
      expect(placedAt, DateTime.utc(2026, 9, 29, 10));
      expect(shippedAt, isNull);
      expect(note, 'gift');
    });

    test('a column the select list left out throws, naming it', () async {
      httpClient.stub({'id': 1, 'note': null});

      final order = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.note,
      ]).single();

      expect(() => order.read(Orders.amount), throwsNotSelected('amount'));
      expect(
        () => order.read(Orders.shippedAt),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            '`shipped_at` was not selected. The row holds `id`, `note`.',
          ),
        ),
      );
    });

    test('a selected column stripped as null reads null', () async {
      httpClient.stub({'id': 1});

      final order = await client
          .table(Orders.table)
          .selectOnly([Orders.id, Orders.note])
          .stripNulls()
          .single();

      expect(order.read(Orders.note), isNull);
    });

    test('a value of another type than declared is a TypeError', () async {
      httpClient.stub({'id': 'one'});

      final order = await client.table(Orders.table).selectOnly([
        Orders.id,
      ]).single();

      expect(() => order.read(Orders.id), throwsA(isA<TypeError>()));
    });
  });

  group('derived expressions', () {
    test('aggregates read under the function name, nullable', () async {
      httpClient.stub({
        'count': 3,
        'sum': 40,
        'avg': 13.5,
        'max': '2026-09-29T10:00:00Z',
      });

      final row = await client.table(Orders.table).selectOnly([
        PostgrestDerivedExpression.countAll(),
        Orders.amount.sum(),
        Orders.amount.avg(),
        Orders.placedAt.max(),
      ]).single();

      final int? count = row.read(PostgrestDerivedExpression.countAll());
      final double? sum = row.read(Orders.amount.sum());
      final double? avg = row.read(Orders.amount.avg());
      final DateTime? latest = row.read(Orders.placedAt.max());
      expect(count, 3);
      expect(sum, 40.0);
      expect(avg, 13.5);
      expect(latest, DateTime.utc(2026, 9, 29, 10));
    });

    test('a cast reads under the key of what was cast', () async {
      httpClient.stub({'id': '7', 'amount': 12});

      final row = await client.table(Orders.table).selectOnly([
        Orders.id.cast(PostgrestCastTarget.text),
        Orders.amount.cast(PostgrestCastTarget.doublePrecision),
      ]).single();

      final String? id = row.read(Orders.id.cast(PostgrestCastTarget.text));
      final double? amount = row.read(
        Orders.amount.cast(PostgrestCastTarget.doublePrecision),
      );
      expect(id, '7');
      expect(amount, 12.0);
      expect(() => row.read(Orders.id), throwsA(isA<TypeError>()));
    });

    test('a JSON path reads under its last key', () async {
      httpClient.stub({'id': 1, 'gift': 'true', 'tags': null});

      final row = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.metadata.jsonText('gift'),
        Orders.metadata.jsonObject('tags'),
      ]).single();

      expect(row.read(Orders.metadata.jsonText('gift')), 'true');
      expect(row.read(Orders.metadata.jsonObject('tags')), isNull);
      expect(
        () => row.read(Orders.metadata.jsonText('wrapping')),
        throwsNotSelected('wrapping'),
      );
    });
  });

  group('relations', () {
    test('a to-one relation reads as a nested partial row', () async {
      httpClient.stub([
        {
          'id': 1,
          'customers': {'name': 'Ada', 'email': null},
        },
        {'id': 2, 'customers': null},
      ]);

      final orders = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.customer.select([Customers.name, Customers.email]),
      ]);

      final PostgrestPartialRow<Customer>? customer = orders.first.read(
        Orders.customer,
      );
      expect(customer?.read(Customers.name), 'Ada');
      expect(customer?.read(Customers.email), isNull);
      expect(() => customer?.read(Customers.id), throwsNotSelected('id'));
      expect(orders.last.read(Orders.customer), isNull);
    });

    test('a to-many relation reads as a list of partial rows', () async {
      httpClient.stub({
        'id': 1,
        'items': [
          {'sku': 'a', 'quantity': 2},
          {'sku': 'b', 'quantity': 1},
        ],
      });

      final order = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.items(Items.sku),
        Orders.items(Items.quantity),
      ]).single();

      final List<PostgrestPartialRow<Item>> items = order.read(Orders.items);
      expect(items.map((item) => item.read(Items.sku)), ['a', 'b']);
      expect(items.map((item) => item.read(Items.quantity)), [2, 1]);
      expect(() => items.first.read(Items.id), throwsNotSelected('id'));
    });

    test('a whole embed reads any column', () async {
      httpClient.stub({
        'id': 1,
        'customers': {'id': 5, 'name': 'Ada', 'email': 'ada@example.com'},
      });

      final order = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.customer.select(),
      ]).single();

      final customer = order.read(Orders.customer)!;
      expect(customer.read(Customers.id), 5);
      expect(customer.read(Customers.email), 'ada@example.com');
    });

    test('entries of one relation merge into the nested row', () async {
      httpClient.stub({
        'id': 1,
        'items': [
          {'id': 9, 'sku': 'a', 'quantity': 2, 'order_id': 1, 'count': 1},
        ],
      });

      final order = await client.table(Orders.table).selectOnly([
        Orders.items(Items.sku),
        Orders.id,
        Orders.items.select(),
        Orders.items(Items.id).count(),
      ]).single();

      final item = order.read(Orders.items).single;
      expect(item.read(Items.sku), 'a');
      expect(item.read(Items.orderId), 1);
      expect(item.read(Items.id.count()), 1);
    });

    test('a relation not in the select list throws', () async {
      httpClient.stub({'id': 1});

      final order = await client.table(Orders.table).selectOnly([
        Orders.id,
      ]).single();

      expect(
        () => order.read(Orders.customer),
        throwsNotSelected('customers'),
      );
    });

    test('a whole embed covers no derived expression', () async {
      httpClient.stub({
        'id': 1,
        'items': [
          {'id': 9, 'sku': 'a', 'quantity': 2, 'order_id': 1},
        ],
      });

      final order = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.items.select(),
      ]).single();

      final item = order.read(Orders.items).single;
      expect(item.read(Items.id), 9);
      expect(() => item.read(Items.id.count()), throwsNotSelected('count'));
    });

    test('an embedded entry is read through its relation', () async {
      httpClient.stub({
        'id': 1,
        'items': [
          {'count': 2},
        ],
      });

      final order = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.items(Items.id).count(),
      ]).single();

      expect(
        () => order.read(Orders.items(Items.id).count()),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            contains('`items` embed'),
          ),
        ),
      );
      expect(order.read(Orders.items).single.read(Items.id.count()), 2);
    });
  });

  group('shapes', () {
    test('single and maybeSingle keep the partial row', () async {
      httpClient.stub({'id': 1, 'note': 'gift'});

      final PostgrestPartialRow<Order> order = await client
          .table(Orders.table)
          .selectOnly([Orders.id, Orders.note])
          .where(Orders.id.eq(1))
          .single();
      expect(order.read(Orders.note), 'gift');
      expect(
        httpClient.requests.last.headers['Accept'],
        'application/vnd.pgrst.object+json',
      );

      httpClient.stub(null);
      final PostgrestPartialRow<Order>? none = await client
          .table(Orders.table)
          .selectOnly([Orders.id])
          .maybeSingle();
      expect(none, isNull);
    });

    test('count wraps the partial rows', () async {
      httpClient.stub(
        [
          {'id': 1},
        ],
        headers: {'content-range': '0-0/10'},
      );

      final response = await client
          .table(Orders.table)
          .selectOnly([Orders.id])
          .count(CountOption.exact);

      expect(response.count, 10);
      expect(response.data.single.read(Orders.id), 1);
    });

    test('a trailing selectOnly on a mutation reads the rows back', () async {
      httpClient.stub({'id': 3});

      final order = await client
          .table(Orders.table)
          .delete()
          .where(Orders.id.eq(3))
          .selectOnly([Orders.id])
          .single();

      expect(httpClient.requests.last.queryParameters['select'], 'id');
      expect(order.read(Orders.id), 3);
    });

    test('toJson and toString expose the decoded row', () async {
      httpClient.stub({'id': 1, 'note': null});

      final order = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.note,
      ]).single();

      expect(order.toJson(), {'id': 1, 'note': null});
      expect(order.toString(), 'PostgrestPartialRow({id: 1, note: null})');
    });
  });
}
