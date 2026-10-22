import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

extension type const Book(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  String get title => _json['title'] as String;
}

extension type const BookInsert._(Map<String, dynamic> _json)
    implements Object {
  BookInsert({required String title}) : this._({'title': title});
}

extension type const BookUpdate._(Map<String, dynamic> _json)
    implements Object {
  BookUpdate({String? title}) : this._({'title': ?title});
}

extension type const Review(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

class Books {
  static const table = PostgrestTable<Book, BookInsert, BookUpdate>(
    'books',
    Book.new,
    primaryKey: [id],
  );
  static const id = PostgrestColumn<Book, int>('id');
  static const title = PostgrestColumn<Book, String>('title');
  static const reviews = PostgrestToManyRelation<Book, Review>(
    'reviews',
    columns: [id],
    referencedTable: 'reviews',
    referencedColumns: [Reviews.bookId],
  );
}

class Reviews {
  static const bookId = PostgrestColumn<Review, int>('book_id');
}

const _objectMediaType = 'application/vnd.pgrst.object+json';

Map<String, Object?> _coerceError(int rows) => {
  'code': 'PGRST116',
  'details': 'The result contains $rows rows',
  'hint': null,
  'message': 'Cannot coerce the result to a single JSON object',
};

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

  Map<String, String> requestParameters() =>
      httpClient.requests.last.queryParameters;

  group('head()', () {
    test('throws after an untyped write instead of sending a HEAD', () {
      final users = client.from('users');
      final writes = <PostgrestTransformBuilder<Object?> Function()>[
        () => users.insert({'name': 'a'}),
        () => users.upsert({'name': 'a'}),
        () => users.update({'name': 'a'}).eq('id', 1),
        () => users.delete().eq('id', 1),
        () => users.insert({'name': 'a'}).select(),
        () => users.delete().eq('id', 1).select(),
      ];

      for (final write in writes) {
        expect(() => write().head(), throwsStateError);
      }
      expect(httpClient.requests, isEmpty);
    });

    test('throws after a typed write instead of sending a HEAD', () {
      final books = client.table(Books.table);
      final writes = <PostgrestTypedTransformBuilder<Book, Object?> Function()>[
        () => books.insert(BookInsert(title: 'a')),
        () => books.insertAll([BookInsert(title: 'a')]),
        () => books.upsert(BookInsert(title: 'a')),
        () => books.upsertAll([BookInsert(title: 'a')]),
        () => books.update(BookUpdate(title: 'a')).where(Books.id.eq(1)),
        () => books.delete().where(Books.id.eq(1)),
        () => books.delete().all().select(),
      ];

      for (final write in writes) {
        expect(() => write().head(), throwsStateError);
      }
      expect(httpClient.requests, isEmpty);
    });

    test('still sends a HEAD for a select and a count', () async {
      await client.from('users').select().eq('id', 1).head();
      await client.table(Books.table).select().where(Books.id.eq(1)).head();
      await client.from('users').count().head();

      expect(httpClient.requests.map((request) => request.method), [
        'HEAD',
        'HEAD',
        'HEAD',
      ]);
      expect(requestParameters()['select'], isNull);
    });

    test('moves the arguments of an untyped call to the query', () async {
      await client
          .rpc('search', params: {'query': 'dart', 'limit_to': 3})
          .eq('id', 1)
          .head();

      final request = httpClient.requests.single;
      expect(request.method, 'HEAD');
      expect(request.url.path, '/rest/v1/rpc/search');
      expect(request.queryParameters, {
        'id': 'eq.1',
        'query': 'dart',
        'limit_to': '3',
      });
    });

    test('sends an untyped call without arguments as a bare HEAD', () async {
      await client.rpc('ping').head();

      final request = httpClient.requests.single;
      expect(request.method, 'HEAD');
      expect(request.queryParameters, isEmpty);
    });

    test('rejects untyped call arguments that are not a Map', () {
      expect(
        () => client.rpcInSchema('sum', null, params: [1, 2]).head(),
        throwsArgumentError,
      );
      expect(httpClient.requests, isEmpty);
    });
  });

  group('maybeSingle()', () {
    test('asks for one object on an untyped write', () async {
      httpClient.stub({'id': 1});

      final row = await client
          .from('users')
          .delete()
          .eq('team', 1)
          .select()
          .maybeSingle();

      expect(row, {'id': 1});
      final request = httpClient.requests.single;
      expect(request.method, 'DELETE');
      expect(request.headers['Accept'], _objectMediaType);
    });

    test('asks for one object on a typed write', () async {
      httpClient.stub({'id': 1, 'title': 'a'});

      final Book? book = await client
          .table(Books.table)
          .delete()
          .where(Books.title.eq('a'))
          .select()
          .maybeSingle();

      expect(book?.title, 'a');
      final request = httpClient.requests.single;
      expect(request.method, 'DELETE');
      expect(request.headers['Accept'], _objectMediaType);
    });

    test('leaves the Accept header of a read alone', () async {
      await client.from('users').select().maybeSingle();
      await client.table(Books.table).select().maybeSingle();

      for (final request in httpClient.requests) {
        expect(request.headers['Accept'], isNot(_objectMediaType));
      }
    });

    test('surfaces a write that matched several rows as an error', () async {
      httpClient.stub(_coerceError(2), statusCode: 406);

      await expectLater(
        () =>
            client.from('users').delete().eq('team', 1).select().maybeSingle(),
        throwsA(
          isA<PostgrestApiException>()
              .having((error) => error.statusCode, 'statusCode', 406)
              .having((error) => error.errorCode, 'errorCode', 'PGRST116'),
        ),
      );
    });

    test('resolves a write that matched no row to null', () async {
      httpClient.stub(_coerceError(0), statusCode: 406);

      final row = await client
          .from('users')
          .update({'name': 'x'})
          .eq('id', 1)
          .select()
          .maybeSingle();
      final Book? book = await client
          .table(Books.table)
          .update(BookUpdate(title: 'x'))
          .where(Books.id.eq(1))
          .select()
          .maybeSingle();

      expect(row, isNull);
      expect(book == null, isTrue);
    });

    test('counts a write that matched no row as zero', () async {
      httpClient.stub(_coerceError(0), statusCode: 406);

      final response = await client
          .from('users')
          .update({'name': 'x'})
          .eq('id', 1)
          .select()
          .maybeSingle()
          .count();

      expect(response.data, isNull);
      expect(response.count, 0);
    });
  });

  group('typed count()', () {
    test('sends the filters as a HEAD request', () async {
      httpClient.stub(null, headers: {'content-range': '*/7'});

      final PostgrestTypedCountBuilder<Book> builder = client
          .table(Books.table)
          .count(CountOption.planned)
          .where(Books.id.gt(1))
          .where(Books.title.neq('a'))
          .setHeader('x-trace', '1');
      final int count = await builder;

      expect(count, 7);
      final request = httpClient.requests.single;
      expect(request.method, 'HEAD');
      expect(request.queryParameters, {'id': 'gt.1', 'title': 'neq.a'});
      expect(request.headers['Prefer'], contains('count=planned'));
      expect(request.headers['x-trace'], '1');
    });
  });

  group('rpc(get: true)', () {
    test('sends a call without arguments as a bare GET', () async {
      await client.rpc('ping', get: true);

      final request = httpClient.requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/rpc/ping');
      expect(request.queryParameters, isEmpty);
    });

    test('still rejects arguments that are not a Map', () {
      expect(
        () => client.rpcInSchema('sum', null, params: [1, 2], get: true),
        throwsArgumentError,
      );
    });
  });

  group('range()', () {
    test('rejects an end before the start', () {
      final users = client.from('users').select();
      final books = client.table(Books.table).select();

      expect(() => users.range(5, 2), throwsArgumentError);
      expect(
        () => users.range(5, 2, referencedTable: 'messages'),
        throwsArgumentError,
      );
      expect(() => books.range(5, 2), throwsArgumentError);
      expect(
        () => books.embedded(Books.reviews, (reviews) => reviews.range(5, 2)),
        throwsArgumentError,
      );
      expect(httpClient.requests, isEmpty);
    });

    test('accepts a single row range', () async {
      await client.from('users').select().range(5, 5);
      expect(requestParameters(), containsPair('limit', '1'));

      await client.table(Books.table).select().range(5, 5);
      expect(requestParameters(), containsPair('offset', '5'));
      expect(requestParameters(), containsPair('limit', '1'));
    });

    test('a typed limit of zero after a range keeps the offset', () async {
      await client
          .table(Books.table)
          .selectOnly([Books.id, Books.reviews.select()])
          .range(5, 9)
          .limit(0)
          .embedded(
            Books.reviews,
            (reviews) => reviews.range(2, 3).limit(0),
          );

      expect(requestParameters(), {
        'select': 'id,reviews(*)',
        'offset': '5',
        'limit': '0',
        'reviews.offset': '2',
        'reviews.limit': '0',
      });
    });
  });
}
