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
    expect(book.publishedOn, PostgrestDate(2026, 7, 23));
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
        'postgrest_bytea': r'\x',
        'postgrest_vector': '[0.5,-2.25,1]',
        'half_embedding': null,
      },
    ]);

    final List<hostile.PostgrestTableRow> rows = await client
        .table(hostile.PostgrestTable$.table)
        .select();

    expect(rows.single.postgrestVector$, [0.5, -2.25, 1.0]);
    expect(rows.single.halfEmbedding, isNull);

    httpClient.stub(null);
    await client
        .table(hostile.PostgrestTable$.table)
        .insert(
          hostile.PostgrestTableInsert(
            quoteNameTail: 'key',
            samples: [],
            postgrestBytea$: Uint8List(0),
            postgrestVector$: [0.5, -2.25],
            halfEmbedding: [0.75],
          ),
        );

    final sent = httpClient.requests.last.jsonBody as Map<String, dynamic>;
    expect(sent['postgrest_vector'], '[0.5,-2.25]');
    expect(sent['half_embedding'], '[0.75]');

    httpClient.stub([]);
    await client
        .table(hostile.PostgrestTable$.table)
        .select()
        .where(hostile.PostgrestTable$.postgrestVector$.eq([0.5, -2.25]));

    expect(
      httpClient.requests.last.queryParameters['postgrest_vector'],
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

      await client.table(InventoryStock.table).select([
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
    await client.table(Books.table).select([
      Books.id,
      Books.authors(Authors.name),
    ]);

    expect(
      httpClient.requests.last.queryParameters['select'],
      'id,authors(name)',
    );

    await client.table(Authors.table).select([
      Authors.id,
      Authors.books(Books.id).count(),
    ]);

    expect(
      httpClient.requests.last.queryParameters['select'],
      'id,books(id.count())',
    );
  });

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
              publishedOn: PostgrestDate(2026, 7, 23),
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

  test('date column tokens filter with the date literal', () async {
    await client
        .table(Books.table)
        .select()
        .where(Books.publishedOn.gte(PostgrestDate(2026, 1, 1)));

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
        PostgrestRange.closedOpen(
          PostgrestDate(2026, 6, 1),
          PostgrestDate(2026, 9, 1),
        ),
      );
      expect(row.since, PostgrestDate(2026, 7, 23));
      expect(row.opensAt, PostgrestTime(hour: 9, minute: 30));
      expect(
        row.closesAt,
        PostgrestTime(hour: 17, offset: const Duration(hours: 2)),
      );
      expect(
        row.ttl,
        const PostgrestInterval(
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
              pages: const PostgrestRange.closedOpen(1, 10),
              shift: PostgrestRange.closedOpen(
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
    'array elements read, write and filter through their conversions',
    () async {
      final row = hostile.PostgrestTableRow({
        'days': ['2026-01-01', '2028-02-29'],
        'blobs': [r'\x4869'],
        'moods': ['plain'],
        'spans': ['[1,3)', 'empty'],
        'stamps': ['2026-07-23T10:00:00+00:00'],
      });

      expect(row.days, [PostgrestDate(2026, 1, 1), PostgrestDate(2028, 2, 29)]);
      expect(row.blobs, [
        [72, 105],
      ]);
      expect(row.moods, [hostile.String$.plain]);
      expect(row.spans, [
        const PostgrestRange.closedOpen(1, 3),
        const PostgrestRange<int>.empty(),
      ]);
      expect(row.stamps, [DateTime.utc(2026, 7, 23, 10)]);

      httpClient.stub(null);
      await client
          .table(hostile.PostgrestTable$.table)
          .insert(
            hostile.PostgrestTableInsert(
              quoteNameTail: 'row',
              samples: [1.5],
              postgrestBytea$: Uint8List.fromList([1]),
              postgrestVector$: [0.5],
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
            hostile.PostgrestTable$.days.contains([PostgrestDate(2026, 1, 1)]) &
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
}
