import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
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
        () => supabase.from('todos').select(),
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

  group('PostgREST shaping', () {
    test('single returns the only row of a one-row list', () async {
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1, 'task': 'Ship it'},
        ],
      );

      final todo = await supabase.from('todos').select().eq('id', 1).single();

      expect(todo, {'id': 1, 'task': 'Ship it'});
    });

    test('single passes a stubbed object through untouched', () async {
      httpClient.stubTable('todos', rows: {'id': 1, 'task': 'Ship it'});

      final todo = await supabase.from('todos').select().single();

      expect(todo, {'id': 1, 'task': 'Ship it'});
    });

    test('single fails with PGRST116 when no row matches', () async {
      httpClient.stubTable('todos', rows: []);

      await expectLater(
        () => supabase.from('todos').select().single(),
        throwsA(
          isA<PostgrestApiException>()
              .having(
                (exception) => exception.errorCode,
                'errorCode',
                'PGRST116',
              )
              .having((exception) => exception.statusCode, 'statusCode', 406),
        ),
      );
    });

    test('single fails with PGRST116 when several rows match', () async {
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1},
          {'id': 2},
        ],
      );

      await expectLater(
        () => supabase.from('todos').select().single(),
        throwsA(
          isA<PostgrestApiException>().having(
            (exception) => exception.errorCode,
            'errorCode',
            'PGRST116',
          ),
        ),
      );
    });

    test('single after an insert returns the inserted row', () async {
      httpClient.stubTable(
        'todos',
        method: 'POST',
        statusCode: 201,
        rows: [
          {'id': 1, 'task': 'Write tests'},
        ],
      );

      final todo = await supabase
          .from('todos')
          .insert({'task': 'Write tests'})
          .select()
          .single();

      expect(todo, {'id': 1, 'task': 'Write tests'});
    });

    test('maybeSingle resolves to null for no rows', () async {
      httpClient.stubTable('todos', rows: []);

      final todo = await supabase.from('todos').select().maybeSingle();

      expect(todo, isNull);
    });

    test('an error body is not shaped for single', () async {
      httpClient.stubTable(
        'todos',
        rows: {'message': 'permission denied', 'code': '42501'},
        statusCode: 403,
      );

      await expectLater(
        () => supabase.from('todos').select().single(),
        throwsA(
          isA<PostgrestApiException>().having(
            (exception) => exception.errorCode,
            'errorCode',
            '42501',
          ),
        ),
      );
    });

    test('count defaults to the number of stubbed rows', () async {
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1},
          {'id': 2},
        ],
      );

      final response = await supabase
          .from('todos')
          .select()
          .count(CountOption.exact);

      expect(response.data, hasLength(2));
      expect(response.count, 2);
    });

    test('an explicit count overrides the number of rows', () async {
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1},
        ],
        count: 42,
      );

      final response = await supabase
          .from('todos')
          .select()
          .limit(1)
          .count(CountOption.exact);

      expect(response.data, hasLength(1));
      expect(response.count, 42);
    });

    test('a head count carries no body', () async {
      httpClient.stubTable('todos', rows: [], count: 7);

      final count = await supabase.from('todos').count();

      expect(count, 7);
      expect(httpClient.requests.single.method, 'HEAD');
    });

    test('single combined with count', () async {
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1},
        ],
      );

      final response = await supabase
          .from('todos')
          .select()
          .single()
          .count(CountOption.exact);

      expect(response.data, {'id': 1});
      expect(response.count, 1);
    });

    test('no content-range is sent unless a count was asked for', () async {
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1},
        ],
      );

      final response = await httpClient.get(
        Uri.parse('http://localhost:54321/rest/v1/todos'),
      );

      expect(response.headers, isNot(contains('content-range')));
    });

    test('stubRpc shapes a single result', () async {
      httpClient.stubRpc(
        'current_profile',
        body: [
          {'id': 'user-1'},
        ],
      );

      final profile = await supabase.rpc('current_profile').select().single();

      expect(profile, {'id': 'user-1'});
    });
  });

  group('stubHandler', () {
    test('builds the response from the request body', () async {
      httpClient.stubHandler((request) {
        final params = request.jsonBody as Map<String, dynamic>;
        return jsonResponse(params['a'] + params['b']);
      }, path: '/rest/v1/rpc/add_them');

      final result = await supabase.rpc('add_them', params: {'a': 1, 'b': 2});

      expect(result, 3);
    });

    test('sees the method and query of an edge function invocation', () async {
      httpClient.stubHandler((request) {
        return jsonResponse({
          'method': request.method,
          'city': request.url.queryParameters['city'],
        });
      }, path: '/functions/v1/where');

      final response = await supabase.functions.invoke(
        'where',
        method: HttpMethod.patch,
        queryParameters: {'city': 'Springfield'},
      );

      expect(response.data, {'method': 'PATCH', 'city': 'Springfield'});
    });

    test('chooses the status code per request', () async {
      httpClient.stubHandler(
        (request) {
          final row = request.jsonBody as Map<String, dynamic>;
          if (row['email'] == 'taken@example.com') {
            return jsonResponse(
              {'message': 'duplicate key value', 'code': '23505'},
              statusCode: 409,
            );
          }
          return jsonResponse([row], statusCode: 201);
        },
        method: 'POST',
        path: '/rest/v1/users',
      );

      await supabase.from('users').insert({'email': 'free@example.com'});

      await expectLater(
        () => supabase.from('users').insert({'email': 'taken@example.com'}),
        throwsA(
          isA<PostgrestApiException>().having(
            (exception) => exception.errorCode,
            'errorCode',
            '23505',
          ),
        ),
      );
    });

    test('may answer asynchronously with any response', () async {
      httpClient.stubHandler(
        (request) async => http.Response('plain text', 200),
        path: '/functions/v1/text',
      );

      final response = await supabase.functions.invoke('text');

      expect(response.data, 'plain text');
    });

    test('encodes non-ASCII JSON as UTF-8', () async {
      httpClient.stubHandler(
        (request) => jsonResponse({'greeting': 'こんにちは 👋'}),
        path: '/functions/v1/hello',
      );

      final response = await supabase.functions.invoke('hello');

      expect(response.data, {'greeting': 'こんにちは 👋'});
    });
  });

  group('binary bodies', () {
    test('a Uint8List body reaches the caller as bytes', () async {
      httpClient.stubEdgeFunction(
        'binary',
        body: Uint8List.fromList([1, 2, 3]),
      );

      final response = await supabase.functions.invoke('binary');

      expect(response.data, isA<Uint8List>());
      expect(response.data, [1, 2, 3]);
    });
  });

  group('reset', () {
    test('forgets the stubs and the recorded requests', () async {
      httpClient.stubTable('todos', rows: []);
      await supabase.from('todos').select();

      httpClient.reset();

      expect(httpClient.requests, isEmpty);
      await expectLater(
        () => supabase.from('todos').select(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('path matching', () {
    test('a stub answers a project served under a path prefix', () async {
      final prefixed = testSupabaseClient(
        httpClient: httpClient,
        url: 'http://localhost:54321/supabase',
      );
      addTearDown(prefixed.dispose);
      httpClient.stubTable(
        'todos',
        rows: [
          {'id': 1},
        ],
      );

      final todos = await prefixed.from('todos').select();

      expect(todos, hasLength(1));
      expect(httpClient.requests.single.url.path, '/supabase/rest/v1/todos');
    });

    test('a suffix only matches at a segment boundary', () {
      httpClient.stubTable('todos', rows: []);

      expect(
        () => httpClient.get(
          Uri.parse('http://localhost:54321/rest/v1/my_todos'),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('recorded requests', () {
    test('headers are looked up case-insensitively', () async {
      httpClient.stubTable('todos', rows: []);
      final session = await signInTestUser(supabase.auth);

      await supabase.from('todos').select();

      final request = httpClient.requests.single;
      expect(request.headers['authorization'], 'Bearer ${session.accessToken}');
      expect(request.headers['AUTHORIZATION'], 'Bearer ${session.accessToken}');
    });

    test('requestsTo narrows by path and method', () async {
      httpClient.stubTable('todos', rows: []);
      httpClient.stubTable('profiles', rows: []);

      await supabase.from('todos').select();
      await supabase.from('profiles').select();
      await supabase.from('todos').insert({'task': 'Write tests'});

      expect(httpClient.requestsTo('/rest/v1/todos'), hasLength(2));
      final inserts = httpClient.requestsTo('/rest/v1/todos', method: 'POST');
      expect(inserts.single.jsonBody, {'task': 'Write tests'});
    });

    test('queryParameters exposes the query of the request', () async {
      httpClient.stubTable('todos', rows: []);

      await supabase.from('todos').select('id').eq('status', true);

      final query = httpClient.requests.single.queryParameters;
      expect(query, {'select': 'id', 'status': 'eq.true'});
    });
  });

  group('auth shorthands', () {
    test('stubSignUp lets a sign-up produce a session', () async {
      httpClient.stubSignUp(user: testUserJson(id: 'new-user'));

      final response = await supabase.auth.signUp(
        email: 'new@example.com',
        password: 'password',
      );

      expect(response.session, isNotNull);
      expect(supabase.auth.currentUser?.id, 'new-user');
    });

    test('stubSignOut lets a signed-in client sign out', () async {
      httpClient.stubSignOut();
      await signInTestUser(supabase.auth);

      await supabase.auth.signOut();

      expect(supabase.auth.currentSession, isNull);
      final request = httpClient.requestsTo('/auth/v1/logout').single;
      expect(request.method, 'POST');
    });

    test('stubUser answers getUser', () async {
      httpClient.stubUser(user: testUserJson(email: 'fresh@example.com'));
      await signInTestUser(supabase.auth);

      final response = await supabase.auth.getUser();

      expect(response.user?.email, 'fresh@example.com');
    });
  });

  group('query matching', () {
    test(
      'differently filtered reads of one table receive different rows',
      () async {
        httpClient.stubTable(
          'todos',
          query: {'id': 'eq.1'},
          rows: [
            {'id': 1, 'task': 'First'},
          ],
        );
        httpClient.stubTable(
          'todos',
          query: {'id': 'eq.2'},
          rows: [
            {'id': 2, 'task': 'Second'},
          ],
        );

        final first = await supabase
            .from('todos')
            .select()
            .eq('id', 1)
            .single();
        final second = await supabase
            .from('todos')
            .select()
            .eq('id', 2)
            .single();

        expect(first['task'], 'First');
        expect(second['task'], 'Second');
      },
    );

    test('a query stub matches a subset of the request query', () async {
      httpClient.stubTable('todos', query: {'status': 'eq.true'}, rows: []);

      final done = await supabase
          .from('todos')
          .select('id, task')
          .eq('status', true)
          .order('id');

      expect(done, isEmpty);
    });

    test('a query stub does not answer a request without the entry', () async {
      httpClient.stubTable('todos', query: {'status': 'eq.true'}, rows: []);

      await expectLater(
        () => supabase.from('todos').select(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('/rest/v1/todos?status=eq.true'),
          ),
        ),
      );
    });

    test('a broad stub still answers what the narrow one does not', () async {
      httpClient.stubTable('todos', rows: []);
      httpClient.stubTable(
        'todos',
        query: {'status': 'eq.false'},
        rows: [
          {'id': 1},
        ],
      );

      final open = await supabase.from('todos').select().eq('status', false);
      final all = await supabase.from('todos').select();

      expect(open, hasLength(1));
      expect(all, isEmpty);
    });

    test('edge function invocations match on their query parameters', () async {
      httpClient.stubEdgeFunction(
        'weather',
        query: {'city': 'Springfield'},
        body: {'weather': 'sunny'},
      );
      httpClient.stubEdgeFunction(
        'weather',
        query: {'city': 'Shelbyville'},
        body: {'weather': 'rain'},
      );

      final response = await supabase.functions.invoke(
        'weather',
        queryParameters: {'city': 'Shelbyville'},
      );

      expect(response.data, {'weather': 'rain'});
    });
  });
}
