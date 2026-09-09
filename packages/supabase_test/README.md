# supabase_test

Test helpers for apps and packages built on the Supabase Dart and Flutter
clients. Your tests run against a real `SupabaseClient` whose HTTP layer is
stubbed per endpoint, so no Supabase stack, network access or hand-rolled
fakes are needed. The test suites of the Supabase client packages themselves
run on the same primitives.

## Getting started

Add the package as a dev dependency:

```yaml
dev_dependencies:
  supabase_test: ^0.1.0
```

Create a client with `testSupabaseClient`, hand it a `MockSupabaseHttpClient`,
and stub the endpoints the code under test talks to:

```dart
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  test('loads the open todos', () async {
    final httpClient = MockSupabaseHttpClient()
      ..stubTable('todos', rows: [
        {'id': 1, 'task': 'Ship it', 'status': false},
      ]);
    final supabase = testSupabaseClient(httpClient: httpClient);
    addTearDown(supabase.dispose);

    final todos = await supabase.from('todos').select();

    expect(todos, hasLength(1));
  });
}
```

`testSupabaseClient` is a regular `SupabaseClient` wired for tests: it
configures the in-memory storage the pkce flow requires, turns off the token
auto refresh so no timer outlives the test, and defaults the API key to an
unsigned test JWT. Dispose it when the test ends, for example with
`addTearDown(supabase.dispose)`.

## Stubbing endpoints

`MockSupabaseHttpClient` answers requests from stubs registered per endpoint:

```dart
final httpClient = MockSupabaseHttpClient()
  // Database reads and writes: /rest/v1/<table>
  ..stubTable('todos', rows: [
    {'id': 1, 'task': 'Ship it', 'status': false},
  ])
  // Postgres functions called through rpc: /rest/v1/rpc/<function>
  ..stubRpc('add_them', body: 3)
  // Edge functions: /functions/v1/<function>
  ..stubEdgeFunction('hello', body: {'message': 'hi'})
  // The token endpoint, so signInWithPassword and friends succeed
  ..stubSignIn();
```

Anything else, storage endpoints for example, is stubbed through the general
`stub`, which matches on method and URL path. A path matches a request whose
path is the same or ends in it, so stubs written for `/rest/v1/todos` keep
working for a project served under a path prefix:

```dart
httpClient.stub(
  {'Key': 'avatars/me.png'},
  method: 'POST',
  path: '/storage/v1/object/avatars/me.png',
);
```

Three rules cover most test setups:

- **The latest matching stub wins.** Register broad defaults in `setUp` and
  override them inside a single test.
- **`times` limits how often a stub answers.** Stub a sequence by registering
  the later responses first, or model state that changes between calls:

  ```dart
  httpClient.stubTable('todos', rows: []);
  httpClient.stubTable('todos', rows: [newTodo], times: 1);
  // First select returns [newTodo], every one after that returns [].
  ```

- **An unmatched request throws.** The `StateError` names the request and the
  registered stubs, so a typo in a path surfaces as a failing test with the
  mismatch spelled out instead of a silent wrong answer.

Failures are stubbed with `statusCode` and the error shape of the service:

```dart
httpClient.stubTable(
  'todos',
  rows: {'message': 'permission denied', 'code': '42501'},
  statusCode: 403,
);
// supabase.from('todos').select() now throws a PostgrestApiException.
```

### Single rows and counts

`stubTable` and `stubRpc` shape their rows the way PostgREST would for the
query that arrives. A query ending in `single()` receives the only row of a
one-row list, and the `PGRST116` error when the list holds any other number
of rows, so the same stub serves both a list query and a single-row query:

```dart
httpClient.stubTable('todos', rows: [
  {'id': 1, 'task': 'Ship it'},
]);

final todos = await supabase.from('todos').select();
final todo = await supabase.from('todos').select().eq('id', 1).single();
```

A query asking for a count receives the number of stubbed rows, or the
`count` you pass when the stub represents one page of a larger table:

```dart
httpClient.stubTable('todos', rows: [{'id': 1}], count: 42);

final page = await supabase
    .from('todos')
    .select()
    .limit(1)
    .count(CountOption.exact);
// page.data has one row, page.count is 42.
```

### Responses that depend on the request

When a fixed body is not enough, `stubHandler` builds the response from the
request it receives, with the body already read. `jsonResponse` wraps a JSON
body with the right content type:

