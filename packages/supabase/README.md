<br />
<p align="center">
  <a href="https://supabase.com">
    <img alt="Supabase Logo" width="300" src="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/logo-preview.jpg">
  </a>

  <h1 align="center">supabase</h1>

  <p align="center">
    Dart client library for <a href="https://supabase.com">Supabase</a>, for use in non-Flutter Dart environments.
  </p>

  <p align="center">
    <a href="https://supabase.com/docs">Guides</a>
    ·
    <a href="https://supabase.com/docs/reference/dart/introduction">Reference Docs</a>
  </p>
</p>

<div align="center">

[![pub package](https://img.shields.io/pub/v/supabase.svg)](https://pub.dev/packages/supabase)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

</div>

`supabase` is the Supabase client for Dart code that does not run in Flutter,
such as a server or a command line tool. It covers typed database queries,
auth, realtime, storage and edge functions.

> [!IMPORTANT]
> For a Flutter app, use [`supabase_flutter`](https://pub.dev/packages/supabase_flutter)
> instead. It wraps this package and adds session persistence, deep links and
> the app lifecycle.

This README describes v3. Most Supabase Dart examples published elsewhere are
v2 code, which no longer compiles. To upgrade a v2 project, follow
[MIGRATION.md](https://github.com/supabase/supabase-flutter/blob/main/MIGRATION.md).

## Using an AI coding agent

`supabase` ships [package skills](https://dart.dev/ai/package-skills),
instructions that teach coding agents such as Claude Code, Cursor, Gemini or
Copilot the current API. Agents trained on v2 examples otherwise tend to write
code that does not compile against v3. The skills for generating the schema
and for testing ship with the dev dependencies they are about. Install the
skills of every package you use:

```sh
dart run skills@ get -p supabase
dart run skills@ get -p supabase_typegen
dart run skills@ get -p supabase_test
```

| Skill                       | Package            | Covers                                                               |
| --------------------------- | ------------------ | -------------------------------------------------------------------- |
| `supabase-idioms`           | `supabase`         | Writing or reviewing any code that uses the client                   |
| `supabase-realtime`         | `supabase`         | Live lists with `stream()`, `onTableChanges`, broadcast and presence |
| `supabase-migrate-v3`       | `supabase`         | Upgrading a project from v2 to v3                                    |
| `supabase-typegen-generate` | `supabase_typegen` | Generating the typed database schema and keeping it in sync          |
| `supabase-test-testing`     | `supabase_test`    | Unit tests with `supabase_test`                                      |

Run the commands again after upgrading the packages to update the skills.
Commit the installed skills together with `.config/dart_skills/` so everyone
working on the project gets the same version.

## Getting started

### 1. Add the package

```sh
dart pub add supabase
```

### 2. Create the client

Find the URL and the publishable key of your project in the dashboard under
**Project Settings > API Keys**. Create one client when the program starts
and reuse it, as described in [Server-side usage](#server-side-usage).

```dart file
import 'package:supabase/supabase.dart';

final supabase = SupabaseClient(
  'https://your-project.supabase.co',
  'your-publishable-key',
  authOptions: AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage()),
);
```

A client without an `asyncStorage` throws when it is created, since the
default PKCE flow keeps its code verifiers there. `MemoryAuthAsyncStorage`
keeps them, and the session, in memory for as long as the process runs.

### 3. Generate the typed schema

Queries are typed by a Dart file generated from your database schema. It
holds a row type per table, `BooksRow` for a `books` table, the
`BooksInsert` and `BooksUpdate` values that writes accept, and a `Books`
class with the table definition and one constant per column. Generate it with
the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started),
version 2.122.0 or newer, from the directory of your `pubspec.yaml`:

```sh
dart pub add dev:supabase_typegen
supabase gen types --lang dart --local > lib/supabase_schema.g.dart
```

`--local` reads the schema of the stack started with `supabase start`. Use
`--linked` for the project linked with `supabase link`, or
`--project-id <ref>` for any hosted project. Never edit the generated file:
regenerate it after every database migration and commit it. The
[`supabase_typegen` README](https://pub.dev/packages/supabase_typegen) lists
everything it generates.

### 4. Query

```dart
final List<BooksRow> books = await supabase
    .table(Books.table)
    .select()
    .where(Books.inPrint.isTrue() & Books.price.lt(10))
    .order(Books.title)
    .limit(20);

await supabase
    .table(Books.table)
    .insert(BooksInsert(authorId: 2, title: 'Dune'));

await supabase
    .table(Books.table)
    .update(BooksUpdate(inPrint: false))
    .where(Books.id.eq(1));

final BooksRow? book = await supabase.rpc.bookById(bookId: 1);
```

The [`supabase_flutter` README](https://github.com/supabase/supabase-flutter/tree/main/packages/supabase_flutter#database)
shows the rest of the API, which is the same in both packages: embedding
related rows, realtime, auth, storage, edge functions and errors.

## Rules of the v3 API

- Query tables with `table()` and the generated schema. `from()` with
  `Map<String, dynamic>` rows is only the fallback for a table that is not in
  the generated file.
- Realtime events arrive on streams. No method takes a `callback:`.
- A typed `update()` or `delete()` sends nothing until `.where(…)` or
  `.all()` is called on it.
- Catch the `SupabaseException` hierarchy, never `ClientException`,
  `TimeoutException` or `String`.
- Create one `SupabaseClient` per process, not one per request.

## Docs

- [Dart reference](https://supabase.com/docs/reference/dart/introduction)
- [Supabase docs](https://supabase.com/docs)

## Server-side usage

Create one `SupabaseClient` when the process starts and reuse it for as long as the process lives.
The client keeps a pool of HTTP connections, and a request on a warm connection skips the TCP
handshake and, over HTTPS, the TLS handshake, which on a server talking to a remote Supabase
project take longer than the request itself. A client created per request throws that pool away
every time.

To act on behalf of the user of an incoming request, keep the shared client and pass the access
token of that request as the `Authorization` header of the call. The client only adds its own
`Authorization` header when the request has none:

```dart file
import 'package:my_app/supabase_schema.g.dart';
import 'package:supabase/supabase.dart';

Future<List<BooksRow>> booksOfUser(
  SupabaseClient supabase,
  String userAccessToken,
) {
  return supabase
      .table(Books.table)
      .select()
      .setHeader('Authorization', 'Bearer $userAccessToken');
}
```

Storage and functions calls accept a header the same way, through `setHeader()` on a bucket and
the `headers` parameter of `invoke()`.

The transport a `SupabaseClient` creates for itself closes a connection that has been unused for
60 seconds, which is below the point where the Supabase gateway closes it from its side. Open
connections keep a Dart program alive until then, so call `dispose()` when the process shuts down.

If you do need more than one `SupabaseClient`, pass the same `http.Client` to each of them so they
share one pool. Disposing a `SupabaseClient` leaves a client you passed in open, so close it
yourself at shutdown. `dart:io` defaults to a 15 second idle timeout, so raise it:

```dart file
import 'dart:io';

import 'package:http/io_client.dart';

final httpClient = IOClient(
  HttpClient()..idleTimeout = const Duration(seconds: 60),
);
```

## Request ids and tracing

The exceptions thrown by the auth, database, storage and functions clients carry the `requestId`
the Supabase gateway assigned to the failed request, which finds it in the logs of your project.
To correlate requests with your own traces, pass `TracePropagationOptions` to `SupabaseClient`.
Both are described, with Sentry and OpenTelemetry recipes, in the
[supabase_flutter README](https://github.com/supabase/supabase-flutter/tree/main/packages/supabase_flutter#request-ids-and-tracing).

## License

This repo is licensed under MIT.

## Credits

- https://github.com/supabase/supabase-js
