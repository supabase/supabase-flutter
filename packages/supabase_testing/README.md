# supabase_testing

Test helpers for apps and packages built on the Supabase Dart and Flutter
clients. Your tests run against a real `SupabaseClient` whose HTTP layer is
stubbed per endpoint, so no Supabase stack, network access or hand-rolled
fakes are needed. The test suites of the Supabase client packages themselves
run on the same primitives.

## Getting started

Add the package as a dev dependency:

```yaml
dev_dependencies:
  supabase_testing: ^0.1.0
```

Create a client with `testSupabaseClient`, hand it a `MockSupabaseHttpClient`,
and stub the endpoints the code under test talks to:

```dart
import 'package:supabase_testing/supabase_testing.dart';
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
`stub`, which matches on method and URL path:

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

## Asserting on requests

The client records every request it answered in `requests`, with the body
already read:

```dart
await supabase.from('todos').insert({'task': 'Write tests'});

final request = httpClient.requests.single;
expect(request.method, 'POST');
expect(request.url.path, '/rest/v1/todos');
expect(request.jsonBody, {'task': 'Write tests'});
```

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

For code that inspects tokens, `unsignedTestJwt` and `signedTestJwt` craft
JWTs carrying exactly the claims you pass, with no auto-injected `iat` and no
claim overrides, and `decodeTestJwtClaims` reads them back for assertions.
The fixtures `testUserJson`, `testSessionResponseJson` and `getSessionData`
produce the JSON shapes the auth server would return.

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

## A note on scope

Every helper is annotated with `@visibleForTesting`, so the analyzer warns if
one ends up in production code.
