import 'dart:convert';

import 'package:http/http.dart';
import 'package:postgrest/postgrest.dart';
import 'package:test/test.dart';

extension type Book(Map<String, dynamic> json) {
  int get id => json['id'] as int;
  String get title => json['title'] as String;
}

class Books {
  static const table = PostgrestTable('books', Book.new);
  static const id = TableColumn<int>('id');
  static const title = TableColumn<String>('title');
  static const tags = TableColumn<List<String>>('tags');
  static const ageRange = TableColumn<String>('age_range');
}

class MockHttpClient extends BaseClient {
  String responseBody = '[]';
  int statusCode = 200;
  Map<String, String> responseHeaders = {'content-type': 'application/json'};
  BaseRequest? lastRequest;
  String? lastRequestBody;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    lastRequest = request;
    lastRequestBody = utf8.decode(await request.finalize().toBytes());
    return StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
      statusCode,
      headers: responseHeaders,
      request: request,
    );
  }
}

void main() {
  late MockHttpClient httpClient;
  late PostgrestClient client;

  const bookRows = '[{"id":1,"title":"a"},{"id":2,"title":"b"}]';

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

  Map<String, String> requestParameters() =>
      httpClient.lastRequest!.url.queryParameters;

  group('select', () {
    test('returns rows converted into the table row type', () async {
      httpClient.responseBody = bookRows;

      final List<Book> books = await client.table(Books.table).select();

      expect(httpClient.lastRequest!.url.path, '/rest/v1/books');
      expect(requestParameters()['select'], '*');
      expect(books.map((book) => book.title), ['a', 'b']);
    });

    test('single returns one row converted into the table row type', () async {
      httpClient.responseBody = '{"id":1,"title":"a"}';

      final Book book = await client
          .table(Books.table)
          .select()
          .where(Books.id.eq(1))
          .single();

      expect(
        httpClient.lastRequest!.headers['Accept'],
        'application/vnd.pgrst.object+json',
      );
      expect(book.title, 'a');
    });

    test('maybeSingle returns null when no row matches', () async {
      httpClient.responseBody = '[]';

      final Book? book = await client
          .table(Books.table)
          .select()
          .where(Books.id.eq(1))
          .maybeSingle();

      expect(book, isNull);
    });

    test('maybeSingle returns the row when one matches', () async {
      httpClient.responseBody = '[{"id":1,"title":"a"}]';

      final Book? book = await client
          .table(Books.table)
          .select()
          .where(Books.id.eq(1))
          .maybeSingle();

      expect(book?.title, 'a');
    });

    test('count returns typed rows together with the count', () async {
      httpClient.responseBody = bookRows;
      httpClient.responseHeaders = {
        'content-type': 'application/json',
        'content-range': '0-1/10',
      };

      final PostgrestResponse<List<Book>> response = await client
          .table(Books.table)
          .select()
          .count(CountOption.exact);

      expect(
        httpClient.lastRequest!.headers['Prefer'],
        contains('count=exact'),
      );
      expect(response.data.map((book) => book.id), [1, 2]);
      expect(response.count, 10);
    });
  });

  group('where', () {
    setUp(() {
      httpClient.responseBody = bookRows;
    });

    test('chained filters combine with logical AND', () async {
      await client
          .table(Books.table)
          .select()
          .where(Books.id.eq(1))
          .where(Books.title.like('%a%'));

      expect(requestParameters()['id'], 'eq.1');
      expect(requestParameters()['title'], 'like.%a%');
    });

    test('builds the same URLs as the untyped filters', () async {
      final filters = {
        Books.id.eq(1): ('id', 'eq.1'),
        Books.id.neq(1): ('id', 'neq.1'),
        Books.id.gt(1): ('id', 'gt.1'),
        Books.id.gte(1): ('id', 'gte.1'),
        Books.id.lt(1): ('id', 'lt.1'),
        Books.id.lte(1): ('id', 'lte.1'),
        Books.id.eq(1).not(): ('id', 'not.eq.1'),
        Books.title.isNull(): ('title', 'is.null'),
        Books.title.isNotNull(): ('title', 'not.is.null'),
        Books.id.inFilter([1, 2]): ('id', 'in.(1,2)'),
        Books.id.isDistinctFrom(5): ('id', 'isdistinct.5'),
        Books.tags.contains(['a', 'b']): ('tags', 'cs.{"a","b"}'),
        Books.tags.containedBy(['a', 'b']): ('tags', 'cd.{"a","b"}'),
        Books.ageRange.overlaps('[2,25)'): ('age_range', 'ov.[2,25)'),
        Books.ageRange.rangeLt('[2,25)'): ('age_range', 'sl.[2,25)'),
        Books.ageRange.rangeGt('[2,25)'): ('age_range', 'sr.[2,25)'),
        Books.ageRange.rangeGte('[2,25)'): ('age_range', 'nxl.[2,25)'),
        Books.ageRange.rangeLte('[2,25)'): ('age_range', 'nxr.[2,25)'),
        Books.ageRange.rangeAdjacent('[2,25)'): ('age_range', 'adj.[2,25)'),
        Books.title.ilike('%a%'): ('title', 'ilike.%a%'),
        Books.title.likeAllOf(['%a%', '%b%']): ('title', 'like(all).{%a%,%b%}'),
        Books.title.likeAnyOf(['%a%', '%b%']): ('title', 'like(any).{%a%,%b%}'),
        Books.title.ilikeAllOf(['%a%', '%b%']): (
          'title',
          'ilike(all).{%a%,%b%}',
        ),
        Books.title.ilikeAnyOf(['%a%', '%b%']): (
          'title',
          'ilike(any).{%a%,%b%}',
        ),
        Books.title.matchRegex('^a'): ('title', 'match.^a'),
        Books.title.imatchRegex('^a'): ('title', 'imatch.^a'),
        Books.title.textSearch(
          "'fat' & 'cat'",
          config: 'english',
        ): (
          'title',
          "fts(english).'fat' & 'cat'",
        ),
        Books.title.textSearch('fat cat', type: TextSearchType.websearch): (
          'title',
          'wfts.fat cat',
        ),
      };

      for (final entry in filters.entries) {
        await client.table(Books.table).select().where(entry.key);

        final (column, value) = entry.value;
        expect(
          requestParameters()[column],
          value,
          reason: 'filter on "$column" with "$value"',
        );
      }
    });

    test('whereAny combines filters with logical OR', () async {
      await client.table(Books.table).select().whereAny([
        Books.id.eq(1),
        Books.title.eq('foo'),
      ]);

      expect(requestParameters()['or'], '(id.eq.1,title.eq."foo")');
    });

    test('whereAny quotes values with reserved characters', () async {
      await client.table(Books.table).select().whereAny([
        Books.title.eq('foo,bar'),
        Books.id.inFilter([1, 2]),
      ]);

      expect(requestParameters()['or'], '(title.eq."foo,bar",id.in.(1,2))');
    });

    test('negating a filter twice throws', () {
      expect(() => Books.id.eq(1).not().not(), throwsStateError);
    });
  });

  group('transforms', () {
    setUp(() {
      httpClient.responseBody = bookRows;
    });

    test('order, limit and range keep the row type', () async {
      final List<Book> books = await client
          .table(Books.table)
          .select()
          .where(Books.id.gt(0))
          .order(Books.title, ascending: true)
          .limit(2);

      expect(requestParameters()['order'], 'title.asc.nullslast');
      expect(requestParameters()['limit'], '2');
      expect(books, hasLength(2));

      await client.table(Books.table).select().range(0, 1);

      expect(requestParameters()['offset'], '0');
      expect(requestParameters()['limit'], '2');
    });
  });

  group('mutations', () {
    test('insert posts the values', () async {
      httpClient.responseBody = '';

      await client.table(Books.table).insert({'title': 'foo'});

      expect(httpClient.lastRequest!.method, 'POST');
      expect(httpClient.lastRequestBody, '{"title":"foo"}');
    });

    test('insert with a trailing select returns the typed row', () async {
      httpClient.responseBody = '{"id":3,"title":"foo"}';

      final Book book = await client
          .table(Books.table)
          .insert({'title': 'foo'})
          .select()
          .single();

      expect(httpClient.lastRequest!.method, 'POST');
      expect(
        httpClient.lastRequest!.headers['Prefer'],
        contains('return=representation'),
      );
      expect(book.id, 3);
    });

    test('upsert sets the resolution header', () async {
      httpClient.responseBody = '';

      await client.table(Books.table).upsert({'id': 1, 'title': 'foo'});

      expect(
        httpClient.lastRequest!.headers['Prefer'],
        contains('resolution=merge-duplicates'),
      );
    });

    test('update patches the filtered rows', () async {
      httpClient.responseBody = '';

      await client
          .table(Books.table)
          .update({'title': 'bar'})
          .where(Books.id.eq(1));

      expect(httpClient.lastRequest!.method, 'PATCH');
      expect(requestParameters()['id'], 'eq.1');
      expect(httpClient.lastRequestBody, '{"title":"bar"}');
    });

    test('delete uses the filtered rows', () async {
      httpClient.responseBody = '';

      await client.table(Books.table).delete().where(Books.id.eq(1));

      expect(httpClient.lastRequest!.method, 'DELETE');
      expect(requestParameters()['id'], 'eq.1');
    });
  });

  group('count', () {
    test('count on the table returns the number of rows', () async {
      httpClient.responseBody = '';
      httpClient.responseHeaders = {
        'content-type': 'application/json',
        'content-range': '*/42',
      };

      final int count = await client.table(Books.table).count();

      expect(httpClient.lastRequest!.method, 'HEAD');
      expect(count, 42);
    });
  });
}
