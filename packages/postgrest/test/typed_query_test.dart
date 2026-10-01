import 'dart:async';

import 'package:postgrest/postgrest.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

extension type const Book(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  int get id => _json['id'] as int;
  String get title => _json['title'] as String;
}

extension type const BookInsert._(Map<String, dynamic> _json)
    implements Object {
  BookInsert({required String title, int? id})
    : this._({'title': title, 'id': ?id});
}

extension type const BookUpdate._(Map<String, dynamic> _json)
    implements Object {
  BookUpdate({String? title}) : this._({'title': ?title});
}

extension type const Author(Map<String, dynamic> _json)
    implements Map<String, dynamic> {}

const bookRows = [
  {'id': 1, 'title': 'a'},
  {'id': 2, 'title': 'b'},
];

class Books {
  static const table = PostgrestTable<Book, BookInsert, BookUpdate>(
    'books',
    Book.new,
    primaryKey: [id],
    relations: [author],
  );
  static const id = PostgrestColumn<Book, int>('id');
  static const authorId = PostgrestColumn<Book, int>('author_id');
  static const title = PostgrestColumn<Book, String>('title');
  static const tags = PostgrestColumn<Book, List<String>>('tags');
  static const ageRange = PostgrestColumn<Book, PostgrestRange<int>>(
    'age_range',
  );
  static const metadata = PostgrestColumn<Book, Map<String, dynamic>>(
    'metadata',
  );
  static const publishedOn = PostgrestNullableColumn<Book, DateTime>(
    'published_on',
  );
  static const author = PostgrestToOneRelation<Book, Author>(
    'author',
    columns: [authorId],
    referencedTable: 'authors',
    referencedColumns: [Authors.id],
  );
  static const editorId = PostgrestColumn<Book, int>('editor_id');
  static const editor = PostgrestToOneRelation<Book, Author>(
    'authors!books_editor_id_fkey',
    columns: [editorId],
    referencedTable: 'authors',
    referencedColumns: [Authors.id],
    alias: 'editor',
  );
}

class Authors {
  static const table = PostgrestTable<Author, Never, Never>(
    'authors',
    Author.new,
    primaryKey: [id],
    relations: [books],
  );
  static const id = PostgrestColumn<Author, int>('id');
  static const name = PostgrestColumn<Author, String>('name');
  static const books = PostgrestToManyRelation<Author, Book>(
    'books',
    columns: [id],
    referencedTable: 'books',
    referencedColumns: [Books.authorId],
  );
}

class BookClass {
  const BookClass();
}

class AuthorClass {
  const AuthorClass();
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

  Map<String, String> requestParameters() =>
      httpClient.requests.last.queryParameters;

