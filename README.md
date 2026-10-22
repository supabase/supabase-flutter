<br />
<p align="center">
  <a href="https://supabase.com">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/supabase-logo-wordmark--dark.svg">
      <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/supabase-logo-wordmark--light.svg">
      <img alt="Supabase Logo" width="300" src="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/logo-preview.jpg">
    </picture>
  </a>

  <h1 align="center">Supabase Flutter</h1>

  <p align="center">
    Flutter client library for <a href="https://supabase.com">Supabase</a>.
  </p>

  <p align="center">
    <a href="https://supabase.com/docs/guides/with-flutter">Guides</a>
    ·
    <a href="https://supabase.com/docs/reference/dart/introduction">Reference Docs</a>
    ·
    <a href="https://github.com/supabase/supabase-flutter/blob/main/MIGRATION.md">Migration Guides</a>
  </p>
</p>

<div align="center">

[![Build](https://github.com/supabase/supabase-flutter/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/supabase/supabase-flutter/actions/workflows/test.yml?query=branch%3Amain)
[![Package](https://img.shields.io/pub/v/supabase_flutter.svg)](https://pub.dev/packages/supabase_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](#license)

</div>

This repository holds the Supabase client libraries for Dart and Flutter.
This README describes v3. Most Supabase Dart examples published elsewhere are
v2 code, which no longer compiles. To upgrade a v2 project, follow
[MIGRATION.md](MIGRATION.md).

## Which package to use

| Package                                                           | Use it for                                                |
| ----------------------------------------------------------------- | --------------------------------------------------------- |
| [`supabase_flutter`](packages/supabase_flutter)                   | Flutter apps. Start here.                                 |
| [`supabase`](packages/supabase)                                   | Dart without Flutter: servers and command line tools      |
| [`supabase_typegen`](packages/supabase_typegen)                   | Generating the typed database schema, as a dev dependency |
| [`supabase_test`](packages/supabase_test)                         | Testing code that uses Supabase, as a dev dependency      |
| [`supabase_flutter_web_auth`](packages/supabase_flutter_web_auth) | OAuth and SSO sign in through an in-app browser session   |

`supabase_flutter` and `supabase` bring in the service clients, which you do
not add yourself: [`postgrest`](packages/postgrest),
[`supabase_auth`](packages/supabase_auth),
[`supabase_realtime`](packages/supabase_realtime),
[`supabase_storage`](packages/supabase_storage),
[`supabase_functions`](packages/supabase_functions) and
[`iceberg`](packages/iceberg).

## Quick start

Add the package and the schema generator:

```sh
flutter pub add supabase_flutter
flutter pub add dev:supabase_typegen
```

Generate the typed schema of your database with the
[Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started),
version 2.122.0 or newer:

```sh
supabase gen types --lang dart --local > lib/supabase_schema.g.dart
```

Initialize Supabase once, then query through the generated types, imported
from `supabase_schema.g.dart`:

```dart file
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    publishableKey: 'your-publishable-key',
  );
  runApp(const MaterialApp(home: Placeholder()));
}

Future<List<BooksRow>> booksInPrint() {
  return Supabase.instance.client
      .table(Books.table)
      .select()
      .where(Books.inPrint.isTrue())
      .order(Books.title);
}
```

The [`supabase_flutter` README](packages/supabase_flutter/README.md) walks
through every part of the API.

## Using an AI coding agent

`supabase_flutter`, `supabase`, `supabase_typegen` and `supabase_test` ship
[package skills](https://dart.dev/ai/package-skills), instructions that teach
coding agents such as Claude Code, Cursor, Gemini or Copilot the v3 API.
Agents trained on v2 examples otherwise tend to write code that does not
compile. Install the skills of every package you use, with `supabase` in
place of `supabase_flutter` in a Dart project without Flutter:

```sh
dart run skills@ get -p supabase_flutter
dart run skills@ get -p supabase_typegen
dart run skills@ get -p supabase_test
```

Run the commands again after upgrading the packages to update the skills.

## Testing your app

[`supabase_test`](packages/supabase_test) runs your tests against a real
`SupabaseClient` whose HTTP requests are answered by stubs and whose realtime
socket runs in memory, so no running stack is needed:

```sh
dart pub add dev:supabase_test
```

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

final books = await supabase.table(Books.table).selectOnly([
  Books.id,
  Books.title,
]);

expect(books.single.read(Books.title), 'Dune');
```

See the [supabase_test README](packages/supabase_test/README.md) for the
full guide: stubbing database, rpc, edge function and auth endpoints,
asserting on recorded requests, running tests as a signed-in user, and wiring
`Supabase.initialize` in Flutter widget tests.

## Run locally

This repository is a monorepo powered by [Melos](https://melos.invertase.dev/).
All packages are in the `packages` directory.

To use a local checkout in an app:

- Clone this repository.
- Install Melos if you have not already: `dart pub global activate melos`.
- Run `melos bootstrap`, or `melos bs`, at the root of the clone to install
  the dependencies.
- Point the dependency in your `pubspec.yaml` at the local package:

  ```yaml
  supabase_flutter:
    path: <your-path-to-the-local-supabase-flutter-repo>/packages/supabase_flutter
  ```

## Testing this repo

The tests for the packages `postgrest`, `supabase_auth`, `supabase_realtime` and `supabase_storage` run against a
local Supabase stack. To run these tests locally you need `docker` and the
[Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) installed.

The single configuration for the stack lives in the `supabase` directory at the repository root.
Start it with:

```bash
supabase start
```

Run the Dart tests within the package directory in `packages/<package>` with the following command.
The `-j 1` flag runs the tests not concurrently, which works better since the tests run against the
same services.

```bash
dart test -j 1
```

To stop the stack run the following command from the repository root:

```bash
supabase stop
```

## Contributing

- Fork the repo on [GitHub](https://github.com/supabase/supabase-flutter)
- Clone the project to your own machine
- Commit changes to your own branch
- Push your work back up to your fork
- Submit a Pull request so that we can review your changes and merge

## License

This repo is licensed under MIT.

## Resources

- [Quickstart: Flutter](https://supabase.com/docs/guides/with-flutter)
- [Flutter Tutorial: building a Flutter chat app](https://supabase.com/blog/flutter-tutorial-building-a-chat-app)
- [Flutter Tutorial - Part 2: Authentication and Authorization with RLS](https://supabase.com/blog/flutter-authentication-and-authorization-with-rls)
