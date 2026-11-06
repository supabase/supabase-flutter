---
name: supabase-typegen-generate
description: >-
  Generates the typed Dart schema (row, insert and update types, column
  constants, enums and typed rpc methods) for a Supabase database with
  `supabase gen types --lang dart`, and keeps it in sync with the database.
  Use when setting up typed queries with table(), after any change to the
  database schema, after upgrading supabase_typegen or the Supabase CLI, when
  a table, column or function is missing from the generated file, or when the
  generated file fails to analyze.
---

# Generating the typed Supabase schema

The `supabase_typegen` package turns a Supabase database schema into the Dart
types that `client.table()` and the typed `client.rpc` methods use. It is
never run by hand: the Supabase CLI introspects the database and runs
`dart run supabase_typegen --output -` in the current directory with the
schema on stdin, and the generated code arrives on stdout.

## Rules

- Generate with the Supabase CLI, version 3.0.0 or newer. Check with
  `supabase --version`, or `npx supabase --version` when the project pins the
  CLI in `package.json`.
- Never edit the generated file. Change the database and regenerate instead.
- Regenerate after every change to the database schema, before writing code
  against it. That includes a new or edited migration, a migration pulled
  from another branch, and a change made in the dashboard or with SQL against
  a hosted project. Changes to tables, views, columns, enums, functions and
  the exposed schemas all change the generated file.
- Generate from the database that has the change. A change made on a hosted
  project is not in the local stack, so generate it with `--remote` pointing
  at that project.
- When generating from the local stack, apply new migrations to it first with
  `supabase migration up`. The command reads the running database, not the
  files in `supabase/migrations`, so a stack that has not run a migration
  generates the old schema without an error.
- `supabase migration up` skips migrations the stack has already applied, so
  it does not pick up an edit to one of them. Rebuild the stack with
  `supabase db reset` instead. A reset drops every row that the migrations
  and `seed.sql` do not recreate, so ask the user before running it.
- Regenerate after upgrading `supabase_typegen` or the Supabase CLI, since
  the generated code can change between versions.
- Commit the generated file, so the app builds without a database.
- Run the command from the directory of the app's `pubspec.yaml`, since the
  CLI runs the generator where it was started. The CLI looks for the
  `supabase/` folder in that directory and its parents only. When the folder
  is elsewhere, such as in a sibling directory of the app, pass the directory
  that contains it with `--workdir`.

## Setup

```sh
dart pub add dev:supabase_typegen
```

Use `flutter pub add` in a Flutter app. The generator must be a dev dependency
of the package the file is written into, since the CLI runs it with
`dart run` there.

## Generating

Pick the database to read from:

| Source                                                               | Command                                                                         |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Local stack from the `supabase/` migrations (after `supabase start`) | `supabase gen types --lang dart > lib/supabase_schema.g.dart`                   |
| Local stack whose `supabase/` folder is not in a parent directory    | `supabase gen types --lang dart --workdir <dir> > lib/supabase_schema.g.dart`   |
| The project linked with `supabase link`                              | `supabase gen types --lang dart --remote > lib/supabase_schema.g.dart`          |
| Any hosted project                                                   | `supabase gen types --lang dart --remote=<ref> > lib/supabase_schema.g.dart`    |
| Any Postgres database, by connection string                          | `supabase gen types --lang dart --remote=<db-url> > lib/supabase_schema.g.dart` |

Prefer the local stack when the project keeps its schema as migrations, so the
SQL in `supabase/migrations` stays the source of truth. It needs Docker and a
running stack.

`<dir>` is the directory that contains `supabase/`, not the `supabase/` folder
itself. Pass the same `--workdir` to `supabase start`, `supabase migration up`
and `supabase db reset`, or they act on a different stack than the one the
types are generated from. `<db-url>` is a `postgresql://` URL with the password in
it, such as `postgresql://postgres:postgres@127.0.0.1:54322/postgres` for a
local stack on the default ports. Quote it, since an `&` in its query string
splits the command. For any other database, ask the user to put the URL in an
environment variable and pass `--remote="$DATABASE_URL"`, so the password is
not written into the command you run or printed in its output. The shell
still expands it into the arguments of the `supabase` process. The `--local`
and `--db-url` flags of older CLI versions are deprecated: the local stack is
the default, and `--remote=<db-url>` replaces `--db-url`.

Without `--schema`, the CLI generates `public` plus the schemas listed in
`api.schemas` of `supabase/config.toml`. Pass `--schema` once per schema to
choose them yourself:

```sh
supabase gen types --lang dart --schema public --schema inventory > lib/supabase_schema.g.dart
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

| Symptom                                                                                                 | Fix                                                                              |
| ------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `dart run` cannot find `supabase_typegen`                                                               | Add the dev dependency and run `pub get` in the directory the command runs in.   |
| `The project is on Dart X, but the generated code needs Dart Y or newer`                                | Raise the lower bound of `environment.sdk` in `pubspec.yaml`.                    |
| `The database has no schema "x"`                                                                        | Check the schema name, or that the stack has run the migration that creates it.  |
| `The project resolves supabase_flutter 2.x, but the generated code needs version 3 of supabase_flutter` | Upgrade the package to version 3 following `MIGRATION.md`, then run `pub get`.   |
| `The document describes no tables, views, enums or functions`                                           | Check the schema names, or that the stack has run the migrations.                |
| `The document has no "rpcFunctions" collection, so no RPC methods are generated`                        | Upgrade the Supabase CLI to the latest release and regenerate.                   |
| `--lang dart` is rejected                                                                               | Upgrade the Supabase CLI to 3.0.0 or newer.                                      |
| The CLI cannot reach the local database                                                                 | Run `supabase start` first, with the same `--workdir` as the generation command. |