  group('select', () {
    test('returns rows converted into the table row type', () async {
      httpClient.stub(bookRows);

      final List<Book> books = await client.table(Books.table).select();

      expect(httpClient.requests.last.url.path, '/rest/v1/books');
      expect(requestParameters()['select'], '*');
      expect(books.map((book) => book.title), ['a', 'b']);
    });

    test('selects the given columns', () async {
      httpClient.stub(bookRows);

      await client.table(Books.table).selectOnly([Books.id, Books.title]);

      expect(requestParameters()['select'], 'id,title');
    });

    test('selects casts and JSON paths', () async {
      httpClient.stub(bookRows);

      await client.table(Books.table).selectOnly([
        Books.id,
        Books.title.cast(PostgrestCastTarget.text),
        Books.metadata.jsonText('isbn'),
      ]);

      expect(requestParameters()['select'], 'id,title::text,metadata->>isbn');
    });

    test('selects aggregates', () async {
      httpClient.stub([
        {'count': 2, 'max': 'b'},
      ]);

      await client.table(Books.table).selectOnly([
        PostgrestDerivedExpression.countAll(),
        Books.title.max(),
      ]);

      expect(requestParameters()['select'], 'count(),title.max()');
    });

    test('selects and orders by embedded columns', () async {
      httpClient.stub([
        {
          'id': 1,
          'author': {'name': 'a'},
        },
      ]);

      await client
          .table(Books.table)
          .selectOnly([Books.id, Books.author(Authors.name)])
          .order(Books.author(Authors.name).desc());

      expect(requestParameters()['select'], 'id,author(name)');
      expect(requestParameters()['order'], 'author(name).desc');

      await client.table(Authors.table).selectOnly([
        Authors.id,
        Authors.books(Books.id).count(),
      ]);

      expect(requestParameters()['select'], 'id,books(id.count())');
    });

    test('projections of one relation are sent as a single embed', () async {
      // `author(id),author(name)` is a 42803 from Postgres.
      httpClient.stub([]);

      await client.table(Books.table).selectOnly([
        Books.author(Authors.id),
        Books.id,
        Books.author(Authors.name),
      ]);

      expect(requestParameters()['select'], 'author(id,name),id');

      await client.table(Authors.table).selectOnly([
        Authors.books(Books.id).count(),
        Authors.books(Books.title),
      ]);

      expect(requestParameters()['select'], 'books(id.count(),title)');
    });

    test('selects a whole embed', () async {
      httpClient.stub([]);

      await client.table(Books.table).selectOnly([
        Books.id,
        Books.author.select(),
      ]);

      expect(requestParameters()['select'], 'id,author(*)');

      await client.table(Books.table).selectOnly([
        Books.id,
        Books.author.select([Authors.id, Authors.name]),
      ]);

      expect(requestParameters()['select'], 'id,author(id,name)');
    });

    test(
      'a whole embed merges with projections of the same relation',
      () async {
        httpClient.stub([]);

        await client.table(Authors.table).selectOnly([
          Authors.books(Books.title),
          Authors.books.select(),
        ]);

        expect(requestParameters()['select'], 'books(*,title)');
      },
    );

    test('an aliased relation is its own embed', () async {
      httpClient.stub([]);

      await client
          .table(Books.table)
          .selectOnly([
            Books.editor(Authors.id),
            Books.author(Authors.name),
            Books.editor(Authors.name),
          ])
          .order(Books.editor(Authors.name).desc());

      expect(
        requestParameters()['select'],
        'editor:authors!books_editor_id_fkey(id,name),author(name)',
      );
      expect(requestParameters()['order'], 'editor(name).desc');
    });

    test('an entry selected twice is sent once', () async {
      httpClient.stub([]);

      await client.table(Books.table).selectOnly([
        Books.id,
        Books.author(Authors.id),
        Books.id,
        Books.author.select([Authors.id, Authors.name]),
      ]);

      expect(requestParameters()['select'], 'id,author(id,name)');
    });

    test('an empty column list throws, naming the parameter', () {
      expect(
        () => client.table(Books.table).selectOnly([]),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'columns')),
      );
    });

    test('single returns one row converted into the table row type', () async {
      httpClient.stub({'id': 1, 'title': 'a'});

      final Book book = await client
          .table(Books.table)
          .select()
          .where(Books.id.eq(1))
          .single();

      expect(
        httpClient.requests.last.headers['Accept'],
        'application/vnd.pgrst.object+json',
      );
      expect(book.title, 'a');
    });

    test('maybeSingle returns null when no row matches', () async {
      httpClient.stub([]);

      final Book? book = await client
          .table(Books.table)
          .select()
          .where(Books.id.eq(1))
          .maybeSingle();

      expect(book == null, isTrue);
    });

    test('maybeSingle returns the row when one matches', () async {
      httpClient.stub([
        {'id': 1, 'title': 'a'},
      ]);

      final Book? book = await client
          .table(Books.table)
          .select()
          .where(Books.id.eq(1))
          .maybeSingle();

      expect(book?.title, 'a');
    });

    test('count returns typed rows together with the count', () async {
      httpClient.stub(bookRows, headers: {'content-range': '0-1/10'});

      final PostgrestResponse<List<Book>> response = await client
          .table(Books.table)
          .select()
          .count(CountOption.exact);

      expect(
        httpClient.requests.last.headers['Prefer'],
        contains('count=exact'),
      );
      expect(response.data.map((book) => book.id), [1, 2]);
      expect(response.count, 10);
    });

    test('count after single wraps the typed row', () async {
      httpClient.stub(
        {'id': 1, 'title': 'a'},
        headers: {'content-range': '0-0/1'},
      );

      final PostgrestResponse<Book> response = await client
          .table(Books.table)
          .select()
          .where(Books.id.eq(1))
          .single()
          .count(CountOption.exact);

      expect(response.data.title, 'a');
      expect(response.count, 1);
    });

