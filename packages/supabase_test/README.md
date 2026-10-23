# supabase_test

Test helpers for apps and packages built on the Supabase Dart and Flutter
clients. Your tests run against a real `SupabaseClient` whose HTTP layer is
stubbed per endpoint and whose realtime socket is served in memory, so no
Supabase stack, network access or hand-rolled fakes are needed. The test
suites of the Supabase client packages themselves run on the same primitives.

## Rules

- Test against a real client from `testSupabaseClient`, or
  `initializeTestSupabase` in a Flutter widget test. Do not mock or subclass
  `SupabaseClient`, `AuthClient` or the query builders, and do not subclass
  `http.BaseClient` for Supabase requests.
- Answer requests with the `stub…` methods of `MockSupabaseHttpClient`. Stub
  the rows the code under test should receive: filters are not evaluated.
- Put a client into a signed-in state with `signInTestUser`. Build auth
  payloads with `testUserJson` and `testSessionResponseJson`, and tokens with
  `unsignedTestJwt`. Do not hand-assemble a JWT or session JSON.
- Assert on what was sent with `requests` and `requestsTo`.
- Dispose every client at the end of the test.

A coding agent learns the same rules from the `supabase-test-testing`
[package skill](https://dart.dev/ai/package-skills) this package ships.
Install it into your project with `dart run skills@ get -p supabase_test`.

## Getting started

Add the package as a dev dependency:

```sh
dart pub add dev:supabase_test
```

Create a client with `testSupabaseClient`, hand it a `MockSupabaseHttpClient`,
and stub the endpoints the code under test talks to. The examples query a
`books` table through the types that
[`supabase_typegen`](https://pub.dev/packages/supabase_typegen) generates
into `lib/supabase_schema.g.dart`. Replace `my_app` with the name of your
package:

```dart test-file
import 'package:my_app/supabase_schema.g.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  test('loads the books in print', () async {
    final httpClient = MockSupabaseHttpClient()
      ..stubTable(
        'books',
        rows: [
          {'id': 1, 'author_id': 2, 'title': 'Dune', 'in_print': true},
        ],
      );
    final supabase = testSupabaseClient(httpClient: httpClient);
    addTearDown(supabase.dispose);

    final books = await supabase
        .table(Books.table)
        .selectOnly([Books.id, Books.title])
        .where(Books.inPrint.isTrue());

    expect(books.single.read(Books.title), 'Dune');
  });
}
```

The stubbed rows are the JSON PostgREST would return, with the column names of
the database, so a typed query decodes them exactly like a real response.
Stub every column the code under test reads: a row type decodes a column when
it is read, so reading `BooksRow.createdAt` from a row stubbed without
`created_at` throws. The untyped `supabase.from('books')` is answered by the
same stubs.

`testSupabaseClient` is a regular `SupabaseClient` wired for tests: it
configures the in-memory storage the PKCE flow requires, turns off the token
auto refresh so no timer outlives the test, and defaults the publishable key
to an `sb_publishable_` test key, so signed-out requests carry the headers a
production publishable key produces. Dispose
it when the test ends, for example with `addTearDown(supabase.dispose)`.

## Stubbing endpoints

`MockSupabaseHttpClient` answers requests from stubs registered per endpoint:

```dart test
final httpClient = MockSupabaseHttpClient()
  // Database reads and writes: /rest/v1/<table>
  ..stubTable(
    'books',
    rows: [
      {'id': 1, 'author_id': 2, 'title': 'Dune', 'in_print': true},
    ],
  )
  // Database functions called through rpc: /rest/v1/rpc/<function>
  ..stubRpc('add_them', body: 3)
  // Edge functions: /functions/v1/<function>
  ..stubEdgeFunction('hello', body: {'message': 'hi'})
  // The token endpoint, so signInWithPassword and friends succeed
  ..stubSignIn();
```

Storage has shorthands for the calls apps make most, which know the paths
and the response shapes of the storage API:

```dart test-file
import 'dart:typed_data';

import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  test('downloads the avatar', () async {
    final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
    final httpClient = MockSupabaseHttpClient()
      ..stubStorageUpload('avatars', 'me.png')
      ..stubStorageDownload('avatars', 'me.png', bytes: pngBytes)
      ..stubStorageSignedUrl('avatars', 'me.png')
      ..stubStorageList('avatars', objects: [storageObjectJson('me.png')])
      ..stubStorageRemove('avatars', paths: ['me.png']);
    final supabase = testSupabaseClient(httpClient: httpClient);
    addTearDown(supabase.dispose);

    final bytes = await supabase.storage.from('avatars').download('me.png');

    expect(bytes, pngBytes);
  });
}
```

Anything else is stubbed through the general `stub`, which matches on method
and URL path. A path matches a request whose path is the same or ends in it,
so stubs written for `/rest/v1/books` keep working for a project served under
a path prefix:

```dart test
final httpClient = MockSupabaseHttpClient()
  ..stub(
    {'name': 'avatars', 'id': 'avatars', 'public': true},
    method: HttpMethod.get,
    path: '/storage/v1/bucket/avatars',
  );
```

These rules cover most test setups:

- **The latest matching stub wins.** Register broad defaults in `setUp` and
  override them inside a single test.
- **`times` limits how often a stub answers.** Stub a sequence by registering
  the later responses first, or model state that changes between calls:

  ```dart test
  final httpClient = MockSupabaseHttpClient()
    ..stubTable('books', rows: [])
    ..stubTable(
      'books',
      rows: [
        {'id': 1, 'author_id': 2, 'title': 'Dune', 'in_print': true},
      ],
      times: 1,
    );
  // The first select returns Dune, every one after that returns no rows.
  ```

- **`query` narrows a stub to matching query parameters.** The stub answers
  only requests whose query carries every entry, so differently filtered
  reads of one table can receive different rows:

  ```dart test
  final httpClient = MockSupabaseHttpClient()
    ..stubTable(
      'books',
      query: {'id': 'eq.1'},
      rows: [
        {'id': 1, 'author_id': 2, 'title': 'Dune', 'in_print': true},
      ],
    )
    ..stubTable(
      'books',
      query: {'id': 'eq.2'},
      rows: [
        {'id': 2, 'author_id': 2, 'title': 'Emma', 'in_print': false},
      ],
    );
  ```

- **`schema` narrows a table or function stub to one schema.** A request to a
  table outside `public` carries its schema in a header, so a stub for
  `public.books` and one for `inventory.books` can answer differently. A stub
  without a schema answers every schema.

- **An unmatched request throws.** The `StateError` names the request and the
  registered stubs, so a typo in a path surfaces as a failing test with the
  mismatch spelled out instead of a silent wrong answer.

Failures are stubbed with `statusCode` and the error shape of the service:

```dart test
final httpClient = MockSupabaseHttpClient()
  ..stubTable(
    'books',
    rows: {'message': 'permission denied', 'code': '42501'},
    statusCode: 403,
  );
final supabase = testSupabaseClient(httpClient: httpClient);
addTearDown(supabase.dispose);

await expectLater(
  () => supabase.table(Books.table).select(),
  throwsA(isA<PostgrestApiException>()),
);
```

### Single rows and counts

`stubTable` and `stubRpc` shape their rows the way PostgREST would for the
query that arrives. A query ending in `single()` receives the only row of a
one-row list, and the `PGRST116` error when the list holds any other number
of rows, so the same stub serves both a list query and a single-row query:

```dart test
final httpClient = MockSupabaseHttpClient()
  ..stubTable(
    'books',
    rows: [
      {'id': 1, 'author_id': 2, 'title': 'Dune', 'in_print': true},
    ],
  );
final supabase = testSupabaseClient(httpClient: httpClient);
addTearDown(supabase.dispose);

final books = await supabase.table(Books.table).selectOnly([Books.title]);
final book = await supabase
    .table(Books.table)
    .selectOnly([Books.title])
    .where(Books.id.eq(1))
    .single();
expect(book.read(Books.title), 'Dune');
```

A query asking for a count receives the number of stubbed rows, or the
`count` you pass when the stub represents one page of a larger table:

```dart test
final httpClient = MockSupabaseHttpClient()
  ..stubTable(
    'books',
    rows: [
      {'id': 1, 'author_id': 2, 'title': 'Dune', 'in_print': true},
    ],
    count: 42,
  );
final supabase = testSupabaseClient(httpClient: httpClient);
addTearDown(supabase.dispose);

final page = await supabase
    .table(Books.table)
    .selectOnly([Books.title])
    .limit(1)
    .count(CountOption.exact);

expect(page.data, hasLength(1));
expect(page.count, 42);
```

### Responses that depend on the request

When a fixed body is not enough, `stubHandler` builds the response from the
request it receives, with the body already read. `jsonResponse` wraps a JSON
body with the right content type:

```dart test
final httpClient = MockSupabaseHttpClient()
  ..stubHandler((request) {
    final params = request.jsonBody as Map<String, dynamic>;
    return jsonResponse((params['a'] as int) + (params['b'] as int));
  }, path: '/rest/v1/rpc/add_them')
  ..stubHandler(
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

### Failures, stalls and status sequences

Not every response is a body under a status. `stubStall` never answers a
request, and `stubStatuses` walks it through a sequence of statuses, one per
request, repeating the last one once they run out:

```dart test
final httpClient = MockSupabaseHttpClient()
  // Never answered, so only a timeout or an abort ends the request.
  ..stubStall(path: '/functions/v1/slow')
  // 503, 503, then 200 for this request and every one after it.
  ..stubStatuses([503, 503, 200], body: [], path: '/rest/v1/books');
```

`stubError` takes the exception to throw, usually the `ClientException` of
`package:http`, and the client reports it as a `SupabaseTransportException`.
Like every stub, it takes `times` to fail only the first requests:

```dart test-file
import 'package:http/http.dart';
import 'package:my_app/supabase_schema.g.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_test/supabase_test.dart';
import 'package:test/test.dart';

void main() {
  test('reports an offline network', () async {
    final httpClient = MockSupabaseHttpClient()
      ..stubError(ClientException('Offline'));
    final supabase = testSupabaseClient(httpClient: httpClient);
    addTearDown(supabase.dispose);

    await expectLater(
      () => supabase.table(Books.table).select(),
      throwsA(isA<SupabaseTransportException>()),
    );
  });
}
```

`stubText` answers with a body that is not JSON, the HTML error page of a
gateway for example, and carries the reason phrase the client falls back to:

```dart test
final httpClient = MockSupabaseHttpClient()
  ..stubText(
    '<html><body>502 Bad Gateway</body></html>',
    statusCode: 502,
    reasonPhrase: 'Bad Gateway',
  );
```

A client shared between tests is wiped with `reset`, which forgets the
registered stubs and the recorded requests.

## Asserting on requests

The client records every request it answered in `requests`, with the body
already read, and `requestsTo` narrows them down by path and method:

```dart test
final httpClient = MockSupabaseHttpClient()..stubTable('books', rows: []);
final supabase = testSupabaseClient(httpClient: httpClient);
addTearDown(supabase.dispose);

await supabase
    .table(Books.table)
    .selectOnly([Books.title])
    .where(Books.inPrint.isTrue());
await supabase
    .table(Books.table)
    .insert(BooksInsert(authorId: 2, title: 'Dune'));

final select = httpClient
    .requestsTo('/rest/v1/books', method: HttpMethod.get)
    .single;
expect(select.queryParameters['in_print'], 'is.true');

final insert = httpClient
    .requestsTo('/rest/v1/books', method: HttpMethod.post)
    .single;
expect(insert.jsonBody, {'author_id': 2, 'title': 'Dune'});
```

Headers are looked up case-insensitively, as on the request itself. For what
does not survive the wire format, `request` holds the `BaseRequest` the
client received, so a multipart upload can be asserted on through its
`files`:

```dart skip
final upload = httpClient.requests.single.request as MultipartRequest;
expect(upload.files.single.contentType.mimeType, 'image/png');
```

## Testing auth

To run a test as a signed-in user, `signInTestUser` puts the client into a
signed-in state without any network traffic:

```dart test
final httpClient = MockSupabaseHttpClient()..stubTable('books', rows: []);
final supabase = testSupabaseClient(httpClient: httpClient);
addTearDown(supabase.dispose);

final session = await signInTestUser(
  supabase.auth,
  userId: 'user-1',
  email: 'someone@example.com',
);

// currentUser and currentSession are set, and every request now carries
// the session token.
await supabase.table(Books.table).selectOnly([Books.title]);
expect(
  httpClient.requests.last.headers['Authorization'],
  'Bearer ${session.accessToken}',
);
```

To test a sign-in flow itself, stub the token endpoint instead and call the
real API:

```dart test
final httpClient = MockSupabaseHttpClient()
  ..stubSignIn(user: testUserJson(id: 'user-1'));
final supabase = testSupabaseClient(httpClient: httpClient);
addTearDown(supabase.dispose);

final session = await supabase.auth.signInWithPassword(
  email: 'someone@example.com',
  password: 'password',
);
expect(session.user.id, 'user-1');
```

`stubSignUp`, `stubSignOut` and `stubUser` cover the sign-up, logout and user
endpoints the same way, so `signUp`, `signOut`, `getUser` and `updateUser`
run against stubs too.

For code that inspects tokens, `unsignedTestJwt` and `signedTestJwt` craft
JWTs carrying exactly the claims you pass, with no automatically added `iat`
and no claim overrides, and `decodeTestJwtClaims` reads them back for
assertions. The fixtures `testUserJson` and `testSessionResponseJson` produce
the JSON shapes the auth server would return.

## Testing realtime

Realtime runs over a WebSocket rather than HTTP, so it is answered by a
`MockRealtimeTransport` instead: a realtime server in memory that joins
channels, acknowledges pushes and heartbeats, and lets the test push server
events:

```dart test
final realtime = MockRealtimeTransport();
final supabase = testSupabaseClient(
  httpClient: MockSupabaseHttpClient(),
  realtimeTransport: realtime.call,
);
addTearDown(supabase.dispose);

final channel = supabase.channel('books');
final changes = channel.onTableChanges(
  Books.table,
  event: PostgresChangeEvent.insert,
);
channel.subscribe();
await channel.onStatusChange.firstWhere(
  (change) => change.status == RealtimeSubscribeStatus.subscribed,
);

realtime.emitPostgresChange(
  table: 'books',
  event: PostgresChangeEvent.insert,
  newRecord: {'id': 1, 'author_id': 2, 'title': 'Dune', 'in_print': true},
);
final change = await changes.first;
expect(change, isA<TypedPostgresInsert<BooksRow, BooksRow>>());
```

`emitPostgresChange` reaches every joined channel bound to the table and
event, which includes the channel a `stream()` opens, so a `stream()` test
stubs the initial rows with `stubTable` and then emits the changes it wants
to see applied. Filters are not evaluated, so emit only the changes the code
under test should see. `emitBroadcast` delivers a broadcast message to a
channel, `emit` sends any `RealtimeMessage`, and `closeConnection` drops the
connection so reconnect handling can be exercised. Everything the client sent
is recorded in `sent`, and `joinedTopics` lists what it subscribed to.

## Flutter apps

Widget tests initialize `supabase_flutter` through `initializeTestSupabase`
from `package:supabase_flutter/testing.dart`, which applies the same test
defaults as `testSupabaseClient` and takes the same `httpClient`, `url`,
`publishableKey` and `realtimeTransport` parameters:

```dart skip
import 'package:supabase_flutter/testing.dart';

final supabase = await initializeTestSupabase(httpClient: httpClient);
addTearDown(supabase.dispose);
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