```dart
httpClient.stubHandler(
  (request) {
    final params = request.jsonBody as Map<String, dynamic>;
    return jsonResponse(params['a'] + params['b']);
  },
  path: '/rest/v1/rpc/add_them',
);

httpClient.stubHandler(
  (request) => request.url.queryParameters['city'] == null
      ? jsonResponse({'message': 'city is required'}, statusCode: 400)
      : jsonResponse({'weather': 'sunny'}),
  path: '/functions/v1/weather',
);
```

The handler may be asynchronous and may return any `http.Response`, so a
plain text or binary edge function response is a `Response.bytes` away. A
`Uint8List` passed as the body of `stub` or `stubEdgeFunction` is sent as
bytes with the content type `application/octet-stream`.

A client shared between tests is wiped with `reset`, which forgets the
registered stubs and the recorded requests.

## Asserting on requests

The client records every request it answered in `requests`, with the body
already read, and `requestsTo` narrows them down by path and method:

```dart
await supabase.from('todos').select().eq('status', true);
await supabase.from('todos').insert({'task': 'Write tests'});

final select = httpClient.requestsTo('/rest/v1/todos', method: 'GET').single;
expect(select.queryParameters['status'], 'eq.true');

final insert = httpClient.requestsTo('/rest/v1/todos', method: 'POST').single;
expect(insert.jsonBody, {'task': 'Write tests'});
```

Headers are looked up case-insensitively, as on the request itself.

## Testing auth

To run a test as a signed-in user, `signInTestUser` puts the client into a
signed-in state without any network traffic:

```dart
final session = await signInTestUser(
  supabase.auth,
  userId: 'user-1',
  email: 'someone@example.com',
);

// currentUser and currentSession are set, and every request now carries
// the session token:
await supabase.from('todos').select();
expect(
  httpClient.requests.last.headers['Authorization'],
  'Bearer ${session.accessToken}',
);
```

To test a sign-in flow itself, stub the token endpoint instead and call the
real API:

```dart
httpClient.stubSignIn(user: testUserJson(id: 'user-1'));

await supabase.auth.signInWithPassword(
  email: 'someone@example.com',
  password: 'password',
);
```

`stubSignUp`, `stubSignOut` and `stubUser` cover the sign-up, logout and user
endpoints the same way, so `signUp`, `signOut`, `getUser` and `updateUser`
run against stubs too.

For code that inspects tokens, `unsignedTestJwt` and `signedTestJwt` craft
JWTs carrying exactly the claims you pass, with no auto-injected `iat` and no
claim overrides, and `decodeTestJwtClaims` reads them back for assertions.
The fixtures `testUserJson` and `testSessionResponseJson` produce the JSON
shapes the auth server would return.

## Testing realtime

Realtime needs a WebSocket rather than an HTTP stub. For unit tests that feed
frames into a mock socket, `postgresChangesFrame` encodes a
`postgres_changes` frame the way the server sends it. For anything beyond
that, run against a real stack (see below).

## Flutter apps

Widget tests initialize `supabase_flutter` the same way, with persistence
pointed at in-memory implementations:

```dart
await Supabase.initialize(
  url: 'http://localhost:54321',
  publishableKey: unsignedTestJwt({'role': 'anon'}),
  httpClient: httpClient,
  authOptions: FlutterAuthClientOptions(
    localStorage: const EmptyLocalStorage(),
    pkceAsyncStorage: MemoryAuthAsyncStorage(),
    autoRefreshToken: false,
  ),
);
addTearDown(Supabase.instance.dispose);
```

## Testing against a real stack

Mocks are for fast unit tests. For integration coverage, run your tests
against a local Supabase stack started with the
[Supabase CLI](https://supabase.com/docs/guides/local-development) and point
your client at the URL and keys `supabase start` prints.

## Migrating from mock_supabase_http_client

The community package `mock_supabase_http_client` kept an in-memory database
and interpreted every filter, order and limit of a query. `supabase_test`
takes the other approach and answers each endpoint with what you stub, which
keeps a test independent of the query it runs and keeps the mock free of
subtle differences to PostgREST. The pieces map as follows:

- Rows that used to be inserted through the client are passed to `stubTable`
  as `rows`. The filters of a query are not applied, so stub the rows the
  query is expected to return.
- `registerRpcFunction` and `registerEdgeFunction` become `stubRpc` and
  `stubEdgeFunction` for fixed responses, or `stubHandler` when the response
  depends on the parameters.
- `postgrestExceptionTrigger` becomes a stub with an error `statusCode`, or a
  `stubHandler` that chooses the status per request.
- `reset` keeps its name.

## A note on scope

Every helper is annotated with `@visibleForTesting`, so the analyzer warns if
one ends up in production code.
