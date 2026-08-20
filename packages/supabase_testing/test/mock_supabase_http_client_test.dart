import 'package:supabase/supabase.dart';
import 'package:supabase_testing/supabase_testing.dart';
import 'package:test/test.dart';

void main() {
  late MockSupabaseHttpClient httpClient;
  late SupabaseClient supabase;

  setUp(() {
    httpClient = MockSupabaseHttpClient();
    supabase = testSupabaseClient(httpClient: httpClient);
    addTearDown(supabase.dispose);
  });

  group('stubTable', () {
    test('answers a select with the stubbed rows', () async {
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1, 'task': 'Ship it', 'status': false},
        ],
      );

      final todos = await supabase.from('todos').select();

      expect(todos, hasLength(1));
      expect(todos.single['task'], 'Ship it');
    });

    test('records the payload an insert sent', () async {
      httpClient.stubTable('todos', method: 'POST', statusCode: 201);

      await supabase.from('todos').insert({'task': 'Write tests'});

      final request = httpClient.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/todos');
      expect(request.jsonBody, {'task': 'Write tests'});
    });

    test('answers a failure status with a PostgrestApiException', () async {
      httpClient.stubTable(
        'todos',
        rows: {'message': 'permission denied', 'code': '42501'},
        statusCode: 403,
      );

      await expectLater(
        supabase.from('todos').select(),
        throwsA(
          isA<PostgrestApiException>().having(
            (exception) => exception.errorCode,
            'errorCode',
            '42501',
          ),
        ),
      );
    });
  });

  group('stub matching', () {
    test('the latest matching stub wins', () async {
      httpClient.stubTable('todos', rows: []);
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1},
        ],
      );

      final todos = await supabase.from('todos').select();

      expect(todos, hasLength(1));
    });

    test('a used-up stub falls back to the one registered before', () async {
      httpClient.stubTable('todos', rows: []);
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1},
        ],
        times: 1,
      );

      final first = await supabase.from('todos').select();
      final second = await supabase.from('todos').select();

      expect(first, hasLength(1));
      expect(second, isEmpty);
    });

    test('an unmatched request throws naming the registered stubs', () {
      httpClient.stubTable('todos', rows: []);

      expect(
        () => httpClient.get(Uri.parse('http://localhost:54321/rest/v1/x')),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('/rest/v1/x'), contains('/rest/v1/todos')),
          ),
        ),
      );
    });

    test('a null body produces an empty response', () async {
      httpClient.stub(null, statusCode: 204);

      final response = await httpClient.get(
        Uri.parse('http://localhost:54321/anything'),
      );

      expect(response.statusCode, 204);
      expect(response.body, isEmpty);
    });
  });

  group('endpoint shorthands', () {
    test('stubRpc answers a function call', () async {
      httpClient.stubRpc('add_them', body: 3);

      final result = await supabase.rpc('add_them', params: {'a': 1, 'b': 2});

      expect(result, 3);
      expect(httpClient.requests.single.url.path, '/rest/v1/rpc/add_them');
    });

    test('stubEdgeFunction answers an invocation', () async {
      httpClient.stubEdgeFunction('hello', body: {'message': 'hi'});

      final response = await supabase.functions.invoke('hello');

      expect(response.data, {'message': 'hi'});
      expect(httpClient.requests.single.url.path, '/functions/v1/hello');
    });

    test('stubSignIn lets a password sign-in produce a session', () async {
      httpClient.stubSignIn();

      final response = await supabase.auth.signInWithPassword(
        email: 'fake1@email.com',
        password: 'password',
      );

      expect(response.session, isNotNull);
      expect(supabase.auth.currentUser?.id, testUserId);
    });

    test('stubSignIn carries a custom user through to the session', () async {
      httpClient.stubSignIn(user: testUserJson(id: 'custom-id'));

      await supabase.auth.signInWithPassword(
        email: 'fake1@email.com',
        password: 'password',
      );

      expect(supabase.auth.currentUser?.id, 'custom-id');
    });
  });
}
