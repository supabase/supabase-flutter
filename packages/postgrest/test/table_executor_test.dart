// The typed table access API under test is annotated @experimental.
// ignore_for_file: experimental_member_use

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
  BookInsert({required String title}) : this._({'title': title});
}

extension type const BookUpdate._(Map<String, dynamic> _json)
    implements Object {
  BookUpdate({String? title}) : this._({'title': ?title});
}

class Books {
  static const table = PostgrestTable<Book, BookInsert, BookUpdate>(
    'books',
    Book.new,
    primaryKey: [id],
  );
  static const id = PostgrestColumn<Book, int>('id');
  static const title = PostgrestColumn<Book, String>('title');
}

const bookRows = [
  {'id': 1, 'title': 'a'},
  {'id': 2, 'title': 'b'},
];

/// Answers every request with [result] and keeps what it was asked.
class RecordingExecutor implements PostgrestTableExecutor {
  RecordingExecutor([this.result = const PostgrestTableResult()]);

  final PostgrestTableResult result;
  final requests = <PostgrestTableRequest>[];

  PostgrestTableRequest get onlyRequest => requests.single;

  @override
  Future<PostgrestTableResult> execute(PostgrestTableRequest request) async {
    requests.add(request);
    return result;
  }
}

class _FailingExecutor implements PostgrestTableExecutor {
  const _FailingExecutor();

  @override
  Future<PostgrestTableResult> execute(PostgrestTableRequest request) async =>
      throw StateError('offline');
}

