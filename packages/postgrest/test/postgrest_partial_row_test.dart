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
  static const table = PostgrestTable<Order, Never, Map<String, dynamic>>(
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
  static const metadata = PostgrestJsonColumn<Order>('metadata');
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
    test('aggregates read under their own expression, nullable', () async {
      httpClient.stub({
        'count()': 3,
        'amount.sum()': 40,
        'amount.avg()': 13.5,
        'placed_at.max()': '2026-09-29T10:00:00Z',
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

    test('two aggregates of the same function read apart', () async {
      httpClient.stub({'id.sum()': 6, 'amount.sum()': 40});

      final row = await client.table(Orders.table).selectOnly([
        Orders.id.sum(),
        Orders.amount.sum(),
      ]).single();

      expect(
        httpClient.requests.last.queryParameters['select'],
        '"id.sum()":id.sum(),"amount.sum()":amount.sum()',
      );
      expect(row.read(Orders.id.sum()), 6.0);
      expect(row.read(Orders.amount.sum()), 40.0);
    });

    test(
      'a cast reads under its own expression, apart from its column',
      () async {
        httpClient.stub({'id': 7, 'id::text': '7', 'amount::float8': 12});

        final row = await client.table(Orders.table).selectOnly([
          Orders.id,
          Orders.id.cast(PostgrestCastTarget.text),
          Orders.amount.cast(PostgrestCastTarget.doublePrecision),
        ]).single();

        final String? id = row.read(Orders.id.cast(PostgrestCastTarget.text));
        final double? amount = row.read(
          Orders.amount.cast(PostgrestCastTarget.doublePrecision),
        );
        expect(row.read(Orders.id), 7);
        expect(id, '7');
        expect(amount, 12.0);
      },
    );

    test('a NOT NULL JSON column reads the JSON null as null', () async {
      httpClient.stub({'id': 1, 'metadata': null});

      final row = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.metadata,
      ]).single();

      final PostgrestJson? metadata = row.read(Orders.metadata);
      expect(metadata, isNull);
    });

    test('a JSON path reads under its own expression', () async {
      httpClient.stub({
        'id': 1,
        'metadata->>"gift"': 'true',
        'metadata->"tags"': null,
      });

      final row = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.metadata.jsonText('gift'),
        Orders.metadata.jsonObject('tags'),
      ]).single();

      expect(row.read(Orders.metadata.jsonText('gift')), 'true');
      expect(row.read(Orders.metadata.jsonObject('tags')), isNull);
      expect(
        () => row.read(Orders.metadata.jsonText('wrapping')),
        throwsNotSelected('metadata->>"wrapping"'),
      );
      expect(
        httpClient.requests.last.url.queryParameters['select'],
        r'id,"metadata->>\"gift\"":metadata->>"gift",'
        r'"metadata->\"tags\"":metadata->"tags"',
      );
    });

    test('JSON paths of one column read their own values', () async {
      httpClient.stub({
        'metadata': {
          'tags': ['urgent', 'later'],
        },
        'metadata->"tags"->>0': 'urgent',
        'metadata->"tags"->>1': 'later',
      });
      final firstTag = Orders.metadata.jsonObject('tags').jsonTextAt(0);
      final secondTag = Orders.metadata.jsonObject('tags').jsonTextAt(1);

      final row = await client.table(Orders.table).selectOnly([
        Orders.metadata,
        firstTag,
        secondTag,
      ]).single();

      expect(row.read(firstTag), 'urgent');
      expect(row.read(secondTag), 'later');
      expect(row.read(Orders.metadata), {
        'tags': ['urgent', 'later'],
      });
    });

    test('a JSON path does not select its column', () async {
      httpClient.stub({'metadata->>0': 'first'});

      final row = await client.table(Orders.table).selectOnly([
        Orders.metadata.jsonTextAt(0),
      ]).single();

      expect(() => row.read(Orders.metadata), throwsNotSelected('metadata'));
      expect(
        () => row.read(Orders.metadata.jsonTextAt(1)),
        throwsNotSelected('metadata->>1'),
      );
    });
  });

  group('relations', () {
    test('a derivation inside an embed reads under the embedded key', () async {
      httpClient.stub({
        'items': [
          {'sku::text': 'A1', 'sku->>"k"': 'v'},
        ],
      });

      final row = await client.table(Orders.table).selectOnly([
        Orders.items(Items.sku).cast(PostgrestCastTarget.text),
        Orders.items(Items.sku).jsonText('k'),
      ]).single();

      final item = row.read(Orders.items).single;
      expect(item.read(Items.sku.cast(PostgrestCastTarget.text)), 'A1');
      expect(item.read(Items.sku.jsonText('k')), 'v');
    });

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
          {'id': 9, 'sku': 'a', 'quantity': 2, 'order_id': 1, 'id.count()': 1},
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

    test('a count of a relation reads as an int', () async {
      httpClient.stub({
        'id': 1,
        'items': [
          {'sku': 'a'},
        ],
        'items(count)': [
          {'count': 3},
        ],
      });

      final order = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.items(Items.sku),
        Orders.items.count(),
      ]).single();

      expect(
        httpClient.requests.last.queryParameters['select'],
        'id,items(sku),"items(count)":items(count)',
      );
      final int count = order.read(Orders.items.count());
      expect(count, 3);
      expect(order.read(Orders.items).single.read(Items.sku), 'a');
    });

    for (final (description, counted) in [
      (
        'a count of the wrong type',
        <Object?>[
          {'count': '3'},
        ],
      ),
      ('a count that is not a single row', <Object?>[]),
    ]) {
      test('$description throws a FormatException', () async {
        httpClient.stub({'id': 1, 'items(count)': counted});

        final order = await client.table(Orders.table).selectOnly([
          Orders.id,
          Orders.items.count(),
        ]).single();

        expect(
          () => order.read(Orders.items.count()),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              anyOf(contains('"count"'), contains('"items(count)"')),
            ),
          ),
        );
      });
    }

    test('a count of a relation not in the select list throws', () async {
      httpClient.stub({'id': 1});

      final order = await client.table(Orders.table).selectOnly([
        Orders.id,
      ]).single();

      expect(
        () => order.read(Orders.items.count()),
        throwsNotSelected('items(count)'),
      );
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
      expect(
        () => item.read(Items.id.count()),
        throwsNotSelected('id.count()'),
      );
    });

    test('an embedded entry is read through its relation', () async {
      httpClient.stub({
        'id': 1,
        'items': [
          {'id.count()': 2},
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

  group('every column', () {
    test('renders as * next to an embed', () async {
      httpClient.stub([]);

      await client.table(Orders.table).selectOnly([
        Orders.table.allColumns,
        Orders.customer.select([Customers.name]),
      ]);

      expect(
        httpClient.requests.last.url.queryParameters['select'],
        '*,customers(name)',
      );
    });

    test('reads any stored column but no relation', () async {
      httpClient.stub({
        'id': 1,
        'note': 'gift',
        'customers': {'name': 'Ada'},
      });

      final order = await client.table(Orders.table).selectOnly([
        Orders.table.allColumns,
        Orders.customer.select([Customers.name]),
      ]).single();

      expect(order.read(Orders.id), 1);
      expect(order.read(Orders.note), 'gift');
      expect(order.read(Orders.customer)?.read(Customers.name), 'Ada');
      expect(() => order.read(Orders.items), throwsNotSelected('items'));
    });

    test('covers no derived expression', () async {
      httpClient.stub({'id': 1});

      final order = await client.table(Orders.table).selectOnly([
        Orders.table.allColumns,
      ]).single();

      expect(
        () => order.read(Orders.id.count()),
        throwsNotSelected('id.count()'),
      );
    });

    test('inside an embed merges with a whole embed', () async {
      httpClient.stub([]);

      await client.table(Orders.table).selectOnly([
        Orders.customer.select(),
        Orders.customer.select([Customers.table.allColumns, Customers.name]),
      ]);

      expect(
        httpClient.requests.last.url.queryParameters['select'],
        'customers(*,name)',
      );
    });

    test('inside an embed reads any column of the nested row', () async {
      httpClient.stub({
        'id': 1,
        'customers': {'id': 5, 'name': 'Ada', 'email': null},
      });

      final order = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.customer.select([Customers.table.allColumns]),
      ]).single();

      final customer = order.read(Orders.customer)!;
      expect(customer.read(Customers.name), 'Ada');
      expect(customer.read(Customers.email), isNull);
      expect(customer.toRow(Customers.table), isA<Customer>());
    });

    test('converts into the full row', () async {
      httpClient.stub({
        'id': 1,
        'customers': {'name': 'Ada'},
      });

      final order = await client.table(Orders.table).selectOnly([
        Orders.table.allColumns,
        Orders.customer.select([Customers.name]),
      ]).single();

      final Order row = order.toRow(Orders.table);
      expect(row.id, 1);
    });

    test('a whole embed converts into the full row', () async {
      httpClient.stub({
        'id': 1,
        'customers': {'id': 5, 'name': 'Ada', 'email': null},
      });

      final order = await client.table(Orders.table).selectOnly([
        Orders.id,
        Orders.customer.select(),
      ]).single();

      final Customer customer = order
          .read(Orders.customer)!
          .toRow(Customers.table);
      expect(customer, {'id': 5, 'name': 'Ada', 'email': null});
    });

    test('a row of some columns does not convert into the full row', () async {
      httpClient.stub({'id': 1});

      final order = await client.table(Orders.table).selectOnly([
        Orders.id,
      ]).single();

      expect(
        () => order.toRow(Orders.table),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Only a row of every column'),
          ),
        ),
      );
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
