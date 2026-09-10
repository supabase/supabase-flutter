// The typed table access API under test is annotated @experimental.
// ignore_for_file: experimental_member_use

import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

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
        'published_on': null,
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
    expect(book.publishedOn == null, isTrue);
  });

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
    'timestamps are sent as UTC instants and dates keep their day',
    () async {
      httpClient.stub(null);

      await client
          .table(Books.table)
          .insert(
            BooksInsert(
              title: 'A typed row',
              authorId: 7,
              createdAt: DateTime(2026, 7, 23, 10), // local wall time
              publishedOn: DateTime(2026, 7, 23, 23, 30),
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
    expect(
      update.containsKey('price'),
      isFalse,
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
