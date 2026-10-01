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

  /// Streams the todos table, and waits for the channel to join and the
  /// fetched rows to arrive.
  Future<List<SupabaseStreamEvent>> listenToTodos() async {
    final snapshots = <SupabaseStreamEvent>[];
    final subscription = supabase
        .from('todos')
        .stream(primaryKey: ['id'])
        .order('id', ascending: true)
        .listen(snapshots.add);
    addTearDown(subscription.cancel);
    await waitFor(
      () => realtime.joinedTopics.isNotEmpty && snapshots.isNotEmpty,
    );
    return snapshots;
  }

  test('an insert of a row that was already fetched replaces it', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'task': 'Ship it'},
      ],
    );
    final snapshots = await listenToTodos();

    realtime.emitPostgresChange(
      table: 'todos',
      event: PostgresChangeEvent.insert,
      newRecord: {'id': 1, 'task': 'Ship it'},
    );

    await waitFor(() => snapshots.length == 2);
    expect(snapshots.last, [
      {'id': 1, 'task': 'Ship it'},
    ]);
  });

  test('an insert of a new row is added', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'task': 'Ship it'},
      ],
    );
    final snapshots = await listenToTodos();

    realtime.emitPostgresChange(
      table: 'todos',
      event: PostgresChangeEvent.insert,
      newRecord: {'id': 2, 'task': 'Test it'},
    );

    await waitFor(() => snapshots.length == 2);
    expect(snapshots.last, [
      {'id': 1, 'task': 'Ship it'},
      {'id': 2, 'task': 'Test it'},
    ]);
  });
}