    test('count after maybeSingle wraps the missing row', () async {
      httpClient.stub([], headers: {'content-range': '*/0'});

      final PostgrestResponse<Book?> response = await client
          .table(Books.table)
          .select()
          .where(Books.id.eq(1))
          .maybeSingle()
          .count(CountOption.exact);

      expect(response.data == null, isTrue);
      expect(response.count, 0);
    });

    test('maybeSingle with more than one row throws', () {
      httpClient.stub(bookRows);

      expect(
        () => client.table(Books.table).select().maybeSingle(),
        throwsA(isA<PostgrestApiException>()),
      );
    });
  });

  group('where', () {
    setUp(() {
      httpClient.stub(bookRows);
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

    test('a top-level AND renders as separate parameters', () async {
      await client
          .table(Books.table)
          .select()
          .where(Books.id.gt(1) & Books.title.like('%a%'));

      expect(requestParameters()['id'], 'gt.1');
      expect(requestParameters()['title'], 'like.%a%');
    });

    test('an OR renders as one or parameter', () async {
      await client
          .table(Books.table)
          .select()
          .where(Books.id.eq(1) | Books.title.eq('foo'));

      expect(requestParameters()['or'], '(id.eq.1,title.eq.foo)');
    });

    test('a nested tree renders groups and escapes group operands', () async {
      await client
          .table(Books.table)
          .select()
          .where(
            (Books.id.eq(1) & Books.title.eq('foo,bar')) |
                Books.id.inFilter([2, 3]).not(),
          );

      expect(
        requestParameters()['or'],
        '(and(id.eq.1,title.eq."foo,bar"),id.not.in.(2,3))',
      );
    });

    test('the same column filtered twice keeps both parameters', () async {
      await client
          .table(Books.table)
          .select()
          .where(Books.id.gt(1) & Books.id.lt(10));

      expect(httpClient.requests.last.url.queryParametersAll['id'], [
        'gt.1',
        'lt.10',
      ]);
    });

    test('builds the same URLs as the untyped filters', () async {
      const ages = PostgrestRange.closedOpen(2, 25);
      final filters = {
        Books.id.eq(1): ('id', 'eq.1'),
        Books.id.neq(1): ('id', 'neq.1'),
        Books.id.gt(1): ('id', 'gt.1'),
        Books.id.gte(1): ('id', 'gte.1'),
        Books.id.lt(1): ('id', 'lt.1'),
        Books.id.lte(1): ('id', 'lte.1'),
        Books.id.eq(1).not(): ('id', 'not.eq.1'),
        Books.publishedOn.isNull(): ('published_on', 'is.null'),
        Books.publishedOn.isNull().not(): ('published_on', 'not.is.null'),
        Books.id.inFilter([1, 2]): ('id', 'in.(1,2)'),
        Books.id.isDistinct(5): ('id', 'isdistinct.5'),
        Books.tags.contains(['a', 'b']): ('tags', 'cs.{a,b}'),
        Books.tags.containedBy(['a', 'b']): ('tags', 'cd.{a,b}'),
        Books.ageRange.overlaps(ages): ('age_range', 'ov.[2,25)'),
        Books.ageRange.rangeLt(ages): ('age_range', 'sl.[2,25)'),
        Books.ageRange.rangeGt(ages): ('age_range', 'sr.[2,25)'),
        Books.ageRange.rangeGte(ages): ('age_range', 'nxl.[2,25)'),
        Books.ageRange.rangeLte(ages): ('age_range', 'nxr.[2,25)'),
        Books.ageRange.rangeAdjacent(ages): ('age_range', 'adj.[2,25)'),
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
        Books.title.textSearch("'fat' & 'cat'", config: 'english'): (
          'title',
          "fts(english).'fat' & 'cat'",
        ),
        Books.title.textSearch('fat cat', type: TextSearchType.websearch): (
          'title',
          'wfts.fat cat',
        ),
        Books.metadata.containsJson({'a': 1}): ('metadata', 'cs.{"a":1}'),
        Books.metadata.containsJson({'a': 1}).not(): (
          'metadata',
          'not.cs.{"a":1}',
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

    test('a raw filter reaches the request untouched', () async {
      await client
          .table(Books.table)
          .select()
          .where(PostgrestFilter.raw('cost::text', 'eq.10'));

      expect(requestParameters()['cost::text'], 'eq.10');
    });

    test('a filter carries the row type of its table', () {
      // Book and Author are extension types and erased at runtime, so the
      // check uses class row types.
      const id = PostgrestColumn<BookClass, int>('id');
      final Object filter = id.eq(1);

      expect(filter, isA<PostgrestFilter<BookClass>>());
      expect(filter, isNot(isA<PostgrestFilter<AuthorClass>>()));
    });
  });

  group('asStream', () {
    test('returns a broadcast stream that supports multiple listeners', () {
      httpClient.stub(bookRows);

      final stream = client.table(Books.table).select().asStream();

      expect(stream.isBroadcast, isTrue);
      stream.listen(
        expectAsync1((books) {
          expect(books, hasLength(2));
        }),
      );
      stream.listen(expectAsync1((books) {}));
    });
  });

  group('transforms', () {
    setUp(() {
      httpClient.stub(bookRows);
    });

    test('order sends only what was asked for', () async {
      await client.table(Books.table).select().order(Books.title);
      expect(
        requestParameters()['order'],
        'title',
        reason: 'a bare column leaves the direction to PostgREST',
      );

      await client.table(Books.table).select().order(Books.title.desc());
      expect(requestParameters()['order'], 'title.desc');

      await client
          .table(Books.table)
          .select()
          .order(Books.publishedOn.asc().nullsFirst());
      expect(requestParameters()['order'], 'published_on.asc.nullsfirst');

      await client
          .table(Books.table)
          .select()
          .order(Books.publishedOn.nullsLast());
      expect(requestParameters()['order'], 'published_on.nullslast');
    });

    test('order accepts a JSON path', () async {
      await client
          .table(Books.table)
          .select()
          .order(Books.metadata.jsonText('isbn').asc());

      expect(requestParameters()['order'], 'metadata->>isbn.asc');
    });

    test('repeated order calls merge into one parameter', () async {
      // PostgREST honours only the first `order` parameter it sees.
      await client
          .table(Books.table)
          .select()
          .order(Books.title.desc())
          .order(Books.id);

      expect(requestParameters()['order'], 'title.desc,id');
      expect(httpClient.requests.last.url.queryParametersAll['order'], [
        'title.desc,id',
      ]);
    });

    test('order, limit and range keep the row type', () async {
      final List<Book> books = await client
          .table(Books.table)
          .select()
          .where(Books.id.gt(0))
          .order(Books.title)
          .limit(2);

      expect(requestParameters()['limit'], '2');
      expect(books, hasLength(2));

      final List<Book> ranged = await client
          .table(Books.table)
          .select()
          .range(0, 1);

      expect(requestParameters()['offset'], '0');
      expect(requestParameters()['limit'], '2');
      expect(ranged.map((book) => book.id), [1, 2]);
    });
  });

  group('result modifiers', () {
    test('csv returns the body as text', () async {
      httpClient.stubText('id,title\n1,a\n', contentType: 'text/csv');

      final String csv = await client.table(Books.table).select().csv();

      expect(httpClient.requests.last.headers['Accept'], 'text/csv');
      expect(csv, 'id,title\n1,a\n');
    });

    test('csv keeps the other transforms', () async {
      httpClient.stubText('id,title\n1,a\n', contentType: 'text/csv');

      final String csv = await client
          .table(Books.table)
          .select()
          .where(Books.id.gt(0))
          .csv()
          .order(Books.title)
          .limit(1);

      expect(requestParameters()['id'], 'gt.0');
      expect(requestParameters()['order'], 'title');
      expect(requestParameters()['limit'], '1');
      expect(csv, 'id,title\n1,a\n');
    });

    test('explain returns the plan as text', () async {
      httpClient.stubText('Aggregate (cost=0.00..0.00)');

      final String plan = await client
          .table(Books.table)
          .select()
          .explain(analyze: true, format: ExplainFormat.json);

      expect(
        httpClient.requests.last.headers['Accept'],
        'application/vnd.pgrst.plan+json; for="application/json"; '
        'options=analyze;',
      );
      expect(plan, 'Aggregate (cost=0.00..0.00)');
    });

    test('head sends a HEAD request and resolves to nothing', () async {
      httpClient.stub(null);

      await client.table(Books.table).select().where(Books.id.eq(1)).head();

      expect(httpClient.requests.last.method, 'HEAD');
      expect(requestParameters()['id'], 'eq.1');
    });

    test('geojson returns the feature collection', () async {
      const collection = {'type': 'FeatureCollection', 'features': []};
      httpClient.stub(collection);

      final Map<String, dynamic> geojson = await client
          .table(Books.table)
          .select()
          .geojson();

      expect(
        httpClient.requests.last.headers['Accept'],
        startsWith('application/geo+json'),
      );
      expect(geojson, collection);
    });

    test('dryRun rolls back and keeps the row type', () async {
      httpClient.stub({'id': 3, 'title': 'foo'});

      final Book book = await client
          .table(Books.table)
          .insert(BookInsert(title: 'foo'))
          .select()
          .single()
          .dryRun();

      expect(httpClient.requests.last.method, 'POST');
      expect(
        httpClient.requests.last.headers['Prefer'],
        'return=representation,tx=rollback',
      );
      expect(book.id, 3);
    });

    test('stripNulls asks for stripped nulls and keeps the row type', () async {
      httpClient.stub(bookRows);

      final List<Book> books = await client
          .table(Books.table)
          .select()
          .stripNulls();

      expect(
        httpClient.requests.last.headers['Accept'],
        'application/json;nulls=stripped',
      );
      expect(books, hasLength(2));
    });

    test('maxAffected limits a delete', () async {
      httpClient.stub(null);

      await client
          .table(Books.table)
          .delete()
          .where(Books.id.gt(0))
          .maxAffected(10);

      expect(httpClient.requests.last.method, 'DELETE');
      expect(
        httpClient.requests.last.headers['Prefer'],
        'handling=strict,max-affected=10',
      );
    });

    test('maxAffected keeps the row type of an update', () async {
      httpClient.stub([
        {'id': 1, 'title': 'bar'},
      ]);

      final List<Book> books = await client
          .table(Books.table)
          .update(BookUpdate(title: 'bar'))
          .where(Books.id.eq(1))
          .maxAffected(1)
          .select();

      expect(httpClient.requests.last.method, 'PATCH');
      expect(
        httpClient.requests.last.headers['Prefer']!.split(','),
        unorderedEquals([
          'handling=strict',
          'max-affected=1',
          'return=representation',
        ]),
      );
      expect(books.single.title, 'bar');
    });
  });

  group('errors', () {
    setUp(() {
      httpClient.stub({'message': 'boom', 'code': '42501'}, statusCode: 403);
    });

    test('catchError receives the error of the request', () async {
      Object? caught;
      final List<Book> fallback = await client
          .table(Books.table)
          .select()
          .catchError((Object error) {
            caught = error;
            return const <Book>[];
          });

      expect(fallback, isEmpty);
      expect(caught, isA<PostgrestApiException>());
    });

    test('then receives the error of the request', () async {
      Object? caught;
      await client
          .table(Books.table)
          .select()
          .then<void>(
            (rows) => fail('resolved to $rows'),
            onError: (Object error) {
              caught = error;
            },
          );

      expect(caught, isA<PostgrestApiException>());
    });
  });

  group('mutations', () {
    test('insert posts the values', () async {
      httpClient.stub(null);

      await client.table(Books.table).insert(BookInsert(title: 'foo'));

      expect(httpClient.requests.last.method, 'POST');
      expect(httpClient.requests.last.body, '{"title":"foo"}');
    });

    test('insertAll posts every row and names the columns', () async {
      httpClient.stub(null);

      await client.table(Books.table).insertAll([
        BookInsert(title: 'foo'),
        BookInsert(id: 2, title: 'bar'),
      ], defaultToNull: false);

      expect(httpClient.requests.last.method, 'POST');
      expect(
        httpClient.requests.last.body,
        '[{"title":"foo"},{"title":"bar","id":2}]',
      );
      expect(requestParameters()['columns'], '"title","id"');
      expect(
        httpClient.requests.last.headers['Prefer'],
        contains('missing=default'),
      );
    });

    test('insertAll and upsertAll without rows throw', () {
      expect(
        () => client.table(Books.table).insertAll([]),
        throwsArgumentError,
      );
      expect(
        () => client.table(Books.table).upsertAll([]),
        throwsArgumentError,
      );
    });

    test('insert with a trailing select returns the typed row', () async {
      httpClient.stub({'id': 3, 'title': 'foo'});

      final Book book = await client
          .table(Books.table)
          .insert(BookInsert(title: 'foo'))
          .select()
          .single();

      expect(httpClient.requests.last.method, 'POST');
      expect(
        httpClient.requests.last.headers['Prefer'],
        contains('return=representation'),
      );
      expect(book.id, 3);
    });

    test('a trailing select takes columns', () async {
      httpClient.stub([
        {'id': 3},
      ]);

      final books = await client
          .table(Books.table)
          .insert(BookInsert(title: 'foo'))
          .selectOnly([Books.id]);

      expect(requestParameters()['select'], 'id');
      expect(books.map((book) => book.read(Books.id)), [3]);
    });

    test('insert and upsert return builders without filters', () {
      final inserts = [
        client.table(Books.table).insert(BookInsert(title: 'foo')),
        client.table(Books.table).insertAll([BookInsert(title: 'foo')]),
        client.table(Books.table).upsert(BookInsert(id: 1, title: 'foo')),
        client.table(Books.table).upsertAll([BookInsert(id: 1, title: 'foo')]),
      ];

      for (final insert in inserts) {
        expect(insert, isA<PostgrestTypedTransformBuilder<Book, void>>());
        expect(insert, isNot(isA<PostgrestTypedFilterBuilder<Book, void>>()));
      }
    });

    test('upsert sets the resolution header', () async {
      httpClient.stub(null);

      await client.table(Books.table).upsert(BookInsert(id: 1, title: 'foo'));

      expect(
        httpClient.requests.last.headers['Prefer'],
        contains('resolution=merge-duplicates'),
      );
    });

    test('upsert names its conflict target with columns', () async {
      httpClient.stub(null);

      await client
          .table(Books.table)
          .upsert(
            BookInsert(id: 1, title: 'foo'),
            onConflict: [Books.id, Books.title],
          );

      expect(requestParameters()['on_conflict'], 'id,title');
    });

    test('upsertAll posts every row with the resolution header', () async {
      httpClient.stub(null);

      await client
          .table(Books.table)
          .upsertAll(
            [BookInsert(id: 1, title: 'foo'), BookInsert(id: 2, title: 'bar')],
            onConflict: [Books.id],
            ignoreDuplicates: true,
          );

      expect(
        httpClient.requests.last.body,
        '[{"title":"foo","id":1},{"title":"bar","id":2}]',
      );
      expect(requestParameters()['on_conflict'], 'id');
      expect(
        httpClient.requests.last.headers['Prefer'],
        contains('resolution=ignore-duplicates'),
      );
    });

    test('an empty conflict target throws', () {
      expect(
        () => client
            .table(Books.table)
            .upsert(BookInsert(id: 1, title: 'foo'), onConflict: []),
        throwsArgumentError,
      );
    });

    test('update patches the filtered rows', () async {
      httpClient.stub(null);

      await client
          .table(Books.table)
          .update(BookUpdate(title: 'bar'))
          .where(Books.id.eq(1));

      expect(httpClient.requests.last.method, 'PATCH');
      expect(requestParameters()['id'], 'eq.1');
      expect(httpClient.requests.last.body, '{"title":"bar"}');
    });

    test('delete uses the filtered rows', () async {
      httpClient.stub(null);

      await client.table(Books.table).delete().where(Books.id.eq(1));

      expect(httpClient.requests.last.method, 'DELETE');
      expect(requestParameters()['id'], 'eq.1');
    });
  });

  group('count', () {
    test('count on the table returns the number of rows', () async {
      httpClient.stub(null, headers: {'content-range': '*/42'});

      final int count = await client.table(Books.table).count();

      expect(httpClient.requests.last.method, 'HEAD');
      expect(count, 42);
    });
  });

  group('schema', () {
    const inventoryBooks = PostgrestTable<Book, BookInsert, BookUpdate>(
      'books',
      Book.new,
      primaryKey: [Books.id],
      schema: 'inventory',
    );

    test(
      'a table without a schema is read in the schema of the client',
      () async {
        httpClient.stub(bookRows);
        final scoped = PostgrestClient(
          'http://localhost/rest/v1',
          schema: 'personal',
          httpClient: httpClient,
        );

        await scoped.table(Books.table).select();
        await scoped.dispose();

        expect(httpClient.requests.last.headers['Accept-Profile'], 'personal');
      },
    );

    test('a table carrying a schema is read in that schema', () async {
      httpClient.stubTable('books', rows: bookRows, schema: 'inventory');

      final List<Book> books = await client.table(inventoryBooks).select();

      expect(books, hasLength(2));
      expect(httpClient.requests.last.headers['Accept-Profile'], 'inventory');
    });

    test('a table carrying a schema is written in that schema', () async {
      httpClient.stub(null);

      await client.table(inventoryBooks).insert(BookInsert(title: 'foo'));

      expect(httpClient.requests.last.headers['Content-Profile'], 'inventory');
    });

    test('an explicitly selected schema wins over the table schema', () async {
      httpClient.stub(bookRows);

      await client.schema('tenant_a').table(inventoryBooks).select();

      expect(httpClient.requests.last.headers['Accept-Profile'], 'tenant_a');
    });
  });

  group('request options', () {
    late PostgrestClient retryingClient;

    setUp(() {
      retryingClient = PostgrestClient(
        'http://localhost/rest/v1',
        httpClient: httpClient,
        retryOptions: SupabaseRetryOptions(
          count: 1,
          initialDelay: Duration.zero,
        ),
      );
    });

    tearDown(() async {
      await retryingClient.dispose();
    });

    test('setHeader sends the header from every phase', () async {
      httpClient.stub(bookRows.first);

      await client
          .table(Books.table)
          .setHeader('X-Query', 'query')
          .select()
          .setHeader('X-Filter', 'filter')
          .where(Books.id.eq(1))
          .order(Books.title)
          .setHeader('X-Transform', 'transform')
          .single()
          .setHeader('X-Terminal', 'terminal');

      final headers = httpClient.requests.last.headers;
      expect(headers['X-Query'], 'query');
      expect(headers['X-Filter'], 'filter');
      expect(headers['X-Transform'], 'transform');
      expect(headers['X-Terminal'], 'terminal');
    });

    test('setHeader keeps the filter builder, so where follows it', () async {
      httpClient.stub(bookRows);

      await client
          .table(Books.table)
          .select()
          .setHeader('Authorization', 'Bearer override')
          .where(Books.id.eq(1));

      final request = httpClient.requests.last;
      expect(request.headers['Authorization'], 'Bearer override');
      expect(request.queryParameters['id'], 'eq.1');
    });

    test('setHeader is sent on a count of the table', () async {
      httpClient.stub(null, headers: {'content-range': '*/3'});

      final int count = await client
          .table(Books.table)
          .setHeader('X-Count', 'yes')
          .count();

      expect(count, 3);
      expect(httpClient.requests.last.headers['X-Count'], 'yes');
    });

    test('retry(enabled: false) sends the request once', () async {
      httpClient.stubStatuses([503, 200], body: bookRows);

      await expectLater(
        () => retryingClient.table(Books.table).select().retry(enabled: false),
        throwsA(isA<PostgrestApiException>()),
      );
      expect(httpClient.requests, hasLength(1));
    });

    test('retry(count:) overrides the retry count of the client', () async {
      httpClient.stubStatuses([503, 503, 200], body: bookRows);

      final List<Book> books = await retryingClient
          .table(Books.table)
          .retry(count: 2)
          .select();

      expect(books, hasLength(2));
      expect(httpClient.requests, hasLength(3));
    });

    test('requestTimeout cancels an attempt that takes too long', () async {
      httpClient.stubStall();

      await expectLater(
        () => client
            .table(Books.table)
            .select()
            .retry(enabled: false)
            .requestTimeout(const Duration(milliseconds: 20)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('abortSignal cancels the request in flight', () async {
      httpClient.stubStall();
      final abort = Completer<void>();

      final books = client
          .table(Books.table)
          .abortSignal(abort.future)
          .select()
          .where(Books.id.eq(1));
      abort.complete();

      await expectLater(() => books, throwsA(isA<RequestAbortedException>()));
    });

    test('abortSignal on the filter builder keeps where available', () async {
      httpClient.stubStall();

      await expectLater(
        () => client
            .table(Books.table)
            .select()
            .abortSignal(Future.delayed(Duration.zero))
            .where(Books.id.eq(1)),
        throwsA(isA<RequestAbortedException>()),
      );
    });
  });
}
