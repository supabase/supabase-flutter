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

  const jwtExpired = {'code': 'PGRST301', 'message': 'JWT expired'};

  Future<void> waitFor(bool Function() condition) async {
    while (!condition()) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  int fetchCount() =>
      httpClient.requestsTo('/rest/v1/todos', method: HttpMethod.get).length;

  ({
    List<SupabaseStreamEvent> snapshots,
    List<Object> errors,
    bool Function() isDone,
  })
  listenToTodos() {
    final snapshots = <SupabaseStreamEvent>[];
    final errors = <Object>[];
    var done = false;
    final subscription = supabase
        .from('todos')
        .stream(primaryKey: ['id'])
        .order('id')
        .listen(
          snapshots.add,
          onError: (Object error) => errors.add(error),
          onDone: () => done = true,
        );
    addTearDown(subscription.cancel);
    return (snapshots: snapshots, errors: errors, isDone: () => done);
  }

  test('fetches the rows once the channel has joined', () async {
    var joinedWhenFetched = false;
    httpClient.stubHandler((request) {
      joinedWhenFetched = realtime.joinedTopics.isNotEmpty;
      return jsonResponse([
        {'id': 1, 'task': 'Ship it'},
      ]);
    }, path: '/rest/v1/todos');

    final stream = listenToTodos();
    await waitFor(() => stream.snapshots.isNotEmpty);

    expect(joinedWhenFetched, isTrue);
    expect(stream.snapshots.single, [
      {'id': 1, 'task': 'Ship it'},
    ]);
  });

  test('applies the changes that arrive during a fetch on top of it', () async {
    httpClient.stubHandler((request) async {
      realtime
        ..emitPostgresChange(
          table: 'todos',
          event: PostgresChangeEvent.update,
          newRecord: {'id': 1, 'task': 'Ship it today'},
          oldRecord: {'id': 1},
        )
        ..emitPostgresChange(
          table: 'todos',
          event: PostgresChangeEvent.insert,
          newRecord: {'id': 2, 'task': 'Test it'},
        );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return jsonResponse([
        {'id': 1, 'task': 'Ship it'},
      ]);
    }, path: '/rest/v1/todos');

    final stream = listenToTodos();
    await waitFor(() => stream.snapshots.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(stream.snapshots, [
      [
        {'id': 1, 'task': 'Ship it today'},
        {'id': 2, 'task': 'Test it'},
      ],
    ]);
  });

  test('retries a failed fetch and keeps the stream open', () async {
    httpClient
      ..stubTable(
        'todos',
        rows: [
          {'id': 1, 'task': 'Ship it'},
        ],
      )
      ..stubTable(
        'todos',
        rows: jwtExpired,
        statusCode: 401,
        times: 2,
      );

    final stream = listenToTodos();
    await waitFor(() => stream.snapshots.isNotEmpty);

    expect(fetchCount(), 3);
    expect(stream.errors, [isA<PostgrestException>()]);
    expect(stream.isDone(), isFalse);
    expect(stream.snapshots.single, [
      {'id': 1, 'task': 'Ship it'},
    ]);

    realtime.emitPostgresChange(
      table: 'todos',
      event: PostgresChangeEvent.insert,
      newRecord: {'id': 2, 'task': 'Test it'},
    );
    await waitFor(() => stream.snapshots.length == 2);
    expect(stream.snapshots.last, [
      {'id': 1, 'task': 'Ship it'},
      {'id': 2, 'task': 'Test it'},
    ]);
  });

  test('a client error that a retry cannot fix closes the stream', () async {
    httpClient.stubTable(
      'todos',
      rows: {'code': 'PGRST205', 'message': 'Could not find the table'},
      statusCode: 404,
    );

    final stream = listenToTodos();
    await waitFor(stream.isDone);

    expect(fetchCount(), 1);
    expect(stream.errors, [isA<PostgrestException>()]);
    expect(stream.snapshots, isEmpty);
    expect(realtime.joinedTopics, isEmpty);
  });

  test(
    'changes are applied while a failed fetch waits for its retry',
    () async {
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1, 'task': 'Ship it'},
        ],
      );
      final stream = listenToTodos();
      await waitFor(() => stream.snapshots.isNotEmpty);

      httpClient.stubTable(
        'todos',
        rows: jwtExpired,
        statusCode: 401,
        times: 1,
      );
      await realtime.closeConnection(code: 1006);
      await waitFor(() => stream.errors.isNotEmpty);

      realtime.emitPostgresChange(
        table: 'todos',
        event: PostgresChangeEvent.insert,
        newRecord: {'id': 2, 'task': 'Test it'},
      );
      await waitFor(() => stream.snapshots.length == 2);

      expect(fetchCount(), 2);
      expect(stream.snapshots.last, [
        {'id': 1, 'task': 'Ship it'},
        {'id': 2, 'task': 'Test it'},
      ]);
    },
  );

  test(
    'a burst of changes without their full records fetches once more',
    () async {
      httpClient.stubHandler((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return jsonResponse([
          {'id': 1, 'task': 'Ship it'},
        ]);
      }, path: '/rest/v1/todos');
      final stream = listenToTodos();
      await waitFor(() => stream.snapshots.isNotEmpty);

      for (var i = 0; i < 3; i++) {
        realtime.emitPostgresChange(
          table: 'todos',
          event: PostgresChangeEvent.update,
          newRecord: {'id': 1},
          oldRecord: {'id': 1},
          errors: ['Error 413: Payload Too Large'],
        );
      }
      await waitFor(() => stream.snapshots.length == 3);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(fetchCount(), 3);
    },
  );

  test('a dropped connection is not reported and refetches the rows', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'task': 'Ship it'},
      ],
    );
    final stream = listenToTodos();
    await waitFor(() => stream.snapshots.isNotEmpty);

    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'task': 'Ship it'},
        {'id': 2, 'task': 'Missed while offline'},
      ],
    );
    await realtime.closeConnection(code: 1006);
    await waitFor(() => stream.snapshots.length == 2);

    expect(fetchCount(), 2);
    expect(stream.errors, isEmpty);
    expect(stream.isDone(), isFalse);
    expect(stream.snapshots.last, [
      {'id': 1, 'task': 'Ship it'},
      {'id': 2, 'task': 'Missed while offline'},
    ]);
  });

  test('a failed fetch after a reconnect is retried', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'task': 'Ship it'},
      ],
    );
    final stream = listenToTodos();
    await waitFor(() => stream.snapshots.isNotEmpty);

    httpClient
      ..stubTable(
        'todos',
        rows: [
          {'id': 2, 'task': 'Test it'},
        ],
      )
      ..stubTable(
        'todos',
        rows: jwtExpired,
        statusCode: 401,
        times: 1,
      );
    await realtime.closeConnection(code: 1006);
    await waitFor(() => stream.snapshots.length == 2);

    expect(fetchCount(), 3);
    expect(stream.errors, [isA<PostgrestException>()]);
    expect(stream.isDone(), isFalse);
    expect(stream.snapshots.last, [
      {'id': 2, 'task': 'Test it'},
    ]);
  });

  test('a change without its full record refetches the rows', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'task': 'Ship it'},
      ],
    );
    final stream = listenToTodos();
    await waitFor(() => stream.snapshots.isNotEmpty);

    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'task': 'A very long task'},
      ],
    );
    realtime.emitPostgresChange(
      table: 'todos',
      event: PostgresChangeEvent.update,
      newRecord: {'id': 1},
      oldRecord: {'id': 1},
      errors: ['Error 413: Payload Too Large'],
    );
    await waitFor(() => stream.snapshots.length == 2);

    expect(fetchCount(), 2);
    expect(stream.snapshots.last, [
      {'id': 1, 'task': 'A very long task'},
    ]);
  });

  test('listening again fetches the rows once', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'id': 1, 'task': 'Ship it'},
      ],
    );
    final stream = supabase.from('todos').stream(primaryKey: ['id']);

    final first = <SupabaseStreamEvent>[];
    final firstSubscription = stream.listen(first.add);
    await waitFor(() => first.isNotEmpty);
    await firstSubscription.cancel();
    await waitFor(() => realtime.joinedTopics.isEmpty);

    final second = <SupabaseStreamEvent>[];
    final secondSubscription = stream.listen(second.add);
    addTearDown(secondSubscription.cancel);
    await waitFor(() => second.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(fetchCount(), 2);
    expect(second, [
      [
        {'id': 1, 'task': 'Ship it'},
      ],
    ]);
  });

  test('a subscription the server declines is reported', () async {
    httpClient.stubTable('todos', rows: []);
    final stream = listenToTodos();
    await waitFor(() => stream.snapshots.isNotEmpty);

    realtime.emit(
      RealtimeMessage(
        topic: realtime.joinedTopics.single,
        event: 'system',
        payload: {'status': 'error', 'message': 'Unauthorized'},
      ),
    );
    await waitFor(() => stream.errors.isNotEmpty);

    expect(stream.errors.single, isA<RealtimeSubscribeException>());
    expect(stream.isDone(), isFalse);
  });
}