void main() {
  late MockSupabaseHttpClient httpClient;
  late PostgrestClient client;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stub(bookRows);
    client = PostgrestClient(
      'http://localhost/rest/v1',
      httpClient: httpClient,
    );
  });

  tearDown(() async {
    await client.dispose();
  });

  group('request value', () {
    test(
      'select collects the table, columns, filters, order and page',
      () async {
        final executor = RecordingExecutor(
          const PostgrestTableResult(data: bookRows),
        );

        final List<Book> books = await client
            .table(Books.table, executor: executor)
            .select([Books.id, Books.title])
            .where(Books.id.gt(1))
            .where(Books.title.eq('a'))
            .order(Books.title.desc())
            .range(10, 19);

        final request = executor.onlyRequest;
        expect(request.table.name, 'books');
        expect(request.schema, isNull);
        expect(request.operation, PostgrestTableOperation.select);
        expect(request.shape, PostgrestResultShape.rows);
        expect(request.columns.map((column) => column.expression), [
          'id',
          'title',
        ]);
        // ignore: invalid_use_of_internal_member
        expect(request.filter!.queryParameters, [
          (key: 'id', value: 'gt.1'),
          (key: 'title', value: 'eq.a'),
        ]);
        expect(request.orderings.single.orderKey, 'title.desc');
        expect(request.offset, 10);
        expect(request.limit, 10);
        expect(books.map((book) => book.title), ['a', 'b']);
      },
    );

    test('carries the schema of the client', () async {
      final executor = RecordingExecutor(
        const PostgrestTableResult(data: <Map<String, dynamic>>[]),
      );

      await client
          .schema('library')
          .table(Books.table, executor: executor)
          .select();

      expect(executor.onlyRequest.schema, 'library');
    });

    test('an embedded limit is kept apart from the table page', () async {
      final executor = RecordingExecutor(
        const PostgrestTableResult(data: <Map<String, dynamic>>[]),
      );

      await client
          .table(Books.table, executor: executor)
          .select()
          .limit(5)
          .limit(2, referencedTable: 'authors');

      final request = executor.onlyRequest;
      expect(request.limit, 5);
      expect(request.embeddedPages.single.referencedTable, 'authors');
      expect(request.embeddedPages.single.limit, 2);
    });

    test('single converts the one returned row', () async {
      final executor = RecordingExecutor(
        const PostgrestTableResult(data: {'id': 1, 'title': 'a'}),
      );

      final Book book = await client
          .table(Books.table, executor: executor)
          .select()
          .single();

      expect(executor.onlyRequest.shape, PostgrestResultShape.single);
      expect(book.title, 'a');
    });

    test('maybeSingle converts a missing row into null', () async {
      final executor = RecordingExecutor();

      final Book? book = await client
          .table(Books.table, executor: executor)
          .select()
          .maybeSingle();

      expect(executor.onlyRequest.shape, PostgrestResultShape.maybeSingle);
      expect(book == null, isTrue);
    });

    test('a mutation carries its payload and asks nothing back', () async {
      final executor = RecordingExecutor();

      await client
          .table(Books.table, executor: executor)
          .update(BookUpdate(title: 'b'))
          .where(Books.id.eq(1));

      final request = executor.onlyRequest;
      expect(request.operation, PostgrestTableOperation.update);
      expect(request.payload, {'title': 'b'});
      expect(request.shape, PostgrestResultShape.none);
      expect(request.returning, isFalse);
      expect(request.filter!.comparison!.operator, PostgrestFilterOperator.eq);
    });

    test('a trailing select on a mutation asks the rows back', () async {
      final executor = RecordingExecutor(
        const PostgrestTableResult(data: bookRows),
      );

      final List<Book> books = await client
          .table(Books.table, executor: executor)
          .insertAll([BookInsert(title: 'a'), BookInsert(title: 'b')])
          .select([Books.id]);

      final request = executor.onlyRequest;
      expect(request.operation, PostgrestTableOperation.insert);
      expect(request.payload, [
        {'title': 'a'},
        {'title': 'b'},
      ]);
      expect(request.shape, PostgrestResultShape.rows);
      expect(request.returning, isTrue);
      expect(request.columns.single.expression, 'id');
      expect(books.length, 2);
    });

    test('upsert carries the conflict target and flags', () async {
      final executor = RecordingExecutor();

      await client
          .table(Books.table, executor: executor)
          .upsert(
            BookInsert(title: 'a'),
            onConflict: [Books.title],
            ignoreDuplicates: true,
            defaultToNull: false,
          );

      final request = executor.onlyRequest;
      expect(request.operation, PostgrestTableOperation.upsert);
      expect(request.onConflict!.single.name, 'title');
      expect(request.ignoreDuplicates, isTrue);
      expect(request.defaultToNull, isFalse);
    });

    test('count reads the count of the result', () async {
      final executor = RecordingExecutor(
        const PostgrestTableResult(count: 7),
      );

      final int count = await client
          .table(Books.table, executor: executor)
          .count(CountOption.estimated);

      expect(executor.onlyRequest.operation, PostgrestTableOperation.count);
      expect(executor.onlyRequest.countOption, CountOption.estimated);
      expect(count, 7);
    });

    test('a counted select wraps rows and count', () async {
      final executor = RecordingExecutor(
        const PostgrestTableResult(data: bookRows, count: 12),
      );

      final response = await client
          .table(Books.table, executor: executor)
          .select()
          .count();

      expect(executor.onlyRequest.countOption, CountOption.exact);
      expect(response.count, 12);
      expect(response.data.map((book) => book.id), [1, 2]);
    });

    test('csv, head and explain set their shapes', () async {
      final executor = RecordingExecutor(
        const PostgrestTableResult(data: 'id,title'),
      );
      final builder = client.table(Books.table, executor: executor).select();

      await builder.csv();
      await builder.head();
      await builder.explain(analyze: true);

      expect(executor.requests.map((request) => request.shape), [
        PostgrestResultShape.csv,
        PostgrestResultShape.head,
        PostgrestResultShape.explain,
      ]);
      expect(executor.requests.last.explainOptions!.analyze, isTrue);
    });

    test('an empty column list is rejected when select is called', () {
      expect(
        () =>
            client.table(Books.table, executor: RecordingExecutor()).select([]),
        throwsArgumentError,
      );
    });

    test('asStream forwards an executor failure', () async {
      final stream = client
          .table(Books.table, executor: const _FailingExecutor())
          .select()
          .asStream();

      await expectLater(stream, emitsError(isA<StateError>()));
    });

    test('a builder is a value: reuse does not leak steps', () async {
      final executor = RecordingExecutor(
        const PostgrestTableResult(data: <Map<String, dynamic>>[]),
      );
      final base = client.table(Books.table, executor: executor).select();

      await base.where(Books.id.eq(1));
      await base.order(Books.title.asc());

      expect(executor.requests[0].filter, isNotNull);
      expect(executor.requests[0].orderings, isEmpty);
      expect(executor.requests[1].filter, isNull);
      expect(executor.requests[1].orderings, hasLength(1));
    });
  });

  group('PostgrestHttpTableExecutor', () {
    test('sends what the untyped builder sends for the same query', () async {
      await client
          .table(Books.table)
          .select([Books.id, Books.title])
          .where(Books.id.gt(1) | Books.title.eq('a'))
          .order(Books.title.desc().nullsLast())
          .range(10, 19);
      await client
          .from('books')
          .select('id,title')
          .or('id.gt.1,title.eq.a')
          .order('title', ascending: false, nullsFirst: false)
          .range(10, 19);

      final typed = httpClient.requests[0];
      final untyped = httpClient.requests[1];
      expect(typed.url.queryParameters, untyped.url.queryParameters);
      expect(typed.method, untyped.method);
    });

    test('renders a returning select on a mutation', () async {
      httpClient
        ..reset()
        ..stub([
          {'id': 3, 'title': 'c'},
        ]);

      final List<Book> books = await client
          .table(Books.table)
          .insert(BookInsert(title: 'c'))
          .select([Books.id]);

      final request = httpClient.requests.single;
      expect(request.method, 'POST');
      expect(request.headers['Prefer'], contains('return=representation'));
      expect(request.queryParameters['select'], 'id');
      expect(books.single.id, 3);
    });

    test('scopes the request to the schema of the request', () async {
      await client.schema('library').table(Books.table).select();

      expect(httpClient.requests.single.headers['Accept-Profile'], 'library');
    });

    test('renders a count only request as HEAD', () async {
      httpClient
        ..reset()
        ..stub(null, headers: {'content-range': '0-1/2'});

      final int count = await client.table(Books.table).count();

      final request = httpClient.requests.single;
      expect(request.method, 'HEAD');
      expect(request.headers['Prefer'], contains('count=exact'));
      expect(count, 2);
    });
  });
}
