// The typed table access API under test is annotated @experimental.
// ignore_for_file: experimental_member_use

import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

extension type const Todo(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  int get id => _json['id'] as int;
  String get task => _json['task'] as String;
  bool get status => _json['status'] as bool;
}

class Todos {
  static const table = PostgrestTable('todos', Todo.new);
  static const id = TableColumn<int>('id');
  static const task = TableColumn<String>('task');
  static const status = TableColumn<bool>('status');
}

void main() {
  late MockSupabaseHttpClient httpClient;
  late MockRealtimeTransport realtime;
  late SupabaseClient supabase;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    realtime = MockRealtimeTransport();
    supabase = testSupabaseClient(httpClient: httpClient, realtime: realtime);
    addTearDown(supabase.dispose);
  });

  test('a typed select decodes the stubbed rows', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'task': 'Ship it', 'status': false},
      ],
    );

    final List<Todo> todos = await supabase
        .table(Todos.table)
        .select()
        .where(Todos.status.eq(false));

    expect(todos.single.task, 'Ship it');
    expect(httpClient.requests.single.queryParameters['status'], 'eq.false');
  });

  test('typed filters match query stubs', () async {
    httpClient.stubTable(
      'todos',
      query: {'id': 'eq.1'},
      rows: [
        {'id': 1, 'task': 'First', 'status': false},
      ],
    );
    httpClient.stubTable(
      'todos',
      query: {'id': 'eq.2'},
      rows: [
        {'id': 2, 'task': 'Second', 'status': true},
      ],
    );

    final first = await supabase
        .table(Todos.table)
        .select()
        .where(Todos.id.eq(1))
        .single();
    final second = await supabase
        .table(Todos.table)
        .select()
        .where(Todos.id.eq(2))
        .single();

    expect(first.task, 'First');
    expect(second.task, 'Second');
  });

  test('single and maybeSingle are shaped for typed rows', () async {
    httpClient.stubTable('todos', rows: []);

    final Todo? none = await supabase.table(Todos.table).select().maybeSingle();

    expect(none == null, isTrue);
    await expectLater(
      () => supabase.table(Todos.table).select().single(),
      throwsA(
        isA<PostgrestApiException>().having(
          (exception) => exception.errorCode,
          'errorCode',
          'PGRST116',
        ),
      ),
    );
  });

  test('a typed count reads the content-range header', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'task': 'Ship it', 'status': false},
      ],
      count: 3,
    );

    final total = await supabase.table(Todos.table).count();
    final page = await supabase
        .table(Todos.table)
        .select()
        .limit(1)
        .count(CountOption.exact);

    expect(total, 3);
    expect(page.data.single.id, 1);
    expect(page.count, 3);
  });

  test('a typed insert sends the row and returns it through select', () async {
    httpClient.stubTable(
      'todos',
      method: 'POST',
      statusCode: 201,
      rows: [
        {'id': 7, 'task': 'Write tests', 'status': false},
      ],
    );

    final Todo inserted = await supabase
        .table(Todos.table)
        .insert({'task': 'Write tests', 'status': false})
        .select()
        .single();

    expect(inserted.id, 7);
    expect(httpClient.requests.single.jsonBody, {
      'task': 'Write tests',
      'status': false,
    });
  });

  test('a typed stream emits typed rows for emitted changes', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'task': 'Ship it', 'status': false},
      ],
    );
    final snapshots = <List<Todo>>[];
    final subscription = supabase
        .table(Todos.table)
        .stream(primaryKey: [Todos.id])
        .listen(snapshots.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    realtime.emitPostgresChange(
      table: 'todos',
      event: PostgresChangeEvent.update,
      newRecord: {'id': 1, 'task': 'Shipped', 'status': true},
      oldRecord: {'id': 1},
    );
    await pumpEventQueue();

    expect(snapshots.map((rows) => rows.single.task), ['Ship it', 'Shipped']);
    expect(snapshots.last.single.status, isTrue);
  });
}
