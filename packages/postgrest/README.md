<br />
<p align="center">
  <a href="https://supabase.com">
    <img alt="Supabase Logo" width="300" src="https://raw.githubusercontent.com/supabase/supabase/master/packages/common/assets/images/logo-preview.jpg">
  </a>

  <h1 align="center">postgrest</h1>

  <p align="center">
    Dart client library for <a href="https://postgrest.org">PostgREST</a>, providing an ORM-like
    interface to the <a href="https://supabase.com/docs/guides/database">Supabase database</a>.
  </p>

  <p align="center">
    <a href="https://supabase.com/docs/guides/database">Guides</a>
    ·
    <a href="https://supabase.com/docs/reference/dart/select">Reference Docs</a>
  </p>
</p>

<div align="center">

[![pub package](https://img.shields.io/pub/v/postgrest.svg)](https://pub.dev/packages/postgrest)
[![pub test](https://github.com/supabase/supabase-flutter/workflows/Test/badge.svg)](https://github.com/supabase/supabase-flutter/actions?query=workflow%3ATest)

</div>

`postgrest` is the database client of the Supabase Dart and Flutter SDKs. In
an app, use it through [`supabase_flutter`](https://pub.dev/packages/supabase_flutter)
or [`supabase`](https://pub.dev/packages/supabase), whose clients expose it as
`supabase.table(…)`, `supabase.from(…)` and `supabase.rpc`. Depend on
`postgrest` directly only to talk to a PostgREST server without the rest of
Supabase.

## Usage

Queries are typed by a Dart file that
[`supabase_typegen`](https://pub.dev/packages/supabase_typegen) generates from
the database schema, with a row type per table (`BooksRow`), the insert and
update values that writes accept (`BooksInsert`, `BooksUpdate`), and a class
holding the table definition and one constant per column (`Books`):

```sh
dart pub add dev:supabase_typegen
supabase gen types --lang dart --local > lib/supabase_schema.g.dart
```

Import the generated `supabase_schema.g.dart` and pass the table definition
to `table()`. Filters are methods on the column constants, so the compiler
checks every column name and value:

```dart file
import 'package:my_app/supabase_schema.g.dart';
import 'package:postgrest/postgrest.dart';

Future<void> main() async {
  final client = PostgrestClient(
    'https://your-project.supabase.co/rest/v1',
    headers: {'apikey': 'your-publishable-key'},
  );

  final List<BooksRow> books = await client
      .table(Books.table)
      .select()
      .where(Books.inPrint.isTrue() & Books.price.lt(10))
      .order(Books.title)
      .limit(20);

  await client
      .table(Books.table)
      .insert(BooksInsert(authorId: 2, title: 'Dune'));

  // A typed update() or delete() sends nothing until where() or all().
  await client
      .table(Books.table)
      .update(BooksUpdate(inPrint: false))
      .where(Books.id.eq(1));

  final BooksRow? book = await client.rpc.bookById(bookId: 1);
}
```

`from('books')` with `Map<String, dynamic>` rows and
`rpc('fn', params: {…})` remain as the untyped fallback for tables and
functions that are not in the generated file.

## Supabase Service Compatibility

`postgrest` only guarantees compatibility with the [latest PostgREST
release](https://github.com/PostgREST/postgrest/releases). Older PostgREST
releases are supported on a best-effort basis, but compatibility is not
guaranteed.

If you self-host PostgREST, we recommend upgrading to the latest release when
upgrading this SDK.

## Docs

The docs can be found on the official Supabase website.

- [Dart reference](https://supabase.com/docs/reference/dart/select)
- [Supabase API guide](https://supabase.com/docs/guides/api)

## License

This repo is licensed under MIT.

## Credits

- https://github.com/supabase/postgrest-js - ported from postgrest-js library
