---
name: supabase-typegen-generate
description: >-
  Generates the typed Dart schema (row, insert and update types, column
  constants, enums and typed rpc methods) for a Supabase database with
  `supabase gen types --lang dart`, and keeps it in sync with the database.
  Use when setting up typed queries with table(), after changing a database
  migration, when a table, column or function is missing from the generated
  file, or when the generated file fails to analyze.
---

# Generating the typed Supabase schema

The `supabase_typegen` package turns a Supabase database schema into the Dart
types that `client.table()` and the typed `client.rpc` methods use. It is
never run by hand: the Supabase CLI introspects the database and runs
`dart run supabase_typegen --output -` in the current directory with the
schema on stdin, and the generated code arrives on stdout.

## Rules

- Generate with the Supabase CLI, version 2.122.0 or newer. Check with
  `supabase --version`, or `npx supabase --version` when the project pins the
  CLI in `package.json`.
- Never edit the generated file. Change the database and regenerate instead.
- Regenerate after every database migration, before writing code against the
  new schema.
- Commit the generated file, so the app builds without a database.
- Run the command from the directory of the app's `pubspec.yaml`. The CLI
  finds the `supabase/` folder in that directory or any parent, and runs the
  generator where it was started.

## Setup

```sh
dart pub add dev:supabase_typegen
```

Use `flutter pub add` in a Flutter app. The generator must be a dev dependency
of the package the file is written into, since the CLI runs it with
`dart run` there.

## Generating

Pick the database to read from:

| Source                                                               | Command                                                                          |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| Local stack from the `supabase/` migrations (after `supabase start`) | `supabase gen types --lang dart --local > lib/supabase_schema.g.dart`            |
| The project linked with `supabase link`                              | `supabase gen types --lang dart --linked > lib/supabase_schema.g.dart`           |
| Any hosted project                                                   | `supabase gen types --lang dart --project-id <ref> > lib/supabase_schema.g.dart` |

Prefer `--local` when the project keeps its schema as migrations, so the SQL
in `supabase/migrations` stays the source of truth. `--local` needs Docker and
a running stack.

Without `--schema`, the CLI generates `public` plus the schemas listed in
`api.schemas` of `supabase/config.toml`. Pass `--schema` once per schema to
choose them yourself:

```sh
supabase gen types --lang dart --local --schema public --schema inventory > lib/supabase_schema.g.dart
```

Only schemas exposed through the Data API can be queried at runtime. A table
in a schema other than `public` carries the schema as a prefix,
`inventory.books` becomes `InventoryBooks`, and its table definition carries
the schema, so no `.schema()` call is needed.

After generating, analyze the file, with `flutter analyze` in a Flutter app.
It must be clean:

```sh
dart analyze lib/supabase_schema.g.dart
```

The file is already formatted for the project's language version, so
`dart format` leaves it unchanged.

## Checking in CI

Fail a CI job when someone changed a migration without regenerating the file:

```sh
supabase start
supabase gen types --lang dart --local --dart-set-exit-if-changed
```

It writes nothing, and exits with an error naming the file and the first
declaration that differs when the file is out of date or missing. Add
`--dart-output <path>` when the file is not at `lib/supabase_schema.g.dart`.
Do not redirect stdout into the file in this mode. When the check fails,
regenerate the file and commit it.

## What the file contains

For a table `books` in `public`:

| Generated                          | Use                                                                                       |
| ---------------------------------- | ----------------------------------------------------------------------------------------- |
| `BooksRow`                         | The row type returned by `select()`, with one typed getter per column                     |
| `BooksInsert`                      | The only value `insert()` and `upsert()` accept; required columns are required parameters |
| `BooksUpdate`                      | The only value `update()` accepts, plus `set…ToNull()` for nullable columns               |
| `Books.table`                      | The table definition passed to `client.table()`                                           |
| `Books.title`, `Books.authorId`, … | Column constants for filters, orderings and `selectOnly`                                  |
| `Books.authors`                    | A relation constant per foreign key, for embedding                                        |
| `Mood`                             | A Dart enum per Postgres enum                                                             |
| `client.rpc.bookById(…)`           | A typed method per function PostgREST exposes                                             |

```dart
final List<BooksRow> books = await supabase
    .table(Books.table)
    .select()
    .where(Books.mood.eq(Mood.happy));

final BooksRow? book = await supabase.rpc.bookById(bookId: 1);
```

Read-only relations, such as materialized views, get a row type and column
constants but no insert or update type, so writes to them do not compile.

## When something is missing

- **A table is missing.** Its schema was not generated: add `--schema`, or
  add the schema to `api.schemas`. A table without columns is skipped, and the
  CLI says so in its summary.
- **A relation constant is missing.** Foreign keys into another schema and
  self-referencing foreign keys get no relation, since PostgREST cannot embed
  them. Query those through a second request.
- **A name has a suffix.** A name the generated code itself uses, such as
  `String`, gets `$`.
- **A function has no method.** The generated file has a comment where the
  method would be, explaining why. Call it untyped with
  `supabase.rpc('fn', params: {...})`.
- **A column has an unexpected type.** `numeric` maps to `num`, `date` to
  `PostgresDate`, `interval` to `PostgresInterval`, and array elements are
  assumed non-null. The full list is in the
  [`supabase_typegen` README](https://pub.dev/packages/supabase_typegen).

## Errors

The CLI reports a generator failure as
`failed to generate dart types: dart run supabase_typegen exited with code N: …`,
followed by the generator's own message.

| Symptom                                                                                                 | Fix                                                                             |
| ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `dart run` cannot find `supabase_typegen`                                                               | Add the dev dependency and run `pub get` in the directory the command runs in.  |
| `The project is on Dart X, but the generated code needs Dart Y or newer`                                | Raise the lower bound of `environment.sdk` in `pubspec.yaml`.                   |
| `The database has no schema "x"`                                                                        | Check the schema name, or that the stack has run the migration that creates it. |
| `The project resolves supabase_flutter 2.x, but the generated code needs version 3 of supabase_flutter` | Upgrade the package to version 3 following `MIGRATION.md`, then run `pub get`.  |
| `The document describes no tables, views, enums or functions`                                           | Check the schema names, or that the stack has run the migrations.               |
| `The document has no "rpcFunctions" collection, so no RPC methods are generated`                        | Upgrade the Supabase CLI to the latest release and regenerate.                  |
| `--lang dart` is rejected                                                                               | Upgrade the Supabase CLI to 2.122.0 or newer.                                   |
| `lib/supabase_schema.g.dart is out of date with the database schema`                                    | Regenerate the file and commit it.                                              |
| `--dart-set-exit-if-changed` is rejected                                                                | Upgrade the Supabase CLI to the latest release.                                 |
| `--local` cannot reach the database                                                                     | Run `supabase start` first.                                                     |
