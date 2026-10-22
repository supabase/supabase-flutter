// The typed table access API under test is annotated @experimental.
// ignore_for_file: experimental_member_use

import 'dart:typed_data';

import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

import 'goldens/hostile_schema.dart' as hostile;
import 'goldens/supabase_schema.dart';

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

  test('select returns typed rows with converted values', () async {
    httpClient.stub([
      {
        'id': 1,
        'title': 'A typed row',
        'author_id': 7,
        'price': 12.5,
        'rating': 4,
        'in_print': true,
        'mood': 'very happy',
        'tags': ['dart', 'types'],
        'metadata': {'reprint': true},
        'created_at': '2026-07-23T10:00:00Z',
        'published_on': '2026-07-23',
        'updated_at': null,
        'cover_image': r'\x89504e47',
      },
    ]);

    final List<BooksRow> books = await client.table(Books.table).select();

    final book = books.single;
    expect(book.id, 1);
    expect(book.title, 'A typed row');
    expect(book.rating, 4.0);
    expect(book.inPrint, isTrue);
    expect(book.mood, Mood.veryHappy);
    expect(book.tags, ['dart', 'types']);
    expect(book.metadata, {'reprint': true});
    expect(book.createdAt, DateTime.utc(2026, 7, 23, 10));
    expect(book.publishedOn, PostgresDate(2026, 7, 23));
    expect(book.updatedAt == null, isTrue);
    expect(book.coverImage, [0x89, 0x50, 0x4e, 0x47]);
  });

  test('bytea columns are sent as hex literals', () async {
    httpClient.stub(null);
    final cover = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);

    await client
        .table(Books.table)
        .insert(
          BooksInsert(title: 'A typed row', authorId: 7, coverImage: cover),
        );

    final sent = httpClient.requests.last.jsonBody as Map<String, dynamic>;
    expect(sent['cover_image'], r'\x89504e47');

    httpClient.stub([]);
    await client.table(Books.table).select().where(Books.coverImage.eq(cover));

    expect(
      httpClient.requests.last.queryParameters['cover_image'],
      r'eq.\x89504e47',
    );
  });

  test('vector columns are read and sent as vector literals', () async {
    httpClient.stub([
      {
        "quote'name\u2029tail": 'key',
        'samples': <double>[],
        'postgres_bytea': r'\x',
        'postgres_vector': '[0.5,-2.25,1]',
        'half_embedding': null,
      },
    ]);

    final List<hostile.PostgrestTableRow> rows = await client
        .table(hostile.PostgrestTable$.table)
        .select();

    expect(rows.single.postgresVector$, [0.5, -2.25, 1.0]);
    expect(rows.single.halfEmbedding, isNull);

    httpClient.stub(null);
    await client
        .table(hostile.PostgrestTable$.table)
        .insert(
          hostile.PostgrestTableInsert(
            quoteNameTail: 'key',
            samples: [],
            postgresBytea$: Uint8List(0),
            postgresVector$: [0.5, -2.25],
            halfEmbedding: [0.75],
          ),
        );

    final sent = httpClient.requests.last.jsonBody as Map<String, dynamic>;
    expect(sent['postgres_vector'], '[0.5,-2.25]');
    expect(sent['half_embedding'], '[0.75]');

    httpClient.stub([]);
    await client
        .table(hostile.PostgrestTable$.table)
        .select()
        .where(hostile.PostgrestTable$.postgresVector$.eq([0.5, -2.25]));

    expect(
      httpClient.requests.last.queryParameters['postgres_vector'],
      'eq.[0.5,-2.25]',
    );
  });

  test('tables outside public are queried in their schema', () async {
    httpClient.stubTable(
      'stock',
      rows: [
        {
          'id': 1,
          'book_id': 1,
          'copy_id': 2,
          'condition': 'used',
          'quantity': 3,
        },
      ],
      schema: 'inventory',
    );

    final List<InventoryStockRow> stock = await client
        .table(InventoryStock.table)
        .select();

    expect(stock.single.condition, InventoryCondition.used);
    expect(stock.single.quantity, 3);
    expect(httpClient.requests.last.url.path, '/rest/v1/stock');
    expect(httpClient.requests.last.headers['Accept-Profile'], 'inventory');
  });

  test(
    'public tables are queried in public whatever the client default',
    () async {
      final personal = PostgrestClient(
        'http://localhost/rest/v1',
        schema: 'personal',
        httpClient: httpClient,
      );
      httpClient.stubTable('books', rows: [], schema: 'public');

      await personal.table(Books.table).select();
      await personal.dispose();

      expect(httpClient.requests.last.headers['Accept-Profile'], 'public');
    },
  );

  test('an explicitly selected schema wins over the table schema', () async {
    httpClient.stubTable('stock', rows: [], schema: 'archive');

    await client.schema('archive').table(InventoryStock.table).select();

    expect(httpClient.requests.last.headers['Accept-Profile'], 'archive');
  });

  test(
    'relation members of tables outside public project embedded columns',
    () async {
      httpClient.stubTable('stock', rows: [], schema: 'inventory');

      await client.table(InventoryStock.table).selectOnly([
        InventoryStock.id,
        InventoryStock.books(InventoryBooks.isbn),
      ]);

      expect(
        httpClient.requests.last.queryParameters['select'],
        'id,books(isbn)',
      );
    },
  );

  test('relation members project embedded columns', () async {
    await client.table(Books.table).selectOnly([
      Books.id,
      Books.authors(Authors.name),
    ]);

    expect(
      httpClient.requests.last.queryParameters['select'],
      'id,authors(name)',
    );

    await client.table(Authors.table).selectOnly([
      Authors.id,
      Authors.books(Books.id).count(),
    ]);

    expect(
      httpClient.requests.last.queryParameters['select'],
      'id,books("id.count()":id.count())',
    );
  });

  test('embedded rows are read through the relation', () async {
    httpClient.stub([
      {
        'id': 1,
        'authors': {'id': 7, 'name': 'Ada'},
      },
      {'id': 2, 'authors': null},
    ]);

    final books = await client.table(Books.table).selectOnly([
      Books.id,
      Books.authors.select([Authors.id, Authors.name]),
    ]);

    expect(
      httpClient.requests.last.queryParameters['select'],
      'id,authors(id,name)',
    );
    expect(books.first.read(Books.authors)?.read(Authors.name), 'Ada');
    expect(books.last.read(Books.authors), isNull);

    httpClient.stub([
      {
        'id': 7,
        'books': [
          {'id': 1, 'title': 'a'},
          {'id': 2, 'title': 'b'},
        ],
      },
    ]);

    final authors = await client.table(Authors.table).selectOnly([
      Authors.id,
      Authors.books.select(),
    ]);

    expect(
      httpClient.requests.last.queryParameters['select'],
      'id,books(*)',
    );
    expect(
      authors.single.read(Authors.books).map((book) => book.read(Books.title)),
      ['a', 'b'],
    );
  });

  test(
    'a hinted relation is selected, ordered and read by its alias',
    () async {
      httpClient.stub([
        {
          'id': 1,
          'map_by_mood': {'list': 3},
          'map_by_days': null,
        },
      ]);

      final rows = await client
          .table(hostile.PostgrestTable$.table)
          .selectOnly([
            hostile.PostgrestTable$.days,
            hostile.PostgrestTable$.mapByMood(hostile.Map$.list),
            hostile.PostgrestTable$.mapByDays.select(),
          ])
          .order(hostile.PostgrestTable$.mapByMood(hostile.Map$.list).desc());

      expect(
        httpClient.requests.last.queryParameters['select'],
        'days,map_by_mood:map!postgrest_table_mood_fkey(list),'
        'map_by_days:map!postgrest_table_days_fkey(*)',
      );
      expect(
        httpClient.requests.last.queryParameters['order'],
        'map_by_mood(list).desc',
      );
      expect(
        rows.single
            .read(hostile.PostgrestTable$.mapByMood)
            ?.read(hostile.Map$.list),
        3,
      );
      expect(rows.single.read(hostile.PostgrestTable$.mapByDays), isNull);
    },
  );

  test('enum column tokens filter with the wire name', () async {
    await client.table(Books.table).select().where(Books.mood.eq(Mood.happy));

    expect(
      httpClient.requests.last.queryParameters['mood'],
      'eq.happy',
    );
  });

  test('insert sends converted values and omits absent columns', () async {
    httpClient.stub(null);

    await client
        .table(Books.table)
        .insert(
          BooksInsert(
            title: 'A typed row',
            authorId: 7,
            mood: Mood.happy,
            createdAt: DateTime.utc(2026, 7, 23, 10),
          ),
        );

    final sent = httpClient.requests.last.jsonBody as Map<String, dynamic>;
    expect(sent, {
      'title': 'A typed row',
      'author_id': 7,
      'mood': 'happy',
      'created_at': '2026-07-23T10:00:00.000Z',
    });
  });

  test(
    'timestamps are sent as UTC instants and dates as their literal',
    () async {
      httpClient.stub(null);

      await client
          .table(Books.table)
          .insert(
            BooksInsert(
              title: 'A typed row',
              authorId: 7,
              createdAt: DateTime(2026, 7, 23, 10), // local wall time
              publishedOn: PostgresDate(2026, 7, 23),
            ),
          );

      final sent = httpClient.requests.last.jsonBody as Map<String, dynamic>;
      expect(
        sent['created_at'],
        DateTime(2026, 7, 23, 10).toUtc().toIso8601String(),
      );
      expect(sent['published_on'], '2026-07-23');
    },
  );

  test(
    'timestamp column tokens filter on the instant an update writes',
    () async {
      httpClient.stub(null);
      final local = DateTime(2026, 7, 23, 10); // local wall time

      await client
          .table(Books.table)
          .update(BooksUpdate(createdAt: local))
          .where(Books.createdAt.eq(local));

      final request = httpClient.requests.last;
      final written = (request.jsonBody as Map<String, dynamic>)['created_at'];
      final filtered = request.queryParameters['created_at']!;
      expect(written, local.toUtc().toIso8601String());
      expect(filtered, startsWith('eq.2026-07-23T10:00:00.000'));
      expect(filtered, matches(RegExp(r'[+-]\d{2}:\d{2}(:\d{2})?$')));
      expect(
        DateTime.parse(
          filtered.substring('eq.'.length),
        ).isAtSameMomentAs(DateTime.parse(written as String)),
        isTrue,
      );
    },
  );

  test('date column tokens filter with the date literal', () async {
    await client
        .table(Books.table)
        .select()
        .where(Books.publishedOn.gte(PostgresDate(2026, 1, 1)));

    expect(
      httpClient.requests.last.queryParameters['published_on'],
      'gte.2026-01-01',
    );
  });

  test(
    'time and interval columns round trip through their value types',
    () async {
      final row = hostile.MapRow({
        'list': 1,
        'pages': '[1,10)',
        'shift': '["2026-07-23 09:00:00","2026-07-23 17:00:00")',
        'season': '[2026-06-01,2026-09-01)',
        'since': '2026-07-23',
        'opens_at': '09:30:00',
        'closes_at': '17:00:00+02',
        'ttl': '1 mon 3 days 04:05:06',
      });

      expect(
        row.season,
        PostgresRange.closedOpen(
          PostgresDate(2026, 6, 1),
          PostgresDate(2026, 9, 1),
        ),
      );
      expect(row.since, PostgresDate(2026, 7, 23));
      expect(row.opensAt, PostgresTime(hour: 9, minute: 30));
      expect(
        row.closesAt,
        PostgresTime(hour: 17, offset: const Duration(hours: 2)),
      );
      expect(
        row.ttl,
        const PostgresInterval(
          months: 1,
          days: 3,
          hours: 4,
          minutes: 5,
          seconds: 6,
        ),
      );

      httpClient.stub(null);
      await client
          .table(hostile.Map$.table)
          .insert(
            hostile.MapInsert(
              list: 1,
              pages: const PostgresRange.closedOpen(1, 10),
              shift: PostgresRange.closedOpen(
                DateTime(2026, 7, 23, 9),
                DateTime(2026, 7, 23, 17),
              ),
              season: row.season,
              since: row.since,
              opensAt: row.opensAt,
              closesAt: row.closesAt,
              ttl: row.ttl,
            ),
          );

      final sent = httpClient.requests.last.jsonBody as Map<String, dynamic>;
      expect(sent['season'], '[2026-06-01,2026-09-01)');
      expect(sent['since'], '2026-07-23');
      expect(sent['opens_at'], '09:30:00');
      expect(sent['closes_at'], '17:00:00+02');
      expect(sent['ttl'], '1 mon 3 days 04:05:06');
    },
  );

  test(
    'integers sent as strings read, write and filter as numbers',
    () async {
      final row = hostile.MapRow({
        'list': 1,
        'opens_at': '09:30:00',
        'relation': '4294967295',
        'relations': ['1', '2'],
        'transaction': '18446744073709551615',
      });

      expect(row.relation, 4294967295);
      expect(row.relations, [1, 2]);
      expect(row.transaction, BigInt.parse('18446744073709551615'));

      httpClient.stub(null);
      await client
          .table(hostile.Map$.table)
          .update(
            hostile.MapUpdate(
              relation: row.relation,
              relations: row.relations,
              transaction: row.transaction,
            ),
          )
          .where(
            hostile.Map$.relation.eq(4294967295) &
                hostile.Map$.transaction.eq(
                  BigInt.parse('18446744073709551615'),
                ),
          );

      final request = httpClient.requests.last;
      expect(request.jsonBody, {
        'relation': 4294967295,
        'relations': [1, 2],
        'transaction': '18446744073709551615',
      });
      expect(request.queryParameters['relation'], 'eq.4294967295');
      expect(
        request.queryParameters['transaction'],
        'eq.18446744073709551615',
      );
    },
  );

  test(
    'integer vectors read as lists and write and filter as their literal',
    () async {
      final row = hostile.MapRow({
        'list': 1,
        'opens_at': '09:30:00',
        'key_columns': [1, 2],
        'argument_types': ['23', '4294967295'],
      });

      expect(row.keyColumns, [1, 2]);
      expect(row.argumentTypes, [23, 4294967295]);

      httpClient.stub(null);
      await client
          .table(hostile.Map$.table)
          .update(
            hostile.MapUpdate(
              keyColumns: row.keyColumns,
              argumentTypes: row.argumentTypes,
            ),
          )
          .where(
            hostile.Map$.keyColumns.eq([1, 2]) &
                hostile.Map$.argumentTypes.contains([23]),
          );

      final request = httpClient.requests.last;
      expect(request.jsonBody, {
        'key_columns': '1 2',
        'argument_types': '23 4294967295',
      });
      expect(request.queryParameters['key_columns'], 'eq.1 2');
      expect(request.queryParameters['argument_types'], 'cs.23');

      httpClient.stub([]);
      await client
          .table(hostile.Map$.table)
          .select()
          .where(
            hostile.Map$.keyColumns.inFilter([
                  [1, 2],
                  [3],
                ]) &
                (hostile.Map$.argumentTypes.eq([]) |
                    hostile.Map$.argumentTypes.eq([23]).not()),
          );

      final parameters = httpClient.requests.last.queryParameters;
      expect(parameters['key_columns'], 'in.(1 2,3)');
      expect(
        parameters['or'],
        '(argument_types.eq."",argument_types.not.eq.23)',
      );
      await expectLater(
        () async => await client
            .table(hostile.Map$.table)
            .select()
            .where(hostile.Map$.keyColumns.contains([1, null])),
        throwsArgumentError,
      );
    },
  );

  test('multirange columns read, write and filter as values', () async {
    final row = hostile.MapRow({
      'list': 1,
      'opens_at': '09:30:00',
      'availability': '{[2026-06-01,2026-06-08),[2026-07-01,2026-07-08)}',
      'shifts': '{["2026-07-23 09:00:00","2026-07-23 17:00:00")}',
    });

    expect(
      row.availability,
      PostgresMultirange([
        PostgresRange.closedOpen(
          PostgresDate(2026, 6, 1),
          PostgresDate(2026, 6, 8),
        ),
        PostgresRange.closedOpen(
          PostgresDate(2026, 7, 1),
          PostgresDate(2026, 7, 8),
        ),
      ]),
    );
    expect(
      row.shifts,
      PostgresMultirange([
        PostgresRange.closedOpen(
          DateTime(2026, 7, 23, 9),
          DateTime(2026, 7, 23, 17),
        ),
      ]),
    );

    httpClient.stub(null);
    await client
        .table(hostile.Map$.table)
        .update(
          hostile.MapUpdate(availability: row.availability, shifts: row.shifts),
        )
        .where(hostile.Map$.availability.eq(row.availability!));

    final request = httpClient.requests.last;
    expect(request.jsonBody, {
      'availability': '{[2026-06-01,2026-06-08),[2026-07-01,2026-07-08)}',
      'shifts': '{[2026-07-23T09:00:00.000,2026-07-23T17:00:00.000)}',
    });
    expect(
      request.queryParameters['availability'],
      'eq.{[2026-06-01,2026-06-08),[2026-07-01,2026-07-08)}',
    );
  });

  test('geometric columns read, write and filter as values', () async {
    final row = hostile.MapRow({
      'list': 1,
      'opens_at': '09:30:00',
      'location': '(1.5,-2)',
      'axis': '{1,-1,0}',
      'edge': '[(0,0),(1,1)]',
      'bounds': '(2,3),(0,0)',
      'route': '[(0,0),(1,1)]',
      'outline': '((0,0),(1,1),(1,0))',
      'reach': '<(1,2),3>',
    });

    expect(row.location, const PostgresPoint(1.5, -2));
    expect(row.axis, const PostgresLine(1, -1, 0));
    expect(
      row.edge,
      const PostgresLineSegment(PostgresPoint(0, 0), PostgresPoint(1, 1)),
    );
    expect(
      row.bounds,
      PostgresBox(const PostgresPoint(0, 0), const PostgresPoint(2, 3)),
    );
    expect(row.route?.isClosed, isFalse);
    expect(row.outline?.points, hasLength(3));
    expect(row.reach, const PostgresCircle(PostgresPoint(1, 2), 3));

    httpClient.stub(null);
    await client
        .table(hostile.Map$.table)
        .update(
          hostile.MapUpdate(
            location: row.location,
            axis: row.axis,
            edge: row.edge,
            bounds: row.bounds,
            route: row.route,
            outline: row.outline,
            reach: row.reach,
          ),
        )
        .where(hostile.Map$.reach.eq(row.reach!));

    final request = httpClient.requests.last;
    expect(request.jsonBody, {
      'location': '(1.5,-2)',
      'axis': '{1,-1,0}',
      'edge': '[(0,0),(1,1)]',
      'bounds': '(2,3),(0,0)',
      'route': '[(0,0),(1,1)]',
      'outline': '((0,0),(1,1),(1,0))',
      'reach': '<(1,2),3>',
    });
    expect(request.queryParameters['reach'], 'eq.<(1,2),3>');
  });

  test(
    'network addresses read, write and filter as values',
    () async {
      final row = hostile.MapRow({
        'list': 1,
        'opens_at': '09:30:00',
        'host': '2001:db8::1/64',
        'allowed_networks': ['10.0.0.0/8', '192.168.1.5/32'],
      });

      expect(
        row.host,
        PostgresNetworkAddress([
          0x20,
          0x01,
          0x0D,
          0xB8,
          ...List.filled(11, 0),
          1,
        ], prefixLength: 64),
      );
      expect(row.allowedNetworks, [
        PostgresNetworkAddress([10, 0, 0, 0], prefixLength: 8),
        PostgresNetworkAddress([192, 168, 1, 5]),
      ]);

      httpClient.stub(null);
      await client
          .table(hostile.Map$.table)
          .update(
            hostile.MapUpdate(
              host: row.host,
              allowedNetworks: row.allowedNetworks,
            ),
          )
          .where(hostile.Map$.host.eq(row.host!));

      final request = httpClient.requests.last;
      expect(request.jsonBody, {
        'host': '2001:db8::1/64',
        'allowed_networks': ['10.0.0.0/8', '192.168.1.5'],
      });
      expect(request.queryParameters['host'], 'eq.2001:db8::1/64');
    },
  );

  test(
    'log sequence numbers and MAC addresses read, write and filter as values',
    () async {
      final row = hostile.MapRow({
        'list': 1,
        'opens_at': '09:30:00',
        'position': '16/B374D848',
        'hardware': '08:00:2b:01:02:03',
        'hardware_history': ['08:00:2b:01:02:03:04:05'],
      });

      expect(row.position, PostgresLogSequenceNumber(0x16, 0xB374D848));
      expect(row.hardware, PostgresMacAddress([8, 0, 0x2B, 1, 2, 3]));
      expect(row.hardwareHistory, [
        PostgresMacAddress([8, 0, 0x2B, 1, 2, 3, 4, 5]),
      ]);

      httpClient.stub(null);
      await client
          .table(hostile.Map$.table)
          .update(
            hostile.MapUpdate(
              position: row.position,
              hardware: row.hardware,
              hardwareHistory: row.hardwareHistory,
            ),
          )
          .where(
            hostile.Map$.position.gt(PostgresLogSequenceNumber(0x16, 0)) &
                hostile.Map$.hardwareHistory.contains([row.hardware!]),
          );

      final request = httpClient.requests.last;
      expect(request.jsonBody, {
        'position': '16/B374D848',
        'hardware': '08:00:2b:01:02:03',
        'hardware_history': ['08:00:2b:01:02:03:04:05'],
      });
      expect(request.queryParameters['position'], 'gt.16/0');
      expect(
        request.queryParameters['hardware_history'],
        'cs.{08:00:2b:01:02:03}',
      );
    },
  );

  test(
    'array elements read, write and filter through their conversions',
    () async {
      final row = hostile.PostgrestTableRow({
        'days': ['2026-01-01', '2028-02-29'],
        'blobs': [r'\x4869'],
        'moods': ['plain'],
        'spans': ['[1,3)', 'empty'],
        'stamps': ['2026-07-23T10:00:00+00:00'],
      });

      expect(row.days, [PostgresDate(2026, 1, 1), PostgresDate(2028, 2, 29)]);
      expect(row.blobs, [
        [72, 105],
      ]);
      expect(row.moods, [hostile.String$.plain]);
      expect(row.spans, [
        const PostgresRange.closedOpen(1, 3),
        const PostgresRange<int>.empty(),
      ]);
      expect(row.stamps, [DateTime.utc(2026, 7, 23, 10)]);

      httpClient.stub(null);
      await client
          .table(hostile.PostgrestTable$.table)
          .insert(
            hostile.PostgrestTableInsert(
              quoteNameTail: 'row',
              samples: [1.5],
              postgresBytea$: Uint8List.fromList([1]),
              postgresVector$: [0.5],
              spans: row.spans,
              days: row.days,
              blobs: row.blobs,
              moods: row.moods,
              stamps: [DateTime(2026, 7, 23, 12)],
            ),
          );

      final sent = httpClient.requests.last.jsonBody as Map<String, dynamic>;
      expect(sent['days'], ['2026-01-01', '2028-02-29']);
      expect(sent['blobs'], [r'\x4869']);
      expect(sent['moods'], ['plain']);
      expect(sent['spans'], ['[1,3)', 'empty']);
      expect(sent['stamps'], [
        DateTime(2026, 7, 23, 12).toUtc().toIso8601String(),
      ]);

      httpClient.stub([]);
      await client
          .table(hostile.PostgrestTable$.table)
          .select()
          .where(
            hostile.PostgrestTable$.days.contains([PostgresDate(2026, 1, 1)]) &
                hostile.PostgrestTable$.moods.overlaps([hostile.String$.plain]),
          );

      final parameters = httpClient.requests.last.queryParameters;
      expect(parameters['days'], 'cs.{2026-01-01}');
      expect(parameters['moods'], 'ov.{plain}');
    },
  );

  test('unknown enum wire values throw a descriptive error', () {
    expect(
      () => Mood.fromWire('grumpy'),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('No Mood value'),
        ),
      ),
    );
  });

  test('update sends only the provided columns', () async {
    httpClient.stub(null);

    await client
        .table(Books.table)
        .update(BooksUpdate(inPrint: false))
        .where(Books.id.eq(1));

    expect(httpClient.requests.last.jsonBody, {'in_print': false});
    expect(httpClient.requests.last.queryParameters['id'], 'eq.1');
  });

  test('setXToNull writes SQL NULL explicitly', () async {
    httpClient.stub(null);

    final update = BooksUpdate(inPrint: false);
    await client
        .table(Books.table)
        .update(update.setPriceToNull().setMoodToNull())
        .where(Books.id.eq(1));

    expect(httpClient.requests.last.jsonBody, {
      'in_print': false,
      'price': null,
      'mood': null,
    });
    await client.table(Books.table).update(update).where(Books.id.eq(1));
    expect(
      httpClient.requests.last.jsonBody,
      {'in_print': false},
      reason: 'setPriceToNull returns a copy and must not mutate',
    );

    await client
        .table(Books.table)
        .insert(
          BooksInsert(title: 'x', authorId: 7).setPublishedOnToNull(),
        );

    expect(httpClient.requests.last.jsonBody, {
      'title': 'x',
      'author_id': 7,
      'published_on': null,
    });
  });
  test('computed fields are selected by name and read as nullable', () async {
    httpClient.stub([
      {'id': 1, 'title_upper': 'A TYPED ROW', 'mood_or_default': 'happy'},
      {'id': 2, 'title_upper': null, 'mood_or_default': null},
    ]);

    final books = await client
        .table(Books.table)
        .selectOnly([Books.id, Books.titleUpper, Books.moodOrDefault])
        .where(Books.moodOrDefault.eq(Mood.happy))
        .order(Books.titleUpper);

    expect(httpClient.requests.last.queryParameters, {
      'select': 'id,title_upper,mood_or_default',
      'mood_or_default': 'eq.happy',
      'order': 'title_upper',
    });
    final String? title = books.first.read(Books.titleUpper);
    expect(title, 'A TYPED ROW');
    expect(books.first.read(Books.moodOrDefault), Mood.happy);
    expect(books.last.read(Books.titleUpper), isNull);
    expect(books.last.read(Books.moodOrDefault), isNull);
    expect(Books.table.computedFields, [Books.moodOrDefault, Books.titleUpper]);
  });

  test('computed relationships embed the rows of the returned table', () async {
    httpClient.stub([
      {
        'id': 7,
        'recent_books': [
          {'id': 1, 'title': 'A typed row'},
        ],
        'latest_book': {'id': 1, 'title': 'A typed row'},
      },
    ]);

    final authors = await client.table(Authors.table).selectOnly([
      Authors.id,
      Authors.recentBooks.select([Books.id, Books.title]),
      Authors.latestBook(Books.id),
      Authors.latestBook(Books.title),
    ]);

    expect(
      httpClient.requests.last.queryParameters['select'],
      'id,recent_books(id,title),latest_book(id,title)',
    );
    final author = authors.single;
    final List<PostgrestPartialRow<BooksRow>> recent = author.read(
      Authors.recentBooks,
    );
    expect(recent.single.read(Books.title), 'A typed row');
    final PostgrestPartialRow<BooksRow>? latest = author.read(
      Authors.latestBook,
    );
    expect(latest?.read(Books.id), 1);
    expect(Authors.table.relations, [
      Authors.authorStats,
      Authors.books,
      Authors.latestBook,
      Authors.recentBooks,
    ]);
  });

  group('functions', () {
    RecordedRequest lastRequest() => httpClient.requests.last;

    test('a set of rows takes typed arguments and reads typed rows', () async {
      httpClient.stub([
        {'id': 1, 'title': 'A typed row', 'mood': 'very happy'},
      ], path: '/rest/v1/rpc/search_books');

      final List<BooksRow> books = await client.rpc
          .searchBooks(query: 'typed', mood: Mood.veryHappy)
          .where(Books.id.gt(0))
          .order(Books.title.asc());

      expect(books.single.mood, Mood.veryHappy);
      expect(lastRequest().method, HttpMethod.get.value);
      expect(lastRequest().url.queryParameters, {
        'mood': 'very happy',
        'query': 'typed',
        'id': 'gt.0',
        'order': 'title.asc',
      });
      expect(lastRequest().headers['accept-profile'], 'public');
    });

    test('a stable function is called read-only and retried', () async {
      httpClient.stubStatuses([503, 200], body: 3);
      final retrying = PostgrestClient(
        'http://localhost/rest/v1',
        httpClient: httpClient,
        retryOptions: const SupabaseRetryOptions(initialDelay: Duration.zero),
      );
      addTearDown(retrying.dispose);

      final int? count = await retrying.rpc.countBooks().retry(count: 1);

      expect(count, 3);
      expect(httpClient.requests, hasLength(2));
      expect(lastRequest().method, HttpMethod.get.value);
    });

    test('a volatile function is not retried', () async {
      httpClient.stubStatuses([503, 200], body: null);
      final retrying = PostgrestClient(
        'http://localhost/rest/v1',
        httpClient: httpClient,
        retryOptions: const SupabaseRetryOptions(initialDelay: Duration.zero),
      );
      addTearDown(retrying.dispose);

      await expectLater(
        () => retrying.rpc.touchBook(bookId: 2).retry(count: 1),
        throwsA(isA<PostgrestException>()),
      );
      expect(httpClient.requests, hasLength(1));
      expect(lastRequest().method, HttpMethod.post.value);
    });

    test('a function of another schema is called in its schema', () async {
      httpClient.stub(5);

      final int? quantity = await client.rpc.inventoryRestock(
        stockId: 1,
        amount: 4,
      );

      expect(quantity, 5);
      expect(lastRequest().url.path, '/rest/v1/rpc/restock');
      expect(lastRequest().headers['content-profile'], 'inventory');
      expect(lastRequest().jsonBody, {'stock_id': 1, 'amount': 4});
    });

    test('a single row reads the row', () async {
      httpClient.stub({'id': 3, 'title': 'One'});

      final BooksRow? book = await client.rpc.bookById(bookId: 3);

      expect(book?.title, 'One');
    });

    test('a single row that is not found reads as null', () async {
      httpClient.stub({'id': null, 'title': null});
      final BooksRow? allNull = await client.rpc.bookById(bookId: 999);
      expect(allNull == null, isTrue);

      httpClient.stub(null);
      final BooksRow? missing = await client.rpc.bookById(bookId: 999);
      expect(missing == null, isTrue);
    });

    test('RETURNS TABLE rows are read and filtered through their own '
        'column tokens', () async {
      httpClient.stub([
        {'author_name': 'Ada', 'book_count': 2},
      ]);

      final rows = await client.rpc
          .authorBookCounts()
          .where(AuthorBookCounts.bookCount.gte(2))
          .order(AuthorBookCounts.authorName.asc());

      expect(rows.single.authorName, 'Ada');
      expect(rows.single.bookCount, 2);
      expect(lastRequest().url.queryParameters, {
        'book_count': 'gte.2',
        'order': 'author_name.asc',
      });
    });

    test('scalars and sets of scalars are converted', () async {
      httpClient.stub(['2026-07-23', null]);
      final List<PostgresDate?> dates = await client.rpc.publicationDates(
        authorId: 1,
      );
      expect(dates, [PostgresDate(2026, 7, 23), null]);

      httpClient.stub('sad');
      final Mood? mood = await client.rpc.moodOrDefault(
        book: BooksRow({'id': 1, 'title': 'A typed row'}),
      );
      expect(mood, Mood.sad);
      expect(lastRequest().method, HttpMethod.post.value);
      expect(lastRequest().jsonBody, {
        'book': {'id': 1, 'title': 'A typed row'},
      });

      httpClient.stub(null);
      final int? count = await client.rpc.countBooks();
      expect(count, isNull);
    });

    test('optional arguments left out are not sent', () async {
      httpClient.stub(null);

      await client.rpc.touchBook(bookId: 2);
      expect(lastRequest().jsonBody, {'book_id': 2});

      await client.rpc.touchBook(
        bookId: 2,
        touchedAt: DateTime.utc(2026, 7, 23, 10),
      );
      expect(lastRequest().jsonBody, {
        'book_id': 2,
        'touched_at': '2026-07-23T10:00:00.000Z',
      });
    });

    test('overloads get a method each', () async {
      httpClient.stub([]);

      await client.rpc.booksOf(authorId: 1);
      expect(lastRequest().url.queryParameters, {'author_id': '1'});

      await client.rpc.booksOfWithAuthorNameAndMaxPrice(
        authorName: 'Ada',
        maxPrice: 10,
      );
      expect(lastRequest().url.queryParameters, {
        'author_name': 'Ada',
        'max_price': '10',
      });
    });

    test('a sole unnamed json parameter is sent as the whole body', () async {
      httpClient.stub({'echoed': true});
      final echoed = await client.rpc.echo({'echoed': true});
      expect(echoed, {'echoed': true});
      expect(lastRequest().method, HttpMethod.post.value);
      expect(lastRequest().jsonBody, {'echoed': true});
    });

    test(
      'the untyped call still works next to the generated methods',
      () async {
        httpClient.stub(3);

        final count = await client.rpc('count_books');

        expect(count, 3);
      },
    );
  });
}
