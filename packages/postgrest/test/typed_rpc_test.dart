import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

extension type const Book(Map<String, dynamic> _json) implements Object {
  int get id => _json['id'] as int;
  String get title => _json['title'] as String;
}

class Books {
  static const id = PostgrestColumn<Book, int>('id');
  static const title = PostgrestColumn<Book, String>('title');
}

const bookRows = [
  {'id': 1, 'title': 'a'},
  {'id': 2, 'title': 'b'},
];

void main() {
  late MockSupabaseHttpClient httpClient;
  late PostgrestClient client;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    client = PostgrestClient(
      'http://localhost/rest/v1',
      httpClient: httpClient,
    );
  });

  tearDown(() async {
    await client.dispose();
  });

  RecordedRequest lastRequest() => httpClient.requests.last;

  group('call', () {
    test('performs an untyped call', () async {
      httpClient.stub('ok', path: '/rest/v1/rpc/get_status');

      final status = await client.rpc(
        'get_status',
        params: {'name': 'supabot'},
      );

      expect(status, 'ok');
      expect(lastRequest().method, HttpMethod.post.value);
      expect(lastRequest().jsonBody, {'name': 'supabot'});
    });

    test('passes the type argument and the read-only flag on', () async {
      httpClient.stub(bookRows);

      final PostgrestList rows = await client.rpc<PostgrestList>(
        'list_books',
        params: {'limit': 2},
        get: true,
      );

      expect(rows, bookRows);
      expect(lastRequest().method, HttpMethod.get.value);
      expect(lastRequest().url.queryParameters, {'limit': '2'});
    });

    test('calls in the schema the client was scoped to', () async {
      httpClient.stub(null);

      await client.schema('inventory').rpc('restock');

      expect(lastRequest().headers['content-profile'], 'inventory');
    });
  });

  group('rows', () {
    test('converts the returned rows into the row type', () async {
      httpClient.stub(bookRows, path: '/rest/v1/rpc/search_books');

      final List<Book> books = await client.rpc.rows(
        'search_books',
        arguments: {'query': 'dart'},
        rowFromJson: Book.new,
      );

      expect(books.map((book) => book.title), ['a', 'b']);
      expect(lastRequest().method, HttpMethod.post.value);
      expect(lastRequest().jsonBody, {'query': 'dart'});
      expect(lastRequest().url.queryParameters, isEmpty);
    });

    test('applies filters, orderings and limits to the result', () async {
      httpClient.stub(bookRows);

      await client.rpc
          .rows('search_books', rowFromJson: Book.new)
          .where(Books.id.gt(1))
          .order(Books.title.desc())
          .limit(5);

      expect(lastRequest().url.queryParameters, {
        'id': 'gt.1',
        'order': 'title.desc',
        'limit': '5',
      });
    });

    test('selects columns of the result as partial rows', () async {
      httpClient.stub([
        {'title': 'a'},
      ]);

      final rows = await client.rpc
          .rows('search_books', rowFromJson: Book.new)
          .selectOnly([Books.title]);

      expect(lastRequest().url.queryParameters, {'select': 'title'});
      expect(rows.single.read(Books.title), 'a');
    });

    test('reads a single row', () async {
      httpClient.stub(bookRows.first);

      final Book book = await client.rpc
          .rows('search_books', rowFromJson: Book.new)
          .single();

      expect(book.id, 1);
      expect(
        lastRequest().headers['accept'],
        'application/vnd.pgrst.object+json',
      );
    });

    test('counts the rows next to the result', () async {
      httpClient.stub(bookRows, headers: {'content-range': '0-1/2'});

      final response = await client.rpc
          .rows('search_books', rowFromJson: Book.new)
          .count();

      expect(response.data, hasLength(2));
      expect(response.count, 2);
    });

    test('sends the arguments of a head request as query parameters', () async {
      httpClient.stub(null);

      await client.rpc
          .rows(
            'search_books',
            arguments: {'query': 'dart'},
            rowFromJson: Book.new,
          )
          .where(Books.id.gt(1))
          .head();

      expect(lastRequest().method, HttpMethod.head.value);
      expect(lastRequest().url.queryParameters, {
        'query': 'dart',
        'id': 'gt.1',
      });
    });

    test('sends a read-only call as a get request', () async {
      httpClient.stub(bookRows);

      await client.rpc
          .rows(
            'search_books',
            arguments: {
              'query': 'dart',
              'tags': ['a', 'b,c'],
            },
            rowFromJson: Book.new,
            get: true,
          )
          .where(Books.id.gt(1));

      expect(lastRequest().method, HttpMethod.get.value);
      expect(lastRequest().url.queryParameters, {
        'query': 'dart',
        'tags': '{a,"b,c"}',
        'id': 'gt.1',
      });
    });

    test('sends a read-only call with a value PostgREST would read as a '
        'filter as a post request', () async {
      httpClient.stub(bookRows);

      for (final query in ['eq.dart', 'not.in.(a)', 'fts(english).dart']) {
        await client.rpc.rows(
          'search_books',
          arguments: {'query': query},
          rowFromJson: Book.new,
          get: true,
        );

        expect(lastRequest().method, HttpMethod.post.value);
        expect(lastRequest().jsonBody, {'query': query});
      }

      await client.rpc.rows(
        'search_books',
        arguments: {'query': 'equal.parts'},
        rowFromJson: Book.new,
        get: true,
      );
      expect(lastRequest().method, HttpMethod.get.value);
    });

    test('retries a read-only call', () async {
      httpClient.stubStatuses([503, 200], body: bookRows);
      final retrying = PostgrestClient(
        'http://localhost/rest/v1',
        httpClient: httpClient,
        retryOptions: const SupabaseRetryOptions(initialDelay: Duration.zero),
      );
      addTearDown(retrying.dispose);

      final books = await retrying.rpc
          .rows('search_books', rowFromJson: Book.new, get: true)
          .retry(count: 1);

      expect(books, hasLength(2));
      expect(httpClient.requests, hasLength(2));
    });

    test('does not retry a call that is not read-only', () async {
      httpClient.stubStatuses([503, 200], body: bookRows);
      final retrying = PostgrestClient(
        'http://localhost/rest/v1',
        httpClient: httpClient,
        retryOptions: const SupabaseRetryOptions(initialDelay: Duration.zero),
      );
      addTearDown(retrying.dispose);

      await expectLater(
        () => retrying.rpc
            .rows('search_books', rowFromJson: Book.new)
            .retry(count: 1),
        throwsA(isA<PostgrestException>()),
      );
      expect(httpClient.requests, hasLength(1));
    });

    test('rejects a read-only call with arguments that are not a map', () {
      expect(
        () => client.rpc.rows(
          'search_books',
          arguments: ['dart'],
          rowFromJson: Book.new,
          get: true,
        ),
        throwsArgumentError,
      );
    });

    test('calls in the schema it is given', () async {
      httpClient.stub(bookRows);

      await client.rpc.rows(
        'search_books',
        rowFromJson: Book.new,
        schema: 'inventory',
      );

      expect(lastRequest().headers['content-profile'], 'inventory');
    });

    test('calls in the schema the client was scoped to over the one it is '
        'given', () async {
      httpClient.stub(bookRows);

      await client
          .schema('archive')
          .rpc
          .rows('search_books', rowFromJson: Book.new, schema: 'inventory');

      expect(lastRequest().headers['content-profile'], 'archive');
    });
  });

  group('value', () {
    test('converts the response body', () async {
      httpClient.stub(3, path: '/rest/v1/rpc/count_books');

      final int? count = await client.rpc.value(
        'count_books',
        fromJson: (json) => json as int?,
      );

      expect(count, 3);
      expect(lastRequest().url.queryParameters, isEmpty);
    });

    test('sends the arguments as the request body', () async {
      httpClient.stub(null);

      await client.rpc.value(
        'log_event',
        arguments: {'kind': 'click'},
        fromJson: (json) {},
      );

      expect(lastRequest().jsonBody, {'kind': 'click'});
    });

    test('sends a read-only call as a get request', () async {
      httpClient.stub(3);

      await client.rpc.value(
        'count_books',
        arguments: {'author_id': 1},
        fromJson: (json) => json as int?,
        get: true,
      );

      expect(lastRequest().method, HttpMethod.get.value);
      expect(lastRequest().url.queryParameters, {'author_id': '1'});
    });

    test('sends a read-only call without arguments as a get request', () async {
      httpClient.stub(3);

      await client
          .schema('inventory')
          .rpc
          .value('count_books', fromJson: (json) => json as int?, get: true);

      expect(lastRequest().method, HttpMethod.get.value);
      expect(lastRequest().url.queryParameters, isEmpty);
      expect(lastRequest().headers['accept-profile'], 'inventory');
    });

    test('converts a list of scalars', () async {
      httpClient.stub([1, 2, null]);

      final List<int?> ids = await client.rpc.value(
        'book_ids',
        fromJson: (json) => (json! as List<dynamic>).cast(),
      );

      expect(ids, [1, 2, null]);
    });

    test('applies the request options', () async {
      httpClient.stub(3);

      await client.rpc
          .value('count_books', fromJson: (json) => json)
          .setHeader('x-trace', 'abc');

      expect(lastRequest().headers['x-trace'], 'abc');
    });
  });
}
