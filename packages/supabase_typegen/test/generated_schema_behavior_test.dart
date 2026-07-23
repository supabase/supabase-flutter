// The typed table access API under test is annotated @experimental.
// ignore_for_file: experimental_member_use

import 'dart:convert';

import 'package:http/http.dart';
import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

import 'goldens/supabase_schema.dart';

class MockHttpClient extends BaseClient {
  String responseBody = '[]';
  BaseRequest? lastRequest;
  String? lastRequestBody;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastRequest = request;
    lastRequestBody = utf8.decode(await request.finalize().toBytes());
    return StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

void main() {
  late MockHttpClient httpClient;
  late PostgrestClient client;

  setUp(() {
    httpClient = MockHttpClient();
    client = PostgrestClient(
      'http://localhost/rest/v1',
      httpClient: httpClient,
    );
  });

  tearDown(() async {
    await client.dispose();
  });

  test('select returns typed rows with converted values', () async {
    httpClient.responseBody = jsonEncode([
      {
        'id': 1,
        'title': 'A typed row',
        'author_id': 7,
        'price': 12.5,
        'rating': 4,
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
    expect(book.mood, Mood.veryHappy);
    expect(book.tags, ['dart', 'types']);
    expect(book.metadata, {'reprint': true});
    expect(book.createdAt, DateTime.utc(2026, 7, 23, 10));
    expect(book.publishedOn == null, isTrue);
  });

  test('enum column tokens filter with the wire name', () async {
    await client.table(Books.table).select().where(Books.mood.eq(Mood.happy));

    expect(
      httpClient.lastRequest!.url.queryParameters['mood'],
      'eq.happy',
    );
  });

  test('insert sends converted values and omits absent columns', () async {
    httpClient.responseBody = '';

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

    final sent =
        jsonDecode(httpClient.lastRequestBody!) as Map<String, dynamic>;
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
      httpClient.responseBody = '';

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

      final sent =
          jsonDecode(httpClient.lastRequestBody!) as Map<String, dynamic>;
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
    httpClient.responseBody = '';

    await client
        .table(Books.table)
        .update(BooksUpdate(inPrint: false))
        .where(Books.id.eq(1));

    expect(jsonDecode(httpClient.lastRequestBody!), {'in_print': false});
    expect(httpClient.lastRequest!.url.queryParameters['id'], 'eq.1');
  });

  test('setXToNull writes SQL NULL explicitly', () async {
    httpClient.responseBody = '';

    final update = BooksUpdate(inPrint: false);
    await client
        .table(Books.table)
        .update(update.setPriceToNull().setMoodToNull())
        .where(Books.id.eq(1));

    expect(jsonDecode(httpClient.lastRequestBody!), {
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

    expect(jsonDecode(httpClient.lastRequestBody!), {
      'title': 'x',
      'author_id': 7,
      'published_on': null,
    });
  });
}
