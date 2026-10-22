// The typed table access API under test is annotated @experimental.
// ignore_for_file: experimental_member_use

import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  late MockSupabaseHttpClient httpClient;
  late MockRealtimeTransport realtime;
  late SupabaseClient supabase;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    realtime = MockRealtimeTransport();
    supabase = testSupabaseClient(
      httpClient: httpClient,
      realtimeTransport: realtime.call,
    );
  });

  tearDown(() async {
    await supabase.removeAllChannels();
    await supabase.dispose();
  });

  Future<void> waitFor(bool Function() condition) async {
    while (!condition()) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<List<SupabaseStreamEvent>> listenToTodosByPriority({
    required bool ascending,
  }) async {
    final snapshots = <SupabaseStreamEvent>[];
    final subscription = supabase
        .from('todos')
        .stream(primaryKey: ['id'])
        .order('priority', ascending: ascending)
        .listen(snapshots.add);
    addTearDown(subscription.cancel);
    await waitFor(
      () => realtime.joinedTopics.isNotEmpty && snapshots.isNotEmpty,
    );
    return snapshots;
  }

  test('an ascending order keeps null values last', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'priority': 1},
        {'id': 2, 'priority': null},
      ],
    );
    final snapshots = await listenToTodosByPriority(ascending: true);

    realtime.emitPostgresChange(
      table: 'todos',
      event: PostgresChangeEvent.insert,
      newRecord: {'id': 3, 'priority': 0},
    );

    await waitFor(() => snapshots.length == 2);
    expect(snapshots.last, [
      {'id': 3, 'priority': 0},
      {'id': 1, 'priority': 1},
      {'id': 2, 'priority': null},
    ]);
  });

  test('a descending order puts null values first', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'priority': 5},
        {'id': 2, 'priority': 1},
      ],
    );
    final snapshots = await listenToTodosByPriority(ascending: false);

    realtime.emitPostgresChange(
      table: 'todos',
      event: PostgresChangeEvent.insert,
      newRecord: {'id': 3, 'priority': null},
    );

    await waitFor(() => snapshots.length == 2);
    expect(snapshots.last, [
      {'id': 3, 'priority': null},
      {'id': 1, 'priority': 5},
      {'id': 2, 'priority': 1},
    ]);
  });

  test('booleans sort false before true', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'priority': true},
      ],
    );
    final snapshots = await listenToTodosByPriority(ascending: true);

    realtime.emitPostgresChange(
      table: 'todos',
      event: PostgresChangeEvent.insert,
      newRecord: {'id': 2, 'priority': false},
    );

    await waitFor(() => snapshots.length == 2);
    expect(snapshots.last, [
      {'id': 2, 'priority': false},
      {'id': 1, 'priority': true},
    ]);
  });

  test('null values do not unsort the rows around them', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        for (var id = 1; id <= 100; id++) {'id': id, 'priority': id},
        {'id': 101, 'priority': null},
        {'id': 102, 'priority': null},
        {'id': 103, 'priority': null},
      ],
    );
    final snapshots = await listenToTodosByPriority(ascending: true);

    realtime.emitPostgresChange(
      table: 'todos',
      event: PostgresChangeEvent.insert,
      newRecord: {'id': 104, 'priority': 0},
    );

    await waitFor(() => snapshots.length == 2);
    expect(snapshots.last.map((row) => row['priority']), [
      for (var priority = 0; priority <= 100; priority++) priority,
      null,
      null,
      null,
    ]);
  });

  group('typed order', () {
    Future<List<List<_Todo>>> listenToTypedTodos(
      PostgrestColumnOrdering<_Todo> ordering,
    ) async {
      final snapshots = <List<_Todo>>[];
      final subscription = supabase
          .table(_Todos.table)
          .stream(primaryKey: [_Todos.id])
          .order(ordering)
          .listen(snapshots.add);
      addTearDown(subscription.cancel);
      await waitFor(
        () => realtime.joinedTopics.isNotEmpty && snapshots.isNotEmpty,
      );
      return snapshots;
    }

    test('takes the direction from the ordering', () async {
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1, 'priority': 5},
          {'id': 2, 'priority': 1},
        ],
      );
      final snapshots = await listenToTypedTodos(_Todos.priority.desc());

      realtime.emitPostgresChange(
        table: 'todos',
        event: PostgresChangeEvent.insert,
        newRecord: {'id': 3, 'priority': 3},
      );

      await waitFor(() => snapshots.length == 2);
      expect(snapshots.last.map((todo) => todo.id), [1, 3, 2]);
      expect(
        httpClient.requestsTo('/rest/v1/todos').single.url.queryParameters,
        containsPair('order', 'priority.desc'),
      );
    });

    test('a bare column sorts ascending', () async {
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1, 'priority': 1},
          {'id': 2, 'priority': 5},
        ],
      );
      final snapshots = await listenToTypedTodos(_Todos.priority);

      realtime.emitPostgresChange(
        table: 'todos',
        event: PostgresChangeEvent.insert,
        newRecord: {'id': 3, 'priority': 3},
      );

      await waitFor(() => snapshots.length == 2);
      expect(snapshots.last.map((todo) => todo.id), [1, 3, 2]);
      expect(
        httpClient.requestsTo('/rest/v1/todos').single.url.queryParameters,
        containsPair('order', 'priority.asc'),
      );
    });

    test('a null placement or a computed field is no column ordering', () {
      expect(
        _Todos.priority.desc().nullsLast(),
        isNot(isA<PostgrestColumnOrdering<_Todo>>()),
      );
      expect(
        _Todos.priority.nullsFirst(),
        isNot(isA<PostgrestColumnOrdering<_Todo>>()),
      );
      expect(
        _Todos.label.desc(),
        isNot(isA<PostgrestColumnOrdering<_Todo>>()),
      );
    });
  });
}

extension type const _Todo(Map<String, dynamic> _json) implements Object {
  int get id => _json['id'] as int;
}

class _Todos {
  static const table = PostgrestTable<_Todo, Never, Never>(
    'todos',
    _Todo.new,
    primaryKey: [id],
  );
  static const id = PostgrestColumn<_Todo, int>('id');
  static const priority = PostgrestNullableColumn<_Todo, int>('priority');
  static const label = PostgrestComputedField<_Todo, String>('label');
}
