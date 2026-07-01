# Dart/Flutter codegen spike (SDK-1106)

> **DO NOT MERGE. Spike / proof of concept.**

Investigation into generating the mechanical HTTP layer of `supabase-dart`
(Storage + Functions) from the shared Smithy models in
[supabase/sdk#51](https://github.com/supabase/sdk/pull/51), producing idiomatic
Dart a maintainer would own long-term.

Companion to the Swift spike
([supabase/supabase-swift#1047](https://github.com/supabase/supabase-swift/pull/1047)).

## TL;DR: recommendation

**Adopt a small custom Dart emitter.** It is the only option that meets all
three hard constraints at once:

1. streaming request bodies (`Stream<List<int>>`, mandatory for TUS + large
   mobile uploads),
2. streaming responses (mandatory for Functions SSE/streaming),
3. no `build_runner` and no `dart:io` (so Web/WASM works).

Off-the-shelf generators were **rejected**:

| Toolchain                      | Verdict | Reason                                                                                      |
| ------------------------------ | ------- | ------------------------------------------------------------------------------------------- |
| OpenAPI Generator `dart-dio`   | Reject  | Requires `build_runner` + `built_value` + `dio`; no streaming request/response body support |
| OpenAPI Generator `dart`       | Reject  | Uses `http` but buffers all bodies; no streaming; less idiomatic output                     |
| TypeSpec / Smithy Dart emitter | N/A     | No official Dart emitter exists                                                             |
| Speakeasy                      | N/A     | No Dart target                                                                              |

The custom emitter is `bin/generate.dart` (~500 lines, zero deps beyond the
Dart SDK). It consumes the committed OpenAPI artifacts and writes `http`-based
clients into `lib/src/generated/`. Building it took roughly the length of this
spike, and extending it to Auth is incremental.

## What's here

```
packages/supabase_openapi_generator/
  openapi/                     # artifacts copied verbatim from supabase/sdk#51
    StorageService.openapi.json
    FunctionsService.openapi.json
  bin/generate.dart            # the emitter (dart run bin/generate.dart)
  lib/
    src/runtime.dart           # hand-written transport: ApiClient, streaming, errors
    src/generated/
      storage_api.g.dart       # GENERATED, 18 operations + models
      functions_api.g.dart     # GENERATED, 5 invoke operations
  test/generated_client_test.dart  # proves the spike questions against a mock client
```

Regenerate with:

```bash
dart pub get
dart run bin/generate.dart
dart test
```

## Design

The split mirrors the Swift PR: a thin hand-written **runtime**
(`ApiClient`) owns transport and headers; the **generated** clients are pure
request-building + response-decoding. The public `supabase-dart` API
(`StorageFileApi`, `FunctionsClient`, …) would sit on top as an idiomatic
facade, exactly as it does today, calling the generated methods instead of the
hand-rolled `fetch` layer.

- Built on the `http` package the SDK already depends on. No `dio`, no
  `build_runner`, no `dart:io`. The same code runs on iOS, Android, macOS,
  Windows, Linux, Web and WASM.
- Models are immutable (`final` fields, named constructor, `fromJson`/`toJson`).
  snake_case wire keys are mapped to camelCase Dart fields.
- The auth token hook is a per-request `HeaderProvider` callback, so a token
  refreshed by the auth loop is always picked up.

## Spike questions

| #   | Question                                                    | Answer                                                                                                                                                                                                                                                     |
| --- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Streaming uploads (`Stream<Uint8List>` body, no buffering)? | **Yes.** Generated via `http.StreamedRequest`; bytes flow source→socket. Proven in `test` (TUS `uploadChunk`). Off-the-shelf generators cannot do this.                                                                                                    |
| 2   | Streaming responses?                                        | **Yes.** Octet-stream responses return `StreamedApiResponse` wrapping `response.stream`; caller receives events incrementally. Proven (Functions `invokeFunctionGet`).                                                                                     |
| 3   | Multipart with a streaming file part?                       | **Yes.** Generated `http.MultipartFile(field, stream, length)`. Proven (`uploadObject`).                                                                                                                                                                   |
| 4   | Middleware/interceptor for runtime auth headers?            | **Yes.** `HeaderProvider` runs before every request; proven with a token that changes between calls.                                                                                                                                                       |
| 5   | Auth flows generatable?                                     | **Partly.** Auth isn't in the shared models yet. The HTTP operations (sign-in/up, token refresh, OTP, admin) are plain JSON and would generate cleanly once added. The session loop (refresh timer, storage, `onAuthStateChange`) stays hand-written.      |
| 6   | PostgREST query builder?                                    | **No.** The dynamic query string (`.select()`, `.eq()`, `.order()`) can't be modelled in Smithy/OpenAPI. Codegen could at most supply a generic request executor; the builder and row types stay hand-written. Recommend keeping PostgREST out of codegen. |
| 7   | Web compatibility (no `dart:io`)?                           | **Yes.** Only `http` is used, no conditional imports. Note: streaming *uploads* on Web depend on the HTTP client (`BrowserClient` buffers, `fetch_client` streams), the same caveat that already applies to the hand-written SDK.                          |
| 8   | `build_runner` required?                                    | **No.** `dart run bin/generate.dart`; output is committed and reviewable. This is the decisive advantage over `dart-dio`.                                                                                                                                  |
| 9   | Effort to build an emitter?                                 | **Low.** One ~500-line file generated idiomatic clients for both services.                                                                                                                                                                                 |
| 10  | Model gaps found                                            | See below.                                                                                                                                                                                                                                                 |

## Model gaps found (for supabase/sdk#51)

- **Functions output should be `@streaming`.** It's currently a plain `Blob`
  (OpenAPI `format: byte`). This emitter already treats `application/octet-stream`
  responses as streams, but marking the output `@streaming` makes the intent
  explicit and matches the TUS `@streaming` input.
- **Functions dynamic query params** (limitation #5 in the model README) still
  need per-SDK middleware URL-rewriting; unchanged by this spike.
- **Single-member outputs** (`ListBucketsResponseContent { items }`) generate a
  wrapper object. The facade layer unwraps it (`listBuckets().items`); acceptable,
  but a codegen convention to unwrap single-member structures would be nicer.
- **`Long`/`Integer` both collapse to OpenAPI `number` → Dart `num`.** Works for
  JSON, but `int` would read better for offsets/sizes. Not a blocker.

## Not covered (out of scope, matching Swift spike)

- Auth and PostgREST models don't exist in `sdk#51` yet.
- Realtime (WebSocket) is incompatible with REST codegen, stays hand-written.
- Wiring the generated clients into the real `storage_client` /
  `functions_client` packages (the Swift PR did this incrementally; deferred
  here to keep the spike self-contained).
