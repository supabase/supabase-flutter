# Edge Functions

A small app that shows how to call Supabase Edge Functions with
`supabase.functions.invoke(...)`:

- **Invoke with a JSON body** over POST and read the JSON response back
  (`invoke('greet', body: {...})`).
- **Invoke over GET** with query parameters instead of a body
  (`invoke('greet', method: HttpMethod.get, queryParameters: {...})`).
- **Send custom headers** to the function (`headers: {...}`), echoed back in the
  response.
- **Send and receive plain text**: a `String` body is sent as `text/plain` and a
  `text/plain` response comes back as a `String` (`invoke('shout', body: text)`).
- **Handle errors**: a non-2xx response throws a `FunctionException` whose
  `details` carry the response body (`invoke('word-count', ...)`).

All Edge Function access is in
[`lib/functions_repository.dart`](lib/functions_repository.dart), kept separate
from the UI so the calls are easy to read and to drive from an integration test.

To keep the focus on the Supabase calls, the screen uses plain `setState` rather
than pulling in a state management package. A larger app would typically reach
for a state management solution (for example Riverpod, Bloc or Provider) instead.

The functions live in the shared Supabase config in
[`../supabase`](../supabase): their code is under `functions/` (`greet`, `shout`
and `word-count`), and the Edge Runtime is enabled in `config.toml`
(`[edge_runtime]`). `supabase start` serves every function while the stack is
running. The functions need no database tables or seed data.

The demo functions set `verify_jwt = false` in `config.toml` so the example can
call them with just the publishable (anon) key, matching the other examples,
which run unauthenticated. A real app would leave JWT verification on and read
the caller's user from the request.

## Running

From the `examples` directory, run the launcher and pick `edge_functions`:

```bash
./run.sh
```

Or run it directly against any project (with the functions deployed there):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## Integration test

[`integration_test/functions_test.dart`](integration_test/functions_test.dart)
is an end-to-end test that runs against the local stack. It drives the flow
through the repository (a JSON greeting over POST and GET, a plain-text
transform, and a validation error that surfaces as a `FunctionException`) and
drives the app widgets to greet through the UI.

With the local stack running, pass the same defines the app uses and run it on a
device (integration tests need one, so `-d macos`, an emulator or a real
device):

```bash
flutter test integration_test/functions_test.dart -d macos \
  --dart-define=SUPABASE_URL=http://localhost:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_LOCAL_PUBLISHABLE_KEY
```
