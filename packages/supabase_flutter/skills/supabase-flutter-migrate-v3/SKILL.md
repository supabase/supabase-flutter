---
name: supabase-flutter-migrate-v3
description: >-
  Migrates a Dart or Flutter project from supabase_flutter v2 to v3, including the
  renamed gotrue, realtime_client, storage_client and functions_client
  packages. Generates a typed database schema with the Supabase CLI, applies
  every breaking change from the migration guide, and moves queries from the
  untyped from() API to the typed table() API. Use when the user asks to
  upgrade or migrate Supabase to v3, bumps supabase_flutter to ^3, or hits v3
  breaking changes.
---

# Migrate supabase_flutter from v2 to v3

The full migration guide is in
[references/migration-v2-v3.md](references/migration-v2-v3.md). Its section
headings name the symbol that changed, so search it for the symbol in a
compiler error or in the code you are changing. Every "Before" and "After"
snippet there is authoritative. This file is the order to apply it in and the
checks that make the migration complete.

## Rules

- Follow the steps in order. Do not skip the Supabase CLI check.
- Never write the table definitions by hand. They come from
  `supabase gen types --lang dart`, and the generated file is never edited.
- Every query ends up on the typed `table()` API unless it matches one of the
  exceptions in step 8. Report every exception to the user.
- Keep the behavior of the app. Where v3 changed a default, pin the v2
  behavior explicitly unless the user asks for the new one.
- Do not suppress analyzer errors or warnings to get a clean run. Fix them.
- Ask the user before a choice that changes runtime behavior and is not
  covered here.

## 1. Preflight

1. Read `pubspec.yaml`. Note which of these are dependencies and their
   versions: `supabase_flutter`, `supabase`, `gotrue`, `postgrest`,
   `realtime_client`, `storage_client`, `functions_client`.
2. Run `git status`. If the tree is dirty, ask the user to commit or stash
   first so the migration is one reviewable diff.
3. Run `flutter analyze` and save the output. Issues that exist before the
   migration are the baseline, and step 9 is measured against it.
4. Check for a `supabase/` folder with `config.toml` and `migrations/`. It
   decides the source of the generated types in step 4.

## 2. Supabase CLI 2.122.0 or newer

Dart generation requires Supabase CLI 2.122.0 or newer.

```sh
supabase --version
```

If the project runs the CLI through npm (a `supabase` entry in
`package.json`), check `npx supabase --version` instead.

If the command is missing or prints a version below `2.122.0`, stop and give
the user the command for their platform, then wait until the version check
passes:

| Install method          | Upgrade command                                                        |
| ----------------------- | ---------------------------------------------------------------------- |
| Homebrew (macOS, Linux) | `brew upgrade supabase/tap/supabase`                                   |
| npm                     | `npm install --save-dev supabase@latest`                               |
| Scoop (Windows)         | `scoop update supabase`                                                |
| Not installed           | https://supabase.com/docs/guides/local-development/cli/getting-started |

Do not continue on an older CLI and do not fall back to hand-written types.

## 3. Pin the changed `order()` defaults while still on v2

v3 changed two defaults of `order()` without a compile error. Both pins
below already mean the same thing on v2, so add them before upgrading:

```sh
grep -rnE '\.order\(' lib test bin
```

- A call without `ascending:` sorted descending on v2 and sorts ascending on
  v3. Add `ascending: false`.
- A call that sorts descending (including the ones you just changed) put
  `NULL`s last on v2 and puts them first on v3. When the column is nullable,
  add `nullsFirst: false`.

This applies to `stream().order()` too. The result is that every `order()`
call states its direction and, on a descending sort of a nullable column, its
null placement.

## 4. Dependencies and the typed schema

Once `supabase_typegen` is added, its `supabase-typegen-generate` skill has
the details of the generator, its options and its errors.

1. Update the dependencies. Use the newest 3.x version of each package;
   `flutter pub outdated` lists it, prereleases included.
   - `supabase_flutter` to 3.x.
   - Replace any direct dependency on a renamed package, and its imports:

     | v2                 | v3                   |
     | ------------------ | -------------------- |
     | `gotrue`           | `supabase_auth`      |
     | `realtime_client`  | `supabase_realtime`  |
     | `storage_client`   | `supabase_storage`   |
     | `functions_client` | `supabase_functions` |

     A direct dependency that only duplicates what `supabase_flutter` already
     re-exports can be removed instead.
2. Add the generator: `flutter pub add dev:supabase_typegen`.
3. Run `flutter pub get`.
4. Generate the schema. Pick the source:
   - A `supabase/` folder with migrations: run `supabase start` (needs Docker),
     then `supabase gen types --lang dart --local`.
   - A project linked with `supabase link`: `--linked`.
   - Otherwise ask the user for the project ref and use
     `--project-id <ref>`.

   Ask which schemas the app queries. Pass `--schema` for each schema other
   than `public` that the app uses. Write to `lib/supabase_schema.g.dart`
   unless the project already has a generated-code convention:

   ```sh
   supabase gen types --lang dart --local > lib/supabase_schema.g.dart
   ```
