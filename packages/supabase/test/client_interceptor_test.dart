// The typed table access API and the interceptor seam are @experimental.
// ignore_for_file: experimental_member_use

import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

import 'utils.dart';

extension type const Todo(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  int get id => _json['id'] as int;
  String get task => _json['task'] as String;
}

extension type const TodoInsert._(Map<String, dynamic> _json)
    implements Object {
  TodoInsert({required String task}) : this._({'task': task});
}

extension type const TodoUpdate._(Map<String, dynamic> _json)
    implements Object {
  TodoUpdate({String? task}) : this._({'task': ?task});
}

class Todos {
  static const table = PostgrestTable<Todo, TodoInsert, TodoUpdate>(
    'todos',
    Todo.new,
    primaryKey: [id],
  );
  static const id = PostgrestColumn<Todo, int>('id');
  static const task = PostgrestColumn<Todo, String>('task');
}

const todoRows = [
  {'id': 1, 'task': 'Ship it'},
];

class LoggingExecutor implements PostgrestTableExecutor {
  const LoggingExecutor(this.name, this.inner, this.log);

  final String name;
  final PostgrestTableExecutor inner;
  final List<String> log;

  @override
  Future<PostgrestTableResult> execute(PostgrestTableRequest request) {
    log.add('$name ${request.operation.name} ${request.table.name}');
    return inner.execute(request);
  }
}

class LoggingInterceptor extends SupabaseClientInterceptor {
  LoggingInterceptor(this.name, this.log);

  final String name;
  final List<String> log;
  SupabaseClient? attachedClient;
  int disposals = 0;

  @override
  PostgrestTableExecutor wrapTableExecutor(PostgrestTableExecutor inner) =>
      LoggingExecutor(name, inner, log);

  @override
  void attach(SupabaseClient client) {
    attachedClient = client;
    log.add('$name attached');
  }

  @override
  Future<void> dispose() async {
    disposals++;
    log.add('$name disposed');
  }
}

class FailingAttachInterceptor extends SupabaseClientInterceptor {
  const FailingAttachInterceptor();

  @override
  void attach(SupabaseClient client) => throw StateError('no attach');
}

void main() {
  late MockSupabaseHttpClient httpClient;
  late List<String> log;
  late LoggingInterceptor interceptor;
  late SupabaseClient supabase;

  setUp(() {
    httpClient = MockSupabaseHttpClient()..stubTable('todos', rows: todoRows);
    log = [];
    interceptor = LoggingInterceptor('a', log);
    supabase = testSupabaseClient(
      httpClient: httpClient,
      interceptors: [interceptor],
    );
  });

  tearDown(() async {
    await supabase.dispose();
  });

  test('table() runs through the interceptor, from() does not', () async {
    final List<Todo> typed = await supabase.table(Todos.table).select();
    await supabase.from('todos').select();

    expect(typed.single.task, 'Ship it');
    expect(log, ['a attached', 'a select todos']);
    expect(httpClient.requestsTo('/rest/v1/todos'), hasLength(2));
  });

  test('rpc, storage and functions bypass the interceptor', () async {
    httpClient
      ..stubRpc('ping', body: 'pong')
      ..stubStorageList('avatars', objects: [])
      ..stubEdgeFunction('hello', body: {'ok': true});

    await supabase.rpc<String>('ping');
    await supabase.storage.from('avatars').list();
    await supabase.functions.invoke('hello');

    expect(log, ['a attached']);
  });

  test(
    'the wire carries the session while the request value does not',
    () async {
      final session = await signInTestUser(supabase.auth);

      await supabase.table(Todos.table).select();

      final sent = httpClient.requestsTo('/rest/v1/todos').single;
      expect(sent.headers['Authorization'], 'Bearer ${session.accessToken}');
      expect(sent.headers['apikey'], isNotNull);
    },
  );

  test('attach receives the constructed client', () {
    expect(interceptor.attachedClient, same(supabase));
    expect(interceptor.attachedClient!.rest.url, endsWith('/rest/v1'));
  });

  test('interceptors wrap in order and dispose in reverse', () async {
    await supabase.dispose();
    log.clear();
    final first = LoggingInterceptor('first', log);
    final second = LoggingInterceptor('second', log);
    supabase = testSupabaseClient(
      httpClient: httpClient,
      interceptors: [first, second],
    );

    await supabase.table(Todos.table).select();
    await supabase.dispose();

    expect(log, [
      'first attached',
      'second attached',
      'second select todos',
      'first select todos',
      'second disposed',
      'first disposed',
    ]);
    expect(supabase.interceptors, [first, second]);
  });

  test('a header change keeps the interceptor chain in place', () async {
    supabase.headers = {'x-tenant': 'acme'};

    await supabase.table(Todos.table).select();

    expect(log, ['a attached', 'a select todos']);
    final sent = httpClient.requestsTo('/rest/v1/todos').single;
    expect(sent.headers['x-tenant'], 'acme');
  });

  test('a schema scoped table request carries its schema', () async {
    await supabase.schema('library').table(Todos.table).select();

    final sent = httpClient.requestsTo('/rest/v1/todos').single;
    expect(sent.headers['Accept-Profile'], 'library');
    expect(log, ['a attached', 'a select todos']);
  });

  test('an interceptor that fails to attach fails the constructor', () {
    expect(
      () => testSupabaseClient(
        httpClient: httpClient,
        interceptors: const [FailingAttachInterceptor()],
      ),
      throwsStateError,
    );
  });

  test('a failed attach disposes the interceptors already attached', () async {
    final first = LoggingInterceptor('first', log);
    final second = LoggingInterceptor('second', log);

    expect(
      () => testSupabaseClient(
        httpClient: httpClient,
        interceptors: [first, second, const FailingAttachInterceptor()],
      ),
      throwsStateError,
    );
    await pumpEventQueue();

    expect(log, [
      'a attached',
      'first attached',
      'second attached',
      'second disposed',
      'first disposed',
    ]);
  });

  test('dispose runs each interceptor once', () async {
    await supabase.dispose();

    expect(interceptor.disposals, 1);
  });
}
