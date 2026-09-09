// This example is a test file; the helpers are meant for test code, so the
// analyzer warning about using them outside of a test directory is expected.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

/// The code under test: a repository that reads and writes todos.
class TodoRepository {
  const TodoRepository(this.supabase);

  final SupabaseClient supabase;

  Future<List<String>> openTasks() async {
    final rows = await supabase
        .from('todos')
        .select('task')
        .eq('status', false);
    return rows.map((row) => row['task'] as String).toList();
  }

  Future<void> add(String task) {
    return supabase.from('todos').insert({'task': task, 'status': false});
  }
}

void main() {
  late MockSupabaseHttpClient httpClient;
  late SupabaseClient supabase;
  late TodoRepository repository;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    supabase = testSupabaseClient(httpClient: httpClient);
    addTearDown(supabase.dispose);
    repository = TodoRepository(supabase);
  });

  test('lists the open tasks', () async {
    httpClient.stubTable(
      'todos',
      rows: [
        {'task': 'Ship it'},
        {'task': 'Write tests'},
      ],
    );

    final tasks = await repository.openTasks();

    expect(tasks, ['Ship it', 'Write tests']);
    final request = httpClient.requestsTo('/rest/v1/todos').single;
    expect(request.queryParameters['status'], 'eq.false');
  });

  test('sends the new todo to the table', () async {
    httpClient.stubTable('todos', method: 'POST', statusCode: 201);

    await repository.add('Release');

    final insert = httpClient.requestsTo('/rest/v1/todos', method: 'POST');
    expect(insert.single.jsonBody, {'task': 'Release', 'status': false});
  });

  test('surfaces a database error', () async {
    httpClient.stubTable(
      'todos',
      rows: {'message': 'permission denied', 'code': '42501'},
      statusCode: 403,
    );

    await expectLater(
      repository.openTasks,
      throwsA(isA<PostgrestApiException>()),
    );
  });

  test('runs as a signed-in user', () async {
    httpClient.stubTable('todos', rows: []);
    final session = await signInTestUser(supabase.auth);

    await repository.openTasks();

    final request = httpClient.requests.single;
    expect(request.headers['Authorization'], 'Bearer ${session.accessToken}');
  });
}
