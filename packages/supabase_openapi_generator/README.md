# supabase_openapi_generator

Generates idiomatic Dart HTTP clients for Supabase services from OpenAPI 3.0
specifications. The generated clients are built on the `http` package, need no
`build_runner`, and run unchanged on mobile, desktop, web and WASM.

The emitter turns an OpenAPI document into:

- immutable model classes (`final` fields, named constructor, `fromJson`/`toJson`,
  snake_case wire keys mapped to camelCase Dart fields), and
- a client class with one typed method per operation.

Supported transport features:

- **Streaming uploads** via `Stream<List<int>>` request bodies, never buffered
  into memory.
- **Streaming responses** handed back as a live byte stream.
- **Multipart** uploads with a streaming file part.
- **Per-request header injection** for runtime values such as auth tokens.
- **Percent-encoded path parameters** so object keys with reserved characters
  address the correct resource.

## Layout

```
supabase_openapi_generator/
  openapi/                     # OpenAPI 3.0 input documents
  bin/generate.dart            # the emitter
  lib/
    src/runtime.dart           # transport: ApiClient, streaming, errors
    src/generated/*.g.dart     # generated clients (checked in)
```

## Generating

Point the emitter at the OpenAPI documents in `openapi/` and run it. Output is
written to `lib/src/generated/` and formatted automatically.

```bash
dart pub get
dart run bin/generate.dart
```

To generate from different documents or to different targets, edit the
`_generate(...)` calls in `bin/generate.dart`.

## Using a generated client

Construct an `ApiClient` with the base URL and, optionally, an `httpClient`,
default headers, and a `headerProvider` that supplies runtime headers before
every request:

```dart
final client = ApiClient(
  baseUrl: 'https://<project>.supabase.co/storage/v1',
  defaultHeaders: {'apikey': anonKey},
  headerProvider: () => {'Authorization': 'Bearer ${session.accessToken}'},
);

final storage = StorageApi(client);

// JSON operation.
final buckets = await storage.listBuckets();

// Streaming upload (bytes flow straight from the source to the socket).
await storage.uploadChunk(
  uploadId: uploadId,
  tusResumable: '1.0.0',
  uploadOffset: 0,
  body: file.openRead(),
  contentLength: length,
);
```

Non-2xx responses throw `ApiException` with the decoded error body.
Octet-stream responses return a `StreamedApiResponse` exposing the live stream.
