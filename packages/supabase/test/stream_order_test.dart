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
    supabase = testSupabaseClient(httpClient: httpClient, realtime: realtime);
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
}