5. Run `flutter analyze lib/supabase_schema.g.dart`. It must be clean. If it is
   not, report the error to the user rather than editing the file.

## 5. Mechanical renames

Apply these across the project before reading compiler errors, since they
remove most of them. The tables are in the reference:

- "The client packages are renamed": imports and the `GoTrue*` type names,
  such as `GoTrueClient` to `AuthClient`.
- "Abbreviations in the public API are spelled out": for example
  `queryParams:` to `queryParameters:` and `opts:` to `options:`.
- "Plural enum names singularized" and "One shared `SortDirection` for every
  sort direction".
- "Every deprecated API is gone": for example `User.confirmedAt` to
  `User.emailConfirmedAt` and `AuthUser` to `User`.
- `Supabase.initialize(anonKey: …)` to `publishableKey: …`, and remove the
  `debug:` argument. If the app wants console logs, add the
  `Logger.root.onRecord` listener from "The SDK no longer prints logs".

## 6. Compiler-driven pass

1. Run `flutter analyze`.
2. For each new error, search the reference for the symbol it names and apply
   the "After" form of that section.
3. Repeat until the only issues left are the baseline from step 1.

The sections that most often apply:

- "Sign-in methods that always issue a session return the `Session`":
  `signInWithPassword()` and others return the `Session` directly.
- "`AuthState` is a sealed class" and
  "`User.appMetadata` is an `AppMetadata` and `userMetadata` is never null".
- "Realtime listener callbacks are now streams": `onPostgresChanges`,
  `onBroadcast` and the connection callbacks.
- "The auth client persists the session itself": `localStorage:` and
  `LocalStorage` subclasses become an `AuthAsyncStorage`.
- "Service exceptions share one base" and "`FunctionException` is sealed".
- "Every client takes one `SupabaseRetryOptions`".
- "Timestamps are `DateTime` instead of `String` or `int`".
- "`rpc` is a getter", "`insert()` and `upsert()` no longer take filters" and
  "The rest client and its builders are stateless".
- "`supabasePersistSessionKey` is gone": keep the old key as `storageKey` only
  if the app wrote sessions under it through a custom storage, otherwise users
  are signed out once.

## 7. Changes the compiler will not catch

Go through every item. For each one, search with the given pattern, read
every match, and fix or confirm it. Keep a list of the sites you could not
decide for the summary in step 9.

| Change (reference section)                                      | Search                                                                            | Action                                                                                                                                                                                                     |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `order()` defaults                                              | `\.order\(`                                                                       | Confirm step 3 covered every call.                                                                                                                                                                         |
| `RealtimeClient.connectionState` is now typed                   | `connectionState`                                                                 | Compare against `SocketState.open` and friends, not strings. Prefer `isConnected`.                                                                                                                         |
| `HttpMethod` is one shared enum                                 | `HttpMethod\.[a-z]+\.index`                                                       | Persist `name` instead of `index`.                                                                                                                                                                         |
| Confirming an email or phone change emits `userUpdated`         | `AuthChangeEvent\.signedIn`                                                       | Handle `userUpdated` where an email or phone change confirmation should be seen.                                                                                                                           |
| `AuthChangeEvent.initialSession` is emitted to every subscriber | `onAuthStateChange`                                                               | Listeners that act on `signedIn` at subscription time must also act on `initialSession`.                                                                                                                   |
| A client without an `asyncStorage` throws when it is created    | `SupabaseClient\(`                                                                | Every directly constructed client passes `AuthClientOptions(asyncStorage: …)`, uses the implicit flow, or uses a third-party `accessToken`.                                                                |
| The retry backoff defaults are the same in every client         | `retryOptions\|SupabaseRetryOptions`                                              | Ask whether the old PostgREST curve matters. If it does, pass the options shown in the reference.                                                                                                          |
| The rest client and its builders are stateless                  | `=\s*await .*\.(insert\|upsert\|update\|delete)\(`                                | A write without `select()` resolves to `void`. Drop the assignment or add `.select()`.                                                                                                                     |
| `userMetadata` is never null                                    | `userMetadata\s*(\?\|==\|!=)`                                                     | Remove the dead null checks.                                                                                                                                                                               |
| `SupabaseClient` builds its own default HTTP client             | `runWithClient`                                                                   | Pass the client as `httpClient:` instead.                                                                                                                                                                  |
| A request that gets no response throws a transport exception    | `on ClientException\|on TimeoutException`                                         | Catch `SupabaseTransportException` around Supabase calls.                                                                                                                                                  |
| A failing `accessToken` callback throws `AccessTokenException`  | `accessToken:` and transport exception catches                                    | Catch `AccessTokenException` where token failures were handled.                                                                                                                                            |
| The request timeout bounds idle time                            | `requestTimeout`                                                                  | Add `.timeout(…)` on the builder where a total deadline was intended.                                                                                                                                      |
| Realtime throws exceptions instead of strings                   | `on String\|toString\(\)\.contains` near `subscribe`, `httpSend`, `track`, `send` | Catch `StateError`, `RealtimeApiException` or `RealtimeTransportException`.                                                                                                                                |
| The session is persisted with `SharedPreferencesAsync`          | `SharedPreferences\.getInstance`                                                  | Migrate the app's own preferences to `SharedPreferencesAsync`, or use the legacy storage from the reference. Widget tests that call `Supabase.initialize` need the `InMemorySharedPreferencesAsync` setup. |

