// The typed table access API under test is annotated @experimental.
// ignore_for_file: experimental_member_use

import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

extension type const Todo(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  int get id => _json['id'] as int;
  String get title => _json['title'] as String;
  bool get done => _json['done'] as bool;
}

class Todos {
  static const table = PostgrestTable<Todo, Never, Never>(
    'todos',
    Todo.new,
    primaryKey: [id],
  );
  static const id = PostgrestColumn<Todo, int>('id');
  static const title = PostgrestColumn<Todo, String>('title');
  static const done = PostgrestColumn<Todo, bool>('done');
}

/// Asserts that the rows of a typed `streamOnly` are read through the
/// selected columns, from the first snapshot through every change.
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

  /// Streams the titles of the todos table, and waits for the channel to join
  /// and the fetched rows to arrive.
  Future<List<List<PostgrestPartialRow<Todo>>>> listenToTitles() async {
    final snapshots = <List<PostgrestPartialRow<Todo>>>[];
    final subscription = supabase
        .table(Todos.table)
        .streamOnly(primaryKey: [Todos.id], columns: [Todos.title])
        .order(Todos.id)
        .listen(snapshots.add);
    addTearDown(subscription.cancel);
    await waitFor(
      () => realtime.joinedTopics.isNotEmpty && snapshots.isNotEmpty,
    );
    return snapshots;
  }

  List<String> titles(List<PostgrestPartialRow<Todo>> rows) => [
    for (final row in rows) row.read(Todos.title),
  ];

  test('the fetched rows are read through the selected columns', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'title': 'first'},
      ],
    );

    final snapshots = await listenToTitles();

    final row = snapshots.single.single;
    expect(row.read(Todos.id), 1);
    expect(row.read(Todos.title), 'first');
    expect(() => row.read(Todos.done), throwsStateError);
  });

  test('a change payload is read through the selected columns', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'title': 'first'},
      ],
    );
    final snapshots = await listenToTitles();

    realtime.emitPostgresChange(
      table: 'todos',
      event: PostgresChangeEvent.insert,
      newRecord: {'id': 2, 'title': 'second'},
    );
    await waitFor(() => snapshots.length == 2);
    realtime.emitPostgresChange(
      table: 'todos',
      event: PostgresChangeEvent.update,
      newRecord: {'id': 1, 'title': 'renamed'},
      oldRecord: {'id': 1},
    );
    await waitFor(() => snapshots.length == 3);

    expect(titles(snapshots[1]), ['first', 'second']);
    expect(titles(snapshots[2]), ['renamed', 'second']);
    expect(() => snapshots.last.first.read(Todos.done), throwsStateError);
  });
}
