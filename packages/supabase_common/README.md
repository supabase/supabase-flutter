# supabase_common

Shared foundation of the Supabase Dart and Flutter client packages
(`supabase_auth`, `postgrest`, `supabase_realtime`, `supabase_storage`,
`supabase_functions`, `supabase`, `supabase_flutter`), and home of the test
helpers those packages, and your app, can test with.

The package ships two libraries with different stability guarantees:

- `package:supabase_common/testing.dart` is supported for direct use in the
  tests of apps and packages built on the Supabase clients.
- `package:supabase_common/supabase_common.dart` is an implementation detail
  of the client packages.

## Testing your app

`testing.dart` contains the helpers the test suites of the client packages
themselves run on, so your tests can build on the same primitives instead of
hand-rolling fixtures:

- **Mock HTTP clients**: `JsonResponseMockClient` answers every request with
  a canned JSON body, `FailingHttpClient` fails every request with a
  recognizable status code, `jsonStreamedResponse` builds a JSON response for
  a custom `MockClient`, and `stallUntilAborted` stalls a request until it is
  aborted.
- **JWT builders**: `unsignedTestJwt` and `signedTestJwt` craft tokens
  carrying exactly the claims you pass, with no auto-injected `iat` and no
  claim overrides, so expiry and refresh logic can be tested deterministically.
- **Auth fixtures**: `testUserJson` and `testSessionResponseJson` produce the
  JSON the auth server would return for a user and a token endpoint response,
  and `getSessionData` produces a persisted session string for a given expiry.
- **Realtime frames**: `postgresChangesFrame` encodes a `postgres_changes`
  frame the way the realtime server sends it, for tests that run against a
  mock WebSocket.
- **Local stack configuration**: the `localStack*` constants describe the
  Supabase CLI stack defined in this repository, which its integration tests
  run against.

Add the package as a dev dependency:

```yaml
dev_dependencies:
  supabase_common: ^0.1.2
```

Then hand a mock HTTP client to your Supabase client and test against it:

```dart
import 'package:supabase/supabase.dart';
import 'package:supabase_common/testing.dart';
import 'package:test/test.dart';

void main() {
  test('loads the open todos', () async {
    final supabase = SupabaseClient(
      'http://localhost:54321',
      unsignedTestJwt({'role': 'anon'}),
      httpClient: JsonResponseMockClient(
        body: [
          {'id': 1, 'task': 'Ship it', 'status': false},
        ],
      ),
      authOptions: AuthClientOptions(
        pkceAsyncStorage: MemoryAuthAsyncStorage(),
      ),
    );

    final todos = await supabase.from('todos').select();

    expect(todos, hasLength(1));
  });
}
```

Every helper is annotated with `@visibleForTesting`, so the analyzer warns if
one ends up outside of test code.

## Runtime library

> [!WARNING]
> `package:supabase_common/supabase_common.dart` is an implementation detail
> of the client packages and is not intended to be consumed directly.
> **Breaking changes can be expected** as the client packages evolve, so
> please do not depend on it directly.

The runtime library holds code that would otherwise be duplicated across the
client packages: the `SupabaseException` base class the auth, postgrest,
storage and functions exceptions extend, the shared `HttpMethod` enum and HTTP
request helpers, the `X-Client-Info` header builder, platform detection, a
small replay stream subject, base64url/PKCE helpers and a few other
primitives.