Search `lib`, `test`, `bin` and any other source folders with
`grep -rnE '<pattern>'`.

## 8. Move every query to the typed `table()` API

Follow the reference section "Moving from `from()` to the typed table API".
Convert one table at a time and re-run `flutter analyze` after each.

Naming in the generated file: table `books` in `public` is `Books`,
`BooksRow`, `BooksInsert` and `BooksUpdate`. A table in another schema
carries the schema as a prefix, `inventory.books` is `InventoryBooks`, and
`supabase.schema('inventory').from('books')` becomes
`supabase.table(InventoryBooks.table)`. Columns are camelCase constants on the
table class, `Books.authorId`.

| Untyped                                                | Typed                                                                     |
| ------------------------------------------------------ | ------------------------------------------------------------------------- |
| `.from('books').select()`                              | `.table(Books.table).select()`                                            |
| `.select('id, title')`                                 | `.selectOnly([Books.id, Books.title])`, read with `row.read(Books.title)` |
| `.select('title, authors(name)')`                      | `.selectOnly([Books.title, Books.authors(Authors.name)])`                 |
| `.eq('author_id', 2)`                                  | `.where(Books.authorId.eq(2))`                                            |
| `.or('price.lt.10,in_print.eq.false')`                 | `.where(Books.price.lt(10) \| Books.inPrint.isFalse())`                   |
| `.order('created_at', ascending: false)`               | `.order(Books.createdAt.desc())`                                          |
| `.order('price', ascending: false, nullsFirst: false)` | `.order(Books.price.desc().nullsLast())`                                  |
| `.limit(3, referencedTable: 'books')`                  | `.embedded(Authors.books, (books) => books.limit(3))`                     |
| `.insert({...})`                                       | `.insert(BooksInsert(...))`                                               |
| `.insert([{...}, {...}])`                              | `.insertAll([BooksInsert(...), ...])`                                     |
| `.update({...}).eq('id', 1)`                           | `.update(BooksUpdate(...)).where(Books.id.eq(1))`                         |
| `.update({'price': null})`                             | `.update(BooksUpdate().setPriceToNull())`                                 |
| `.delete().eq('id', 1)`                                | `.delete().where(Books.id.eq(1))`                                         |
| `.delete()` with no filter                             | `.delete().all()`                                                         |
| `.upsert({...}, onConflict: 'name')`                   | `.upsert(AuthorsInsert(...), onConflict: [Authors.name])`                 |
| `.stream(primaryKey: ['id']).eq('author_id', 2)`       | `.stream(primaryKey: [Books.id]).filter(Books.authorId.eq(2))`            |
| `.rpc('search_books', params: {'query': q})`           | `.rpc.searchBooks(query: q)`                                              |

Rules for the conversion:

- Carry the direction pinned in step 3 over: `ascending: false` becomes
  `.desc()`, and `nullsFirst: false` becomes `.nullsLast()`. An `order()` with
  neither stays a plain column, which is ascending. On a typed `stream()`,
  `order()` takes the column and keeps `ascending: false` instead.
- A typed `update()` or `delete()` sends nothing until it has `.where(…)` or
  `.all()`. A bare `await` of one compiles and silently does nothing, and the
  analyzer reports it as an `unused_result` warning. Fix every one of them.
- Passing `null` to an `Insert` or `Update` parameter leaves the column out.
  Use the generated `set…ToNull()` method to write SQL `NULL`.
- Replace `row['title'] as String` with `row.title` wherever the rows are
  consumed. A model class that only mirrors a table is replaced by the
  generated row type. A model that adds behavior is built from the row
  getters, not from `toJson()`.
- An operator with no typed method uses `Books.title.raw('eq.Dune')`. A filter
  on a JSON path uses `PostgrestFilter.raw('metadata->>edition', 'eq.first')`.

`from()` and the untyped `rpc('fn', params: …)` remain only for:

- a table, view or function missing from the generated file because its
  schema was not generated or is not exposed through the Data API,
- a table name computed at runtime,
- a function the generator gives no method, which it explains in a comment in
  the generated file.

## 9. Verify and report

1. `flutter analyze` shows nothing beyond the baseline from step 1.
2. Run `dart format` on every file you changed. Do not format
   `lib/supabase_schema.g.dart`, which is already formatted.
3. Run `flutter test`. Fix failures the migration caused and report the rest.
4. Give the user a short summary:
   - the dependency changes and the generated schema file and command,
   - every site from step 7 that needs a human decision,
   - every remaining `from()` or untyped `rpc()` call and its reason,
   - that the schema must be regenerated with the same command after every
     database migration.
