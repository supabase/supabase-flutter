# Migration Guides

This document lists the breaking changes between major versions of the Supabase Flutter SDK and
what you need to change in your code.

All packages in this repository are released together for a major version, so a single section
covers `supabase_flutter`, `supabase`, `supabase_auth`, `postgrest`, `supabase_realtime`,
`supabase_storage`, `iceberg` and `supabase_functions`. Every symbol mentioned here is re-exported
from `supabase_flutter`, so the snippets apply whether you depend on the individual package or on
the Flutter one.

## Migrating from v2 to v3

> [!NOTE]
> v3 has not been released yet. This section is updated as breaking changes land on `main`, so
> treat it as the running list rather than the final one.

The guide starts with the package skills, which let an AI agent carry out much of this migration
for you. Then comes the typed table API, the biggest addition in v3, since moving your queries to
it also takes care of several of the database changes further down. After it come
[the changes the compiler will not catch](#changes-the-compiler-will-not-catch), and then every
breaking change grouped by area: [packages and setup](#packages-and-setup),
[database](#database), [auth](#auth), [realtime](#realtime), [storage](#storage),
[errors](#errors), [requests, retries and tokens](#requests-retries-and-tokens),
[shared types](#shared-types) and [testing](#testing).

### Install the package skills

The v3 packages ship [package skills](https://dart.dev/ai/package-skills), instructions for AI
coding agents such as Claude Code, Cursor, Gemini and Copilot. They include skills for migrating
from v2 to v3, and teach the agent the current API, including the typed table API, so it writes v3
code instead of the v2 code it was trained on. Install them from your project directory as the
first step of the upgrade, once `pubspec.yaml` depends on v3:

```sh
dart run skills@ get --all
```

Without `--all` the command lets you pick the skills to install, and `-p supabase_flutter` limits
it to one package. Run it again after every upgrade to update the installed skills, and
`dart run skills@ prune` to remove the skills of packages you no longer depend on. If you commit
the installed skills, commit `.config/dart_skills/` with them; otherwise add both to `.gitignore`.

### Moving from `from()` to the typed table API

v3 adds `table()`, a typed counterpart of `from()` built on definitions that the Supabase CLI
generates from your database schema. Rows come back as generated types instead of
`Map<String, dynamic>`, filters and orderings are checked against the column types at compile time,
and writes only accept the generated insert and update types. We recommend generating the
definitions for your project and using `table()` for every table they cover. `from()` keeps working,
and both can be used on one client, so a codebase can move over one table at a time.

The typed API is marked `@experimental` while it settles. Referencing an experimental type such as
`PostgrestFilter` directly reports `experimental_member_use`, which an
`// ignore_for_file: experimental_member_use` silences; the generated file already carries it.

The examples below use this schema:

```sql
create table authors (
  id bigint generated always as identity primary key,
  name text not null unique
);

create table books (
  id bigint generated always as identity primary key,
  author_id bigint not null references authors (id),
  title text not null,
  in_print boolean not null default true,
  price numeric,
  published_on date,
  created_at timestamptz not null default now()
);
```

#### Generate the table definitions

Generating Dart requires [Supabase CLI](https://supabase.com/docs/guides/cli/getting-started)
2.122.0 or newer; check yours with `supabase --version`. Add `supabase_typegen` as a dev dependency
of your project and generate the types into it. With `--local` the CLI reads the database of the
running local stack, which it builds from the migrations in your `supabase/` directory:

```sh
dart pub add dev:supabase_typegen
supabase gen types --lang dart --local > lib/supabase_schema.g.dart
```

`--linked` and `--project-id` generate from a hosted project instead; see the
[`supabase_typegen` README](https://github.com/supabase/supabase-flutter/blob/main/packages/supabase_typegen/README.md)
for details.

For every table the file holds a row type (`BooksRow`), an insert type (`BooksInsert`), an update
type (`BooksUpdate`), and a class (`Books`) with the table definition and one constant per column
and foreign key. Run the generator again after every migration so the types follow the schema.

#### Reading rows

```dart
// Before
final List<Map<String, dynamic>> books = await supabase
    .from('books')
    .select();
final title = books.first['title'] as String;

// After
final List<BooksRow> books = await supabase.table(Books.table).select();
final String title = books.first.title;
```

`BooksRow` is an extension type over the decoded JSON, so the getters cost nothing over reading the
map, and `toJson()` returns the map when something still needs it. Dates, enums, `bytea` and the
other column types are converted by the getters, so `createdAt` is a `DateTime` and `publishedOn` a
`PostgresDate`.

A table outside the `public` schema carries its schema in the definition, so
`supabase.table(InventoryBooks.table)` replaces `supabase.schema('inventory').from('books')`.

To read some columns only, `selectOnly` replaces the column string of `select()`. The rows are
`PostgrestPartialRow`s, read through the same column constants. Each value comes back with the
type of its column, and reading a column that was not selected throws a `StateError` instead of
returning `null`:

```dart
// Before
final books = await supabase.from('books').select('id, title');
final title = books.first['title'] as String;

// After
final books = await supabase.table(Books.table).selectOnly([
  Books.id,
  Books.title,
]);
final String title = books.first.read(Books.title);
```

#### Filters

Filters are methods on the column constants, passed to `where()`. The value has to match the column
type, so `Books.price.eq('ten')` does not compile, and `isNull()` only exists on nullable columns.

| Before                                 | After                                                   |
| -------------------------------------- | ------------------------------------------------------- |
| `.eq('author_id', 2)`                  | `.where(Books.authorId.eq(2))`                          |
| `.neq('title', 'Dune')`                | `.where(Books.title.neq('Dune'))`                       |
| `.gte('price', 10)`                    | `.where(Books.price.gte(10))`                           |
| `.ilike('title', '%dune%')`            | `.where(Books.title.ilike('%dune%'))`                   |
| `.inFilter('id', [1, 2])`              | `.where(Books.id.inFilter([1, 2]))`                     |
| `.isFilter('published_on', null)`      | `.where(Books.publishedOn.isNull())`                    |
| `.not('published_on', 'is', null)`     | `.where(Books.publishedOn.isNull().not())`              |
| `.or('price.lt.10,in_print.eq.false')` | `.where(Books.price.lt(10) \| Books.inPrint.isFalse())` |

Filters combine with `&` and `|` and negate with `not()`, so a nested `or()` string becomes an
expression the compiler checks. Repeated `where()` calls combine with AND, like repeated filter
calls did:

```dart
// Before
await supabase
    .from('books')
    .select()
    .eq('in_print', true)
    .or('price.lt.10,published_on.is.null');

// After
await supabase
    .table(Books.table)
    .select()
    .where(
      Books.inPrint.isTrue() &
          (Books.price.lt(10) | Books.publishedOn.isNull()),
    );
```

A filter is a value, so one assembled conditionally no longer needs to reassign the builder:

```dart
var filter = Books.inPrint.isTrue();
if (search != null) filter = filter & Books.title.ilike('%$search%');
final books = await supabase.table(Books.table).select().where(filter);
```

A JSON path is built on the column, with `jsonText()` for a key read as text and `jsonObject()`
to go deeper, and filters like any other column:

```dart
// Before
.eq('metadata->>edition', 'first')

// After
.where(Books.metadata.jsonText('edition').eq('first'))
```

For an operator the API has no method for, `raw()` on a column keeps the column checked and takes
the operand as PostgREST spells it, `Books.title.raw('eq.Dune')`. `PostgrestFilter.raw` takes both
sides as strings, for an expression no column constant or JSON path can name.

#### Ordering, pagination and single rows

The direction of an ordering is spelled on the column:

```dart
// Before
await supabase
    .from('books')
    .select()
    .order('created_at', ascending: false)
    .range(0, 9);

// After
await supabase
    .table(Books.table)
    .select()
    .order(Books.createdAt.desc())
    .range(0, 9);
```

Both APIs only send what was asked for, so `.order('price', ascending: false)` matches
`.order(Books.price.desc())` and `.order('price', ascending: false, nullsFirst: false)` matches
`.order(Books.price.desc().nullsLast())`. Repeated `order()` calls append on both APIs.

`limit()` and `range()` take the same arguments as before, apart from `referencedTable`: the rows
of an embed are sorted and limited with `embedded()`, see [embedded selects](#embedded-selects).
`single()` and `maybeSingle()` resolve to the row type:

```dart
// Before
final Map<String, dynamic> book = await supabase
    .from('books')
    .select()
    .eq('id', 1)
    .single();

// After
final BooksRow book = await supabase
    .table(Books.table)
    .select()
    .where(Books.id.eq(1))
    .single();
final BooksRow? maybeBook = await supabase
    .table(Books.table)
    .select()
    .where(Books.id.eq(1))
    .maybeSingle();
```

`count()` keeps both of its shapes. After `select()` it resolves to a `PostgrestResponse` holding
the typed rows and the count; on its own it is a count query that resolves to an `int` and takes
filters like any other request:

```dart
// Before
final PostgrestResponse<List<Map<String, dynamic>>> response = await supabase
    .from('books')
    .select()
    .count(CountOption.exact);
final int inPrint = await supabase.from('books').count().eq('in_print', true);

// After
final PostgrestResponse<List<BooksRow>> response = await supabase
    .table(Books.table)
    .select()
    .count(CountOption.exact);
final int inPrint = await supabase
    .table(Books.table)
    .count()
    .where(Books.inPrint.isTrue());
```

#### Writes

`insert()`, `upsert()` and `update()` take the generated `Insert` and `Update` types instead of
maps. A required column is a required parameter of `BooksInsert`, and a column the database always
generates, such as `id` above, is not a parameter at all:

```dart
// Before
await supabase.from('books').insert({'author_id': 2, 'title': 'Dune'});
await supabase.from('books').insert([
  {'author_id': 2, 'title': 'Dune'},
  {'author_id': 3, 'title': 'Emma'},
]);
await supabase
    .from('books')
    .update({'in_print': false, 'price': null})
    .eq('id', 1);
await supabase.from('books').delete().eq('id', 1);

// After
await supabase
    .table(Books.table)
    .insert(BooksInsert(authorId: 2, title: 'Dune'));
await supabase.table(Books.table).insertAll([
  BooksInsert(authorId: 2, title: 'Dune'),
  BooksInsert(authorId: 3, title: 'Emma'),
]);
await supabase
    .table(Books.table)
    .update(BooksUpdate(inPrint: false).setPriceToNull())
    .where(Books.id.eq(1));
await supabase.table(Books.table).delete().where(Books.id.eq(1));
```

Several rows go through `insertAll()` and `upsertAll()` instead of a list passed to `insert()`.
Passing `null` to a parameter of `BooksInsert` or `BooksUpdate` leaves the column out of the
request, so the database default applies or the value stays unchanged. To write SQL `NULL`, use the
generated `set…ToNull()` methods, which only exist for nullable columns.
A column left out of only some of the rows passed to `insertAll()` or `upsertAll()` also gets its
default, where an untyped `insert()` of a list writes `NULL`. Pass `defaultToNull: true` to write
`NULL` instead.

An `update()` or `delete()` sends nothing until it says which rows it acts on, through `where()`
or, for every row in the table, `all()`; a bare `await` of it compiles but performs no request,
and the analyzer reports it as an `unused_result` warning:

```dart
// Before
await supabase.from('books').delete();

// After
await supabase.table(Books.table).delete().all();
```

`onConflict` of `upsert()` is a list of columns instead of a comma separated string:

```dart
// Before
await supabase.from('authors').upsert({
  'name': 'Frank Herbert',
}, onConflict: 'name');

// After
await supabase
    .table(Authors.table)
    .upsert(AuthorsInsert(name: 'Frank Herbert'), onConflict: [Authors.name]);
```

Writes resolve to `void` on both APIs. A trailing `select()` returns the written rows, typed as the
row type:

```dart
// Before
final Map<String, dynamic> book = await supabase
    .from('books')
    .insert({'author_id': 2, 'title': 'Dune'})
    .select()
    .single();

// After
final BooksRow book = await supabase
    .table(Books.table)
    .insert(BooksInsert(authorId: 2, title: 'Dune'))
    .select()
    .single();
```

#### Embedded selects

Every foreign key between two generated tables of one schema becomes a relation constant on both
sides, named after the table on the other side: `Books.authors` points at the author of a book, and
`Authors.books` at the books of an author. A relation goes into a `selectOnly` list, called with a
column of the other table or with `select()` for several of them, and the embedded rows are read
back through it:

```dart
// Before
final books = await supabase.from('books').select('title, authors(name)');
final authorName = books.first['authors']?['name'] as String?;

final authors = await supabase
    .from('authors')
    .select('name, books(title)')
    .limit(3, referencedTable: 'books');
final titles = [
  for (final book in authors.first['books'] as List) book['title'] as String,
];

// After
final books = await supabase.table(Books.table).selectOnly([
  Books.title,
  Books.authors(Authors.name),
]);
final String? authorName = books.first
    .read(Books.authors)
    ?.read(Authors.name);

final authors = await supabase
    .table(Authors.table)
    .selectOnly([
      Authors.name,
      Authors.books.select([Books.title]),
    ])
    .embedded(Authors.books, (books) => books.limit(3));
final List<String> titles = [
  for (final book in authors.first.read(Authors.books))
    book.read(Books.title),
];
```

A to-one relation reads back as a nullable partial row and a to-many relation as a list of them.

The typed API cannot filter inside an embed yet, and has no `!inner` embed that drops the parent
rows without a match. Keep a query that needs either on `from()`, for example
`.select('title, authors!inner(name)').eq('authors.name', 'Frank Herbert')`.

When two foreign keys point at the same table, the generator adds the constraint hint and an alias,
so each embed comes back under its own key without spelling `authors!books_author_id_fkey` by hand.

`embedded()` replaces `referencedTable` on `order()`, `limit()` and `range()`. Its callback receives
a scope typed against the embedded table, so ordering by a column of another table does not compile,
and a scope can reach an embed nested in it:

```dart
// Before
await supabase
    .from('authors')
    .select('name, books(title, reviews(rating))')
    .order('created_at', referencedTable: 'books', ascending: false)
    .limit(1, referencedTable: 'books')
    .limit(3, referencedTable: 'books.reviews');

// After
await supabase
    .table(Authors.table)
    .selectOnly([
      Authors.name,
      Authors.books.select([
        Books.title,
        Books.reviews.select([Reviews.rating]),
      ]),
    ])
    .embedded(
      Authors.books,
      (books) => books
          .order(Books.createdAt.desc())
          .limit(1)
          .embedded(Books.reviews, (reviews) => reviews.limit(3)),
    );
```

The generated table definition also lists `primaryKey` and `relations`. Neither changes how a
request is sent; they describe the table to code that handles requests itself, such as a plugin
that caches rows and needs to tell them apart, or one that resolves an embed from local data.

#### Realtime streams

`stream()` on `table()` emits lists of the row type and takes the primary key as columns. Its filter
method is named `filter()`, since `Stream.where` already exists, and takes a single operator:

```dart
// Before
supabase
    .from('books')
    .stream(primaryKey: ['id'])
    .eq('author_id', 2)
    .order('created_at', ascending: false)
    .listen((List<Map<String, dynamic>> books) {});

// After
supabase
    .table(Books.table)
    .stream(primaryKey: [Books.id])
    .filter(Books.authorId.eq(2))
    .order(Books.createdAt.desc())
    .listen((List<BooksRow> books) {});
```

A stream filter supports `eq`, `neq`, `lt`, `lte`, `gt`, `gte`, `inFilter`, `like`, `ilike`,
`matchRegex`, `imatchRegex`, `isNull`, `isTrue`, `isFalse` and `isDistinct`, optionally negated
with `not()`. A filter composed with `&` or `|` throws an `ArgumentError`.

`order()` takes the direction on the column instead of an `ascending` argument, like `order()` on
a typed query. It accepts a `PostgrestColumnOrdering`: a stored column, or its `asc()` or `desc()`.
A stream keeps `null` values last in ascending order and first in descending order, so an ordering
with `nullsFirst()` or `nullsLast()`, or one by anything but a stored column, does not compile.

### Changes the compiler will not catch

Most of this guide produces compile errors until you act on it. These do not, so check them
explicitly:

- [`order()` now sorts ascending by default](#order-now-sorts-ascending-by-default)
- [`order()` no longer sends a null placement by default](#order-no-longer-sends-a-null-placement-by-default)
- [`RealtimeClient.connectionState` is now typed](#realtimeclientconnectionstate-is-now-typed)
- [`HttpMethod` is one shared enum](#httpmethod-is-one-shared-enum), where the enum `index` shifted
- [Confirming an email or phone change emits `userUpdated`](#confirming-an-email-or-phone-change-emits-userupdated)
- [A client without an `asyncStorage` keeps pkce verifiers in memory](#a-client-without-an-asyncstorage-keeps-pkce-verifiers-in-memory),
  so a pkce flow that leaves the process needs a persistent storage passed explicitly
- [`AuthChangeEvent.initialSession` is emitted to every subscriber](#authchangeeventinitialsession-is-emitted-to-every-subscriber)
- [`Supabase.initialize` rejects another url or key](#supabaseinitialize-rejects-another-url-or-key),
  and `initializeTestSupabase` throws when an earlier test did not dispose
- [A web callback URL is exchanged after `Supabase.initialize` completes](#a-web-callback-url-is-exchanged-after-supabaseinitialize-completes)
- [The retry backoff defaults are the same in every client](#the-retry-backoff-defaults-are-the-same-in-every-client)
- [`DateTime` filter values carry their offset from UTC](#datetime-filter-values-carry-their-offset-from-utc)
- [The rest client and its builders are stateless](#the-rest-client-and-its-builders-are-stateless),
  where writes without a `select()` now resolve to `void`
- [`User.userMetadata` is never null](#userappmetadata-is-an-appmetadata-and-usermetadata-is-never-null),
  so a null check on it is dead code that the analyzer only warns about
- [`SupabaseClient` builds its own default HTTP client](#supabaseclient-builds-its-own-default-http-client),
  so on `dart:io` platforms a client installed with `runWithClient` is no longer picked up
- [A request that gets no response throws a transport exception](#a-request-that-gets-no-response-throws-a-transport-exception),
  so a catch of `ClientException` or `TimeoutException` around a query or upload no longer matches
- [A failing `accessToken` callback throws `AccessTokenException`](#a-failing-accesstoken-callback-throws-accesstokenexception),
  so a catch of the transport exception no longer matches a token failure
- [The request timeout bounds idle time, not the whole request](#the-request-timeout-bounds-idle-time-not-the-whole-request),
  so a response that keeps arriving can take longer than `requestTimeout`
- [Iceberg catalog options are named and take an `abortSignal`](#iceberg-catalog-options-are-named-and-take-an-abortsignal),
  where a failing catalog configuration request now fails the operation
- [Transforms that sent a different request now throw or narrow](#transforms-that-sent-a-different-request-now-throw-or-narrow),
  where `head()` after a write and a reversed `range()` throw at the call site
- [Edge Function responses decode every JSON type](#edge-function-responses-decode-every-json-type),
  so an empty JSON body is `null` and a check for `""` no longer matches
- [Realtime throws exceptions instead of strings](#realtime-throws-exceptions-instead-of-strings),
  so a catch of `String` or a `toString()` comparison around `subscribe()` or `httpSend()` no
  longer matches
- [Broadcasts no longer fall back to the REST API](#broadcasts-no-longer-fall-back-to-the-rest-api),
  so `sendBroadcastMessage()` on a channel that was never subscribed throws
- [Storage uploads return an `UploadResponse`](#storage-uploads-return-an-uploadresponse), so a
  result stored in `var` or interpolated into a string is no longer the key
- [`exists()` only returns `false` for a missing object](#exists-only-returns-false-for-a-missing-object),
  so a missing bucket or an invalid token throws instead of returning `false`
- [An `Authorization` header passed to `SupabaseClient` reaches the auth client](#an-authorization-header-passed-to-supabaseclient-reaches-the-auth-client)
- [Broadcast data arrives under `payload`](#broadcast-data-arrives-under-payload), so code that
  reads the sent keys from the top of the received message gets `null`
- [A channel name in use returns its channel](#a-channel-name-in-use-returns-its-channel), so a
  second channel with the same name shares the first one instead of replacing it
- [`stream()` keeps running through reconnects](#stream-keeps-running-through-reconnects), so
  `onDone` no longer fires after a failed fetch that a retry can fix

### Packages and setup

#### The client packages are renamed

Four packages are renamed. The old ones are discontinued on pub.dev when v3 ships.

| Before                     | After                        |
| -------------------------- | ---------------------------- |
| `gotrue: ^2.27.1`          | `supabase_auth: ^3.0.0`      |
| `functions_client: ^2.7.1` | `supabase_functions: ^3.0.0` |
| `realtime_client: ^2.13.0` | `supabase_realtime: ^3.0.0`  |
| `storage_client: ^2.8.0`   | `supabase_storage: ^3.0.0`   |

| Before                                           | After                                                |
| ------------------------------------------------ | ---------------------------------------------------- |
| `package:gotrue/gotrue.dart`                     | `package:supabase_auth/supabase_auth.dart`           |
| `package:functions_client/functions_client.dart` | `package:supabase_functions/supabase_functions.dart` |
| `package:realtime_client/realtime_client.dart`   | `package:supabase_realtime/supabase_realtime.dart`   |
| `package:storage_client/storage_client.dart`     | `package:supabase_storage/supabase_storage.dart`     |

If you depend on `supabase_flutter` or `supabase`, your dependencies and imports are unchanged.

Only the auth package renames types. The functions, realtime and storage packages keep every type
name they had:

| Before                                | After                               |
| ------------------------------------- | ----------------------------------- |
| `GoTrueClient`                        | `AuthClient`                        |
| `GoTrueAdminApi`                      | `AuthAdminApi`                      |
| `GoTrueAdminCustomProvidersApi`       | `AuthAdminCustomProvidersApi`       |
| `GoTrueAdminMFAApi`                   | `AuthAdminMFAApi`                   |
| `GoTrueAdminOAuthApi`                 | `AuthAdminOAuthApi`                 |
| `GoTrueAdminPasskeyApi`               | `AuthAdminPasskeyApi`               |
| `GoTrueMFAApi`                        | `AuthMFAApi`                        |
| `GoTrueOAuthApi`                      | `AuthOAuthApi`                      |
| `GoTruePasskeyApi`                    | `AuthPasskeyApi`                    |
| `GotrueAsyncStorage`                  | `AuthAsyncStorage`                  |
| `SharedPreferencesGotrueAsyncStorage` | `SharedPreferencesAuthAsyncStorage` |
| `GoTrueClientSignInProvider`          | `AuthClientSignInProvider`          |
| `GoTrueClientPasskey`                 | `AuthClientPasskey`                 |

The last two are extensions `supabase_flutter` adds to the auth client. You only name them if you
referred to the extension explicitly, for example to hide it in an import.

#### The Iceberg catalog moved to its own package

`IcebergRestCatalog`, the Iceberg exceptions and the table and namespace types now live in
`iceberg`. `supabase_storage` re-exports all of it, so imports through `supabase_storage` or
`supabase_flutter` and `storage.analyticsCatalog()` keep working unchanged. Depend on `iceberg`
directly to use an Iceberg REST Catalog without the rest of Storage.

#### `publishableKey` is required on `Supabase.initialize`

`anonKey` is removed and `publishableKey` is required. A legacy anon key is still a valid value, it
just goes under the new name.

```dart
// Before
await Supabase.initialize(url: url, anonKey: anonKey);

// After
await Supabase.initialize(url: url, publishableKey: anonKey);
```

#### `Supabase.initialize` rejects another url or key

A second call used to return at once, even while the first was still restoring the session, and
ignored its arguments. It now completes with the same instance once that instance is fully
initialized, and throws a `StateError` when its `url` or `publishableKey` differ. Call
`Supabase.instance.dispose()` first to switch to another project.

`initializeTestSupabase` throws a `StateError` too when an earlier test left the instance
initialized, since it would otherwise hand back that test's mocks. Dispose it at the end of every
test, for example with `addTearDown(supabase.dispose)`.

#### `SupabaseClient` builds its own default HTTP client

On `dart:io` platforms a `SupabaseClient` created without an `httpClient` now builds an `IOClient`
that keeps idle connections open for 60 seconds instead of 15. It no longer goes through the
`Client()` factory of `package:http`, so a client installed with `runWithClient` is not picked up
outside the web. Pass the client as `httpClient` instead, which every platform honors:

```dart
// Before
runWithClient(() {
  final supabase = SupabaseClient(supabaseUrl, supabaseKey);
}, () => MockClient(handler));

// After
final supabase = SupabaseClient(
  supabaseUrl,
  supabaseKey,
  authOptions: AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage()),
  httpClient: MockClient(handler),
);
```

A Dart script that does not call `dispose()` on its `SupabaseClient` now waits a minute before
exiting instead of 15 seconds.

#### `realtimeClientOptions` is renamed to `realtimeOptions`

The parameter of `SupabaseClient` and `Supabase.initialize` now matches `postgrestOptions`,
`authOptions`, `storageOptions` and `functionsOptions`.

```dart
// Before
SupabaseClient(url, key, realtimeClientOptions: RealtimeClientOptions(timeout: timeout));

// After
SupabaseClient(url, key, realtimeOptions: RealtimeClientOptions(timeout: timeout));
```

#### The SDK no longer prints logs

`Supabase.initialize` no longer takes a `debug` flag and never prints anything to the console. All
packages still emit their records through [`package:logging`](https://pub.dev/packages/logging)
under the `supabase` logger hierarchy, so instead of `debug: true`, print them yourself:

```dart
Logger.root.onRecord.listen((record) {
  if (record.loggerName.startsWith('supabase.')) {
    debugPrint('${record.loggerName}: ${record.level.name}: '
        '${record.message} ${record.error ?? ''}');
  }
});
```

See the `Logging` section of the `supabase_flutter` README for level filtering with
`hierarchicalLoggingEnabled`.

Two logger names changed, so update any listeners that filter on `LogRecord.loggerName`:

| Before                      | After              |
| --------------------------- | ------------------ |
| `supabase.supabase`         | `supabase.dart`    |
| `supabase.supabase_flutter` | `supabase.flutter` |

#### Every deprecated API is gone

| Removed                                                    | Replacement                                  | Package             |
| ---------------------------------------------------------- | -------------------------------------------- | ------------------- |
| `AuthChangeEvent.userDeleted`                              | none, it was never emitted                   | `supabase_auth`     |
| `OAuthProvider.snakeCase`                                  | `OAuthProvider.name`                         | `supabase_auth`     |
| `User.confirmedAt`                                         | `User.emailConfirmedAt`                      | `supabase_auth`     |
| `ReturningOption`                                          | none, it was unused                          | `postgrest`         |
| `PostgrestClient.auth()`                                   | none, pass an `Authorization` header instead | `postgrest`         |
| `RealtimeClient.longpollerTimeout`                         | none, there is no longpoll transport         | `supabase_realtime` |
| `ChannelResponse.rateLimited`                              | none, it was never returned                  | `supabase_realtime` |
| `FileObject.lastAccessedAt`, `FileObjectV2.lastAccessedAt` | none, the server does not populate it        | `supabase_storage`  |
| `AuthUser`                                                 | `User`                                       | `supabase`          |
| `RealtimeClientOptions.eventsPerSecond`                    | none, it was already ignored                 | `supabase`          |
| `RemoveSubscriptionResult`                                 | none                                         | `supabase`          |
| `SupabaseRealtimeError`                                    | none                                         | `supabase`          |
| `SupabaseEventTypes` and `SupabaseEventTypesName`          | none, it was unused                          | `supabase`          |
| `SupabaseStreamBuilder.execute()`                          | listen to the builder directly               | `supabase`          |

Both `lastAccessedAt` fields were also required constructor parameters, so any code that builds a
`FileObject` or `FileObjectV2` by hand drops that argument.

`User.toJson()` no longer contains a `confirmed_at` key.

#### Abbreviations in the public API are spelled out

The wire format is unchanged throughout: where a JSON key, query parameter or URL path matched the
abbreviation, only the Dart identifier is renamed.

Across every package:

| Before                     | After                             |
| -------------------------- | --------------------------------- |
| `RealtimeClient.setAuth()` | `RealtimeClient.setAccessToken()` |
| `queryParams:`             | `queryParameters:`                |
| `opts:`                    | `options:`                        |
| `PresenceOpts`             | `PresenceOptions`                 |
| `appendSearchParams`       | `appendSearchParameters`          |
| `overrideSearchParams`     | `overrideSearchParameters`        |
| `toQueryParams`            | `toQueryParameters`               |

`supabase_realtime`:

| Before                                      | After                                       |
| ------------------------------------------- | ------------------------------------------- |
| `RealtimeClient.conn`                       | `RealtimeClient.connection`                 |
| `RealtimeClient.connState`                  | `RealtimeClient.connectionState`            |
| `RealtimeClient.onConnMessage`              | `RealtimeClient.onConnectionMessage`        |
| `RealtimeClient.params`                     | `RealtimeClient.parameters`                 |
| `RealtimeClient.endPoint`                   | `RealtimeClient.endpoint`                   |
| `RealtimeClient.endPointURL`                | `RealtimeClient.endpointUrl`                |
| `RealtimeConstants.wsCloseNormal`           | `RealtimeConstants.webSocketCloseNormal`    |
| `RealtimeChannel(topic, socket, params: …)` | `RealtimeChannel(topic, socket, config: …)` |
| `Presence.presenceRef`                      | `Presence.presenceReference`                |

`supabase_auth`:

| Before                                                      | After                                                                          |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `JwtPayload.iss/sub/aud/exp/nbf/iat/jti`                    | `issuer`, `subject`, `audience`, `expiresAt`, `notBefore`, `issuedAt`, `jwtId` |
| `JwtHeader.alg/kid/typ`                                     | `algorithm`, `keyId`, `type`                                                   |
| `JWK.kty/keyOps/alg/kid`                                    | `keyType`, `keyOperations`, `algorithm`, `keyId`                               |
| `User.aud`                                                  | `User.audience`                                                                |
| `CreateOAuthClientParams` / `UpdateOAuthClientParams`       | `…Options`                                                                     |
| `CreateCustomProviderParams` / `UpdateCustomProviderParams` | `…Options`                                                                     |
| `authorizationParams`                                       | `authorizationParameters`                                                      |
| `supportedIdTokenSigningAlgs`                               | `supportedIdTokenSigningAlgorithms`                                            |
| `tokenEndpointAuthMethod`                                   | `tokenEndpointAuthenticationMethod`                                            |
| `userinfoEndpoint` / `userinfoUrl`                          | `userInfoEndpoint` / `userInfoUrl`                                             |
| `validateExp(int? exp)`                                     | `validateExpiration(int? expiresAt)`                                           |
| `AMRMethod` / `AMREntry`                                    | `AuthenticationMethodReference` / `…Entry`                                     |
| `AuthChangeEvent.jsName`                                    | `AuthChangeEvent.value`                                                        |
| `AuthenticationMethodReference.code`                        | `AuthenticationMethodReference.value`                                          |
| `GenerateLinkType.fromString`                               | `GenerateLinkType.fromValue`                                                   |
| `OAuthClientType.fromString`                                | `OAuthClientType.fromValue`                                                    |
| `OAuthClientRegistrationType.fromString`                    | `OAuthClientRegistrationType.fromValue`                                        |
| `CustomProviderType.fromString`                             | `CustomProviderType.fromValue`                                                 |

`supabase_storage` and `iceberg`:

| Before                                         | After                                       |
| ---------------------------------------------- | ------------------------------------------- |
| `StorageFileApi.info()`                        | `StorageFileApi.getMetadata()`              |
| `SignedUploadURLResponse`                      | `SignedUploadUrlResponse`                   |
| `VectorBucketEncryption.sseType`               | `serverSideEncryptionType`                  |
| `PartitionSpec` and the Iceberg `spec` cluster | `PartitionSpecification`, `…Specification…` |
| `TableMetadata.refs`                           | `TableMetadata.references`                  |
| `TableField.doc`                               | `TableField.documentation`                  |
| `LoadTableSnapshots.refs`                      | `TableSnapshotScope.references`             |

These renames also change a type:

| Before                                                              | After                                              |
| ------------------------------------------------------------------- | -------------------------------------------------- |
| `RealtimeClient.heartbeatIntervalMs` (`int`)                        | `heartbeatInterval` (`Duration`)                   |
| `RealtimeConstants.defaultHeartbeatIntervalMs` (`int`)              | `defaultHeartbeatInterval` (`Duration`)            |
| `RealtimeClient.reconnectAfterMs` (`int` return)                    | `reconnectAfter` (`Duration` return)               |
| `SnapshotReference.maxReferenceAgeMs` / `maxSnapshotAgeMs` (`int?`) | `maxReferenceAge` / `maxSnapshotAge` (`Duration?`) |
| `Snapshot.timestampMs` / `TableMetadata.lastUpdatedMs` (`int`)      | `timestamp` / `lastUpdated` (`DateTime`, UTC)      |

### Database

#### `order()` now sorts ascending by default

`PostgrestTransformBuilder.order()` and `SupabaseStreamBuilder.order()` default `ascending` to
`true` instead of `false`. This is not a compile error, so check every `.order()` call that does not
pass `ascending` explicitly, in both `select()` queries and `stream()`. To keep the previous
behaviour, add `ascending: false`, which already means descending on v2, so you can make the change
before upgrading:

```dart
// Before: newest first. After: oldest first.
await supabase.from('messages').select().order('created_at');

// Newest first on both.
await supabase.from('messages').select().order('created_at', ascending: false);
```

#### `order()` no longer sends a null placement by default

`nullsFirst` on `PostgrestTransformBuilder.order()` is now a `bool?` that defaults to `null`. When
it is left out, no `nullsfirst` or `nullslast` is sent and PostgreSQL decides where `NULL`s go: last
for an ascending sort and first for a descending one. v2 defaulted it to `false`, which always sent
`nullslast` and so put `NULL`s last on a descending sort too. This is not a compile error, so check
every `.order(..., ascending: false)` call on a nullable column. To keep the previous behaviour,
add `nullsFirst: false`, which already means nulls last on v2:

```dart
// Before: nulls at the end. After: nulls at the start.
await supabase.from('books').select().order('price', ascending: false);

// Nulls at the end on both.
await supabase
    .from('books')
    .select()
    .order('price', ascending: false, nullsFirst: false);
```

#### `DateTime` filter values carry their offset from UTC

A `DateTime` passed to a filter, such as `gt()`, `eq()`, `inFilter()`, `match()` or `filter()`, to
a `stream()` or `PostgresChangeFilter`, or as a `GET` function argument, is sent in ISO 8601 with
its offset from UTC:
`2026-01-01T12:00:00.000Z` for a UTC value and `2026-01-01T12:00:00.000-05:00` for a local one. v2
sent `toString()`, `2026-01-01 12:00:00.000`, so the database read a local value in its own time
zone, usually UTC, and a `timestamptz` filter compared against an instant shifted by the device
offset. A `timestamp` column ignores the offset and still compares against the wall clock time.

This is not a compile error, so check every filter that passes a `DateTime` from `DateTime.now()`
or another local value. A filter that already passes a string, such as
`value.toUtc().toIso8601String()`, is unaffected:

```dart
// Before: matched rows created up to the local time, read as UTC.
// After: matches rows created before now.
await supabase.from('messages').select().lt('created_at', DateTime.now());
```

#### The rest client and its builders are stateless

| Before                                                                               | After                                                                                  |
| ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| `supabase.rest.headers['X-Foo'] = 'bar'`                                             | `supabase.headers = {...supabase.headers, 'X-Foo': 'bar'}`                             |
| `postgrest.headers['X-Foo'] = 'bar'`                                                 | pass the header to the `PostgrestClient` constructor, or use `setHeader()` per request |
| `await supabase.from('countries')`                                                   | does not compile, choose an operation first                                            |
| `SupabaseQuerySchema(…)` and `SupabaseQueryBuilder(…)`                               | internal, use `supabase.schema(…)` and `supabase.from(…)`                              |
| `PostgrestQueryBuilder(method: …, abortSignal: …)`                                   | removed, call `abortSignal()` on the query builder instead                             |
| `PostgrestRpcBuilder(abortSignal: …)`                                                | removed, call `abortSignal()` on the builder `rpc()` returns                           |
| `PostgrestBuilder.appendSearchParameters()` and `overrideSearchParameters()`         | removed                                                                                |
| `PostgrestFilterBuilder.copyWithUrl()` and `PostgrestTransformBuilder.copyWithUrl()` | removed, build the request with the filters and transforms instead                     |
| `PostgrestQueryBuilder<T>`                                                           | `PostgrestQueryBuilder`                                                                |

`PostgrestClient.headers` is an unmodifiable map. Set headers on the constructor for all requests,
or with `setHeader()` on a builder for a single request.

Assigning `supabase.headers` replaces the rest client with one carrying the new headers. A
`PostgrestClient` or `SupabaseQuerySchema` captured before the assignment keeps the old headers, so
read `supabase.rest` or call `supabase.schema(…)` again after changing them.

`insert()`, `upsert()`, `update()` and `delete()` without a trailing `select()` now resolve to
`void`. The value was always `null`, so drop the assignment or add `select()` to return data.

`supabase.from('countries')` by itself can no longer be awaited or converted with
`withConverter()`. Call `select()`, `insert()`, `upsert()`, `update()`, `delete()` or `count()`
first. `setHeader()`, `retry()`, `requestTimeout()` and `abortSignal()` remain available before the
operation.

#### The PostgREST builder has one type parameter and no wrapper classes

`PostgrestBuilder<T, S, R>` is now `PostgrestBuilder<T>`, where `T` is the type the request resolves
to when awaited. `RawPostgrestBuilder` and `ResponsePostgrestBuilder` are gone; `withConverter()` and
`count()` are methods of `PostgrestBuilder<T>` itself.

| Before                                                                   | After                                           |
| ------------------------------------------------------------------------ | ----------------------------------------------- |
| `PostgrestBuilder<T, S, R>`                                              | `PostgrestBuilder<T>`                           |
| `RawPostgrestBuilder<T, S, R>` and `ResponsePostgrestBuilder<T, S, R>`   | `PostgrestBuilder<T>`                           |
| `PostgrestBuilder(count: …, converter: …)`                               | `PostgrestBuilder(…).withConverter(…).count(…)` |
| `geojson()` returned `ResponsePostgrestBuilder<Map<String, dynamic>, …>` | `PostgrestBuilder<Map<String, dynamic>>`        |

`withConverter()` converts whatever the request resolves to at the point where it is called. Without
`count()` nothing changes. With `count()`, call `withConverter()` first so the converter keeps
receiving the data:

```dart
// Before
final response = await supabase
    .from('users')
    .select()
    .count(CountOption.exact)
    .withConverter((rows) => rows.map(User.fromJson).toList());

// After
final response = await supabase
    .from('users')
    .select()
    .withConverter((rows) => rows.map(User.fromJson).toList())
    .count(CountOption.exact);
```

A converter placed after `count()` receives the whole `PostgrestResponse`, so the old order no
longer compiles.

The per-request timeout override is a method of its own instead of a parameter of `retry()`:

| Before                                                   | After                                                   |
| -------------------------------------------------------- | ------------------------------------------------------- |
| `.retry(requestTimeout: Duration(seconds: 5))`           | `.requestTimeout(Duration(seconds: 5))`                 |
| `.retry(count: 5, requestTimeout: Duration(seconds: 5))` | `.retry(count: 5).requestTimeout(Duration(seconds: 5))` |

`requestTimeout()` is available wherever `retry()` is.

#### `rpc` is a getter

`PostgrestClient.rpc`, `SupabaseClient.rpc` and `SupabaseQuerySchema.rpc` are getters returning a
`PostgrestRpc` instead of methods. Calling the result makes the same untyped call as before, so
`supabase.rpc('fn', params: {...})` is unchanged, and the generated extension methods on
`PostgrestRpc` add typed calls such as `supabase.rpc.searchBooks(query: 'dart')`. Code that passes
`rpc` itself around as a function no longer compiles; wrap it in a closure instead.

```dart
// Before
final call = supabase.rpc;

// After
PostgrestFilterBuilder<dynamic> call(String fn) => supabase.rpc(fn);
```

#### `insert()` and `upsert()` no longer take filters

`insert()` and `upsert()` return a `PostgrestTransformBuilder` instead of a
`PostgrestFilterBuilder`, and the typed `insert()`, `insertAll()`, `upsert()` and `upsertAll()`
return a `PostgrestTypedTransformBuilder` instead of a `PostgrestTypedFilterBuilder`. PostgREST
always ignored a filter on an insert, so drop it, or use `update()` to change existing rows.
`select()`, `order()`, `limit()` and the other transforms are still available. Code that stores one
of these builders in a variable typed as `PostgrestFilterBuilder<void>` or
`PostgrestTypedFilterBuilder<Row, void>` needs the `Transform` type instead.

#### Typed `update()` and `delete()` require a filter or `all()`

The typed `update()` and `delete()` return a `PostgrestTypedUnscopedBuilder` instead of a
`PostgrestTypedFilterBuilder`. It does not implement `Future` and has no transforms, only
`where()` and `all()`, each of which returns the `PostgrestTypedFilterBuilder` the mutation used to
start with. A mutation that forgot its filter, and would have written every row in the table, no
longer sends a request; writing every row is spelled out with `all()`.

```dart
// Before: compiled, and deleted every book.
await supabase.table(Books.table).delete();

// After: sends nothing, see below. Filter the rows, or ask for all of them.
await supabase.table(Books.table).delete().where(Books.id.eq(1));
await supabase.table(Books.table).delete().all();
```

A bare `await` of `update()` or `delete()` still compiles and silently performs no request. The
analyzer reports every such line as an `unused_result` warning, which is on by default.
Anything chained directly after `update()` or `delete()` has to move after the `where()` or `all()`.
`update()` and `delete()` on `from()` are unchanged.

#### Transforms that sent a different request now throw or narrow

These used to compile and send something other than what was asked for:

- Typed `count()` returns a `PostgrestTypedCountBuilder`, which offers `where()` but no
  transforms. `limit()` and `range()` were dropped from a count and `csv()`, `select()` and
  `explain()` crashed, so remove them.
- `head()` after an insert, upsert, update or delete throws a `StateError`. It used to send a
  `HEAD` request, so the write never happened. On a function call, `head()` sends the arguments
  as query parameters and throws an `ArgumentError` for any that PostgREST would read as an
  option or a filter, such as `limit` or `eq.1`, or a `null`.
- `range(from, to)` throws an `ArgumentError` when `to` is less than `from`, instead of sending a
  negative limit.
- `maybeSingle()` on an insert, upsert, update or delete asks PostgREST for a single object, so
  a write that affects more than one row is rolled back before the error is thrown, as with
  `single()`. It used to be committed.

### Auth

#### `AuthClient.getSSOSignInUrl` returns a `Uri`

It returned a `String` before. Call `toString()` on the result if you need the string.

#### `signInWithSSO` takes `authScreenLaunchMode`

Its `launchMode:` argument is renamed to `authScreenLaunchMode:`, the name `signInWithOAuth` and
`linkIdentity` use.

#### A web callback URL is exchanged after `Supabase.initialize` completes

On web the callback URL of a sign-in used to be exchanged before `Supabase.initialize` completed,
while on mobile the link that opened the app was exchanged after it. Both platforms now exchange it
right after, so a listener that subscribes to `onAuthStateChange` once `initialize` completes gets
`signedIn` or `passwordRecovery` on web too. Code that read `currentSession` right after
`initialize` to find the session of the callback should wait for that event instead.

#### `OAuthResponse.url` is a `Uri`

`getOAuthSignInUrl()` and `getLinkIdentityUrl()` return a `Uri` in `OAuthResponse.url` rather than
a `String`. Drop any `Uri.parse()` you were doing yourself, or call `toString()` for the string.

#### Sign-in methods that always issue a session return the `Session`

The auth methods that cannot complete without a session return it directly instead of an
`AuthResponse` with a nullable `session`:

- `signInAnonymously()`
- `signInWithPassword()`
- `signInWithIdToken()`
- `signInWithWeb3()`
- `linkIdentityWithIdToken()`
- `refreshSession()`
- `setSession()`
- `recoverSession()`
- `passkey.verifyAuthentication()`, and with it `signInWithPasskey()` and `signInWithRestoreKey()`

```dart
// Before
final response = await supabase.auth.signInWithPassword(email: email, password: password);
final session = response.session!;
final user = response.user!;

// After
final session = await supabase.auth.signInWithPassword(email: email, password: password);
final user = session.user;
```

When the response carries no session, every method in the list throws an
`AuthSessionMissingException` with the `errorCode` `session_missing`, where some used to resolve with
a `null` session. `signUp()` and `verifyOTP()` keep returning an `AuthResponse`, since both can
complete without a session.

#### `admin.listUsers()` returns pagination metadata

`listUsers()` returns a `ListUsersResponse` instead of a `List<User>`. The users are under `users`,
alongside `total`, `nextPage`, `lastPage` and `audience`. `nextPage` is `null` on the last page. To
walk every page, use `listAllUsers()`:

```dart
await for (final user in supabase.auth.admin.listAllUsers(perPage: 50)) {
  print(user.email);
}
```

#### `OAuthAuthorizationDetailsResponse.user` is an `OAuthAuthorizingUser`

It was a `User` before. `OAuthAuthorizingUser` carries `id` and `email` under the same names, so
code that only reads those needs no change.

#### `OAuthClient.clientName` is nullable

A client that registered itself through dynamic client registration may have no name, so
`OAuthClient.clientName` is a `String?`. Fall back to something like `client.clientId` where you
need a value.

#### `OAuthClient.tokenEndpointAuthenticationMethod` and `registrationType` are nullable

Auth leaves both out of a client response when they are empty, so
`OAuthClient.tokenEndpointAuthenticationMethod` is a `String?` and `OAuthClient.registrationType`
is an `OAuthClientRegistrationType?`.

#### OAuth clients no longer have a `scope`

`OAuthClient.scope`, `CreateOAuthClientOptions.scope` and `UpdateOAuthClientOptions.scope` are
gone. Auth never stored a scope on a client, so drop the argument. Scopes are requested per
authorization with the `scope` query parameter on `/oauth/authorize`, and are on
`OAuthAuthorizationDetailsResponse.scope`.

#### `JWK.publicKey` returns a `JWTKey`

`JWK.publicKey` supports EC keys as well as RSA keys, so it returns a `JWTKey`: an `RSAPublicKey`
for `RSA` keys and an `ECPublicKey` for `EC` keys. It returned an `RSAPublicKey` before.

#### `User.appMetadata` is an `AppMetadata` and `userMetadata` is never null

`User.appMetadata` changes from a `Map<String, dynamic>` to an `AppMetadata` value object with
typed `provider` and `providers` fields. Every other key the server sent, such as a claim added by
an auth hook or an admin update, is still read with `[]`, so `user.appMetadata['provider']` keeps
compiling. Iterating the map or passing it where a `Map` is expected does not; use `toJson()` for
the full map.

`User.userMetadata` is no longer nullable. A user without metadata has an empty map. Both metadata
objects are unmodifiable when parsed from the server.

```dart
// Before
final provider = user.appMetadata['provider'] as String?;
final name = user.userMetadata?['name'] as String?;

// After
final provider = user.appMetadata.provider;
final name = user.userMetadata['name'] as String?;
```

The `User` constructor takes an `AppMetadata`, such as
`const AppMetadata(provider: 'email', providers: ['email'])`, and both metadata arguments are
optional. `UserAttributes.data` and the `AdminUserAttributes` metadata fields are still plain maps.

#### Confirming an email or phone change emits `userUpdated`

Confirming an email or phone change now emits `AuthChangeEvent.userUpdated` instead of
`AuthChangeEvent.signedIn`:

| Confirmation                                                      | Before     | After         |
| ----------------------------------------------------------------- | ---------- | ------------- |
| `verifyOTP()` with `OtpType.emailChange` or `OtpType.phoneChange` | `signedIn` | `userUpdated` |
| `getSessionFromUrl()` with an implicit `type=email_change` link   | `signedIn` | `userUpdated` |
| `exchangeCodeForSession()` for a PKCE code from an email change   | `signedIn` | `userUpdated` |

The session is still saved and `currentSession` still updates. Check any `onAuthStateChange`
listener that expects the email-change confirmation to arrive as `signedIn`, and handle
`userUpdated` there instead. You can also branch on the `redirectType` of the response of
`getSessionFromUrl()` or `exchangeCodeForSession()`, which is `AuthRedirectType.emailChange` for
these, see below.

#### `AuthSessionUrlResponse.redirectType` is an `AuthRedirectType`

`redirectType` held the raw `type` of an implicit link, such as `'recovery'`, but the name of the
event, such as `'passwordRecovery'`, for a PKCE code, so a check like `redirectType == 'recovery'`
never matched a PKCE password reset. It is now an `AuthRedirectType` with the same value for both
flows, and never `null`:

| Redirect                  | Before (implicit) | Before (PKCE)        | After                               |
| ------------------------- | ----------------- | -------------------- | ----------------------------------- |
| Password recovery         | `'recovery'`      | `'passwordRecovery'` | `AuthRedirectType.passwordRecovery` |
| Email change              | `'email_change'`  | `'userUpdated'`      | `AuthRedirectType.emailChange`      |
| Any other sign-in or link | `type` or `null`  | `null`               | `AuthRedirectType.signIn`           |

```dart
final response = await supabase.auth.getSessionFromUrl(Uri.base);
if (response.redirectType == AuthRedirectType.passwordRecovery) {
  // Show the form that sets a new password.
}
```

#### `signOut()` only throws when the sessions could not be revoked

`signOut()` used to sign out on the device first and then rethrow a network or server failure of the
revoke request, so with `SignOutScope.global` an offline device was signed out while the other
devices stayed signed in, and the token needed to retry was gone.

- With `SignOutScope.local`, the default, the session is removed from the device first, so signing
  out works offline and `AuthSignedOut` is emitted right away. `signOut()` then waits up to 10
  seconds for the server to revoke the session, refreshing an expired access token first, so
  disposing the client afterwards cannot abort the request. When the revoke fails or times out,
  `signOut()` throws, but the user stays signed out on the device.
- With `SignOutScope.global` and `SignOutScope.others` the server is asked first, after refreshing
  an expired access token. When that fails, including when the access token has expired and cannot
  be refreshed, `signOut()` throws and the session is kept, so you can retry.
  `SignOutScope.global` signs out on the device once the server has revoked the sessions.

The session is gone from the device as soon as `signOut()` is called, so you can navigate away
without awaiting it and handle a failed revoke in the background, for example with
`signOut().onError<AuthException>(...)`. Where you sign out globally, handle the exception, for
example by offering a retry or falling back to a local sign-out.

#### `FlutterWebAuth2OAuthLauncher` reports cancel and exchange failures without throwing

With `supabase_flutter_web_auth`, closing the web auth session without signing in made
`signInWithOAuth`, `signInWithSSO` and `linkIdentity` throw a `PlatformException` with the code
`CANCELED`. They now return `false`, so check the result instead of catching the exception. A
failed code exchange no longer throws either: the `AuthException` arrives as an error on
`onAuthStateChange`, as it does with the default launcher.

```dart
final launched = await supabase.auth.signInWithOAuth(
  OAuthProvider.github,
  redirectTo: 'com.example.myapp://oauth-callback',
);
if (!launched) {
  print('Sign-in was cancelled');
}
```

#### Switching to another user's session emits `signedIn`

`setSession()`, `refreshSession()` and `recoverSession()` now emit `AuthChangeEvent.signedIn`
instead of `AuthChangeEvent.tokenRefreshed` when the session they store belongs to another user than
the current one, or when nobody was signed in. Refreshing the current user's session still emits
`tokenRefreshed`. Handle `signedIn` in any `onAuthStateChange` listener that relied on
`tokenRefreshed` to notice the new user.

#### User-scoped auth calls throw when signed out

The `mfa`, `passkey` and `oauth` calls that act on the signed-in user, `unlinkIdentity()`,
`getLinkIdentityUrl()` and `linkIdentityWithIdToken()` now throw an `AuthSessionMissingException`
without a request when nobody is signed in, like `getUser()` and `updateUser()` already did. Before,
they sent the request without a user token and the server rejected it.

#### An expired session is kept when `autoRefreshToken` is off

With `autoRefreshToken: false`, an expired session restored at startup is no longer signed out. It
stays in `currentSession` and `getSession()` refreshes it when it is next needed, so check
`Session.isExpired`, or await `getSession()`, instead of treating a non-null `currentSession` as
valid. `recoverSession()` now refreshes an expired session whatever `autoRefreshToken` is set to.

`getSession()` signs out an expired session that has no refresh token and throws an
`AuthSessionMissingException`, instead of returning the expired session.

#### Cross-tab session sync is opt-in for standalone clients

On web the auth client keeps the tabs of a project in sync through a `BroadcastChannel`. It is now
only opened when the session is persisted. `AuthClientOptions` and `AuthClient` gain
`persistSession`, which defaults to `false`.

`Supabase.initialize` still defaults it to `true` through `FlutterAuthClientOptions`, so an app
initialized that way is unaffected. A client you construct directly no longer takes part unless you
pass `persistSession: true` to its `AuthClientOptions`. An app that passes `persistSession: false`
keeps its session in memory and no longer syncs it across tabs. A client configured with a
third-party `accessToken` never opens the channel.

#### The auth client persists the session itself

`AuthClient` owns session persistence. It takes one `AuthAsyncStorage` for both the session and the
pkce code verifiers, writes the session whenever it changes, and restores it when the client is
created, so a Dart program without Flutter gets session persistence too.

| Before                                                               | After                                |
| -------------------------------------------------------------------- | ------------------------------------ |
| `FlutterAuthClientOptions(localStorage: …)`                          | `AuthClientOptions(asyncStorage: …)` |
| `AuthClientOptions(pkceAsyncStorage: …)`                             | `AuthClientOptions(asyncStorage: …)` |
| `LocalStorage`, `EmptyLocalStorage`, `SharedPreferencesLocalStorage` | removed                              |
| `getItem({required String key})`                                     | `getItem(String key)`                |
| `setItem({required String key, required String value})`              | `setItem(String key, String value)`  |
| `removeItem({required String key})`                                  | `removeItem(String key)`             |

`SharedPreferencesAuthAsyncStorage` remains the default of `Supabase.initialize`. On web it writes
to `window.localStorage`, so the session is shared with supabase-js under the same key.

A custom storage implements the three methods of `AuthAsyncStorage` instead of the five of
`LocalStorage`, and no longer needs to know the key:

```dart
class MySecureStorage extends AuthAsyncStorage {
  final storage = FlutterSecureStorage();

  @override
  Future<String?> getItem(String key) => storage.read(key: key);

  @override
  Future<void> setItem(String key, String value) =>
      storage.write(key: key, value: value);

  @override
  Future<void> removeItem(String key) => storage.delete(key: key);
}

authOptions: FlutterAuthClientOptions(asyncStorage: MySecureStorage()),
```

Keeping the session in memory only is a flag rather than a storage: replace
`localStorage: const EmptyLocalStorage()` with `persistSession: false`. The code verifiers are still
stored in that case, so an email link or OAuth redirect completes even if the app was closed in
between.

A Dart program persists the session by passing an `asyncStorage` and `persistSession: true` to
`AuthClientOptions`, then awaiting `client.auth.initialized`, which completes once the persisted
session has been restored. `Supabase.initialize` awaits it for you.

`AuthClientOptions.storageKey` names the key the session is stored under, defaulting to
`sb-<project-ref>-auth-token`. It also prefixes the code verifier keys. Verifiers under the old
`supabase.auth.token-…` prefix are still read, so a sign-in link requested before the upgrade still
completes after it.

#### A client without an `asyncStorage` keeps pkce verifiers in memory

The pkce flow, the default, keeps its code verifiers in the `asyncStorage` of `AuthClientOptions`.
A `SupabaseClient` created without one now falls back to a `MemoryAuthAsyncStorage`, so a script
or a server needs no setup. The verifiers are lost when the process exits, so pass a persistent
storage when the code comes back to another process, such as from an email link.

`Supabase.initialize` configures a persistent storage for you. A `SupabaseClient` with
`persistSession: true`, or an `AuthClient` using the pkce flow, still needs an `asyncStorage` and
throws an `ArgumentError` when it is created without one, in every build mode.

#### `AuthChangeEvent.initialSession` is emitted to every subscriber

`initialSession` is emitted to every new subscriber of `onAuthStateChange` as its first event,
carrying the session at that moment or `null`. In v2 it was emitted once at startup by
`Supabase.initialize`, and the stream replayed its latest event to late subscribers.

This is not a compile error. A listener attached after a sign-in now receives `initialSession` with
the signed-in session instead of a replayed `signedIn`, so move any work that ran on `signedIn` at
subscription time to handle `initialSession` as well:

```dart
supabase.auth.onAuthStateChange.listen((data) {
  switch (data.event) {
    case AuthChangeEvent.initialSession:
      // The session as it is when this listener attaches, or null.
    case AuthChangeEvent.signedIn:
      // A sign-in that happened after this listener attached.
    default:
  }
});
```

A client you construct yourself emits the event too. Earlier events and errors are no longer
replayed.

#### `AuthState` is a sealed class

Each `AuthChangeEvent` has its own `AuthState` subtype carrying the data that event produces:
`AuthInitialSession`, `AuthSignedIn`, `AuthSignedOut`, `AuthTokenRefreshed`, `AuthUserUpdated`,
`AuthPasswordRecovery` and `AuthMfaChallengeVerified`. `session` is non-nullable on every subtype
except `AuthInitialSession`, where it is the session at subscription time or `null`, and
`AuthSignedOut`, where it is always `null`.

`AuthState.event` and `AuthState.session` are still there, so a listener that compares `event` and
null-checks `session` keeps compiling. What changes:

- `AuthState.signOutReason` moved to `AuthSignedOut.reason`.
- `AuthState` itself can no longer be constructed. Construct the subtype instead, for example in a
  test that feeds a fake stream.

```dart
// Before
supabase.auth.onAuthStateChange.listen((state) {
  if (state.event == AuthChangeEvent.signedOut) {
    if (state.signOutReason == SignOutReason.sessionExpired) {
      showSessionExpired();
    }
    showLogin();
  } else if (state.session != null) {
    showHome(state.session!.user);
  }
});

// After
supabase.auth.onAuthStateChange.listen((state) {
  switch (state) {
    case AuthSignedOut(reason: SignOutReason.sessionExpired):
      showSessionExpired();
      showLogin();
    case AuthSignedOut():
    case AuthInitialSession(session: null):
      showLogin();
    case AuthInitialSession(session: final session?):
    case AuthSignedIn(:final session):
    case AuthTokenRefreshed(:final session):
    case AuthUserUpdated(:final session):
    case AuthPasswordRecovery(:final session):
    case AuthMfaChallengeVerified(:final session):
      showHome(session.user);
  }
});
```

#### The session is persisted with `SharedPreferencesAsync`

`SharedPreferencesAuthAsyncStorage`, the storage `Supabase.initialize` uses by default, now writes
through
[`SharedPreferencesAsync`](https://pub.dev/packages/shared_preferences#sharedpreferences-vs-sharedpreferencesasync-vs-sharedpreferenceswithcache)
rather than the legacy `SharedPreferences` API.

An existing session is moved over the first time it is read, so your users stay signed in. Two
things need action.

If your own code still calls `SharedPreferences.getInstance()`, on Windows and Linux a session write
by the SDK can now drop preferences you wrote through the legacy API, and the other way around.
[Migrate your code to `SharedPreferencesAsync`](https://pub.dev/packages/shared_preferences#migrating-from-sharedpreferences-to-sharedpreferencesasync-or-sharedpreferenceswithcache)
as well, or pass an `AuthAsyncStorage` that keeps the session in the legacy store:

```dart
class LegacySharedPreferencesStorage extends AuthAsyncStorage {
  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<String?> getItem(String key) async =>
      (await _preferences).getString(key);

  @override
  Future<void> setItem(String key, String value) async =>
      (await _preferences).setString(key, value);

  @override
  Future<void> removeItem(String key) async =>
      (await _preferences).remove(key);
}
```

Widget tests that call `Supabase.initialize` otherwise throw
`StateError: The SharedPreferencesAsyncPlatform instance must be set.`, since
`SharedPreferences.setMockInitialValues()` only covers the legacy API:

```dart
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

setUp(() {
  SharedPreferences.setMockInitialValues({});
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
});
```

`shared_preferences_platform_interface` needs to be a `dev_dependency` for that import. Passing
`FlutterAuthClientOptions(asyncStorage: MemoryAuthAsyncStorage())` instead avoids shared
preferences altogether.

#### `supabasePersistSessionKey` is gone

The session is stored under `AuthClientOptions.storageKey`, which defaults to
`sb-<project-ref>-auth-token`. A custom `AuthAsyncStorage` receives the key with every call. To keep
reading sessions stored under the old constant, pass
`storageKey: 'SUPABASE_PERSIST_SESSION_KEY'` to `FlutterAuthClientOptions`; leaving the default
signs your users out once instead.

If you are still on v1 with a session in [hive](https://pub.dev/packages/hive), upgrade to v2 first
and let it migrate the session, then move to v3.

#### Auth requires a GoTrue server on API version `2024-01-01` or newer

Error codes are always read from `code`, without the fallback to the older `error_code` field. This
only affects self-hosted setups on a GoTrue older than `2024-01-01`, where `code` is now `null` and a
weak password surfaces as a plain `AuthApiException` rather than `AuthWeakPasswordException`.
`ApiVersions` is removed with nothing replacing it.

#### Session and auth request objects are immutable

`Session.expiresAt` and `ResendResponse.messageId` are `final`. The expiry is read from the access
token, so call `session.copyWith(accessToken: newAccessToken)` to change it.

The request fields on `UserAttributes` and `AdminUserAttributes` are `final`, so pass them to the
constructor instead of assigning after construction:

```dart
// Before
final attributes = UserAttributes();
attributes.email = 'new@example.com';
attributes.data = {'name': 'Alice'};
await supabase.auth.updateUser(attributes);

// After
await supabase.auth.updateUser(
  UserAttributes(email: 'new@example.com', data: {'name': 'Alice'}),
);
```

### Realtime

#### `RealtimeClient.connectionState` is now typed

`connectionState` keeps its name but changes from a `String` getter to `SocketState?`, and the typed
`connState` field is gone. This is not a compile error if you were only reading the string, so check
every use site.

```dart
// Before
if (client.connectionState == 'open') {}
final SocketStates? state = client.connState;

// After
if (client.connectionState == SocketState.open) {}
final SocketState? state = client.connectionState;
```

Use `connectionState?.name` for the string form, or `RealtimeClient.isConnected` to check whether
the socket is up.

#### The mutable internals of `RealtimeClient` are private

| Before                                                          | After                                         |
| --------------------------------------------------------------- | --------------------------------------------- |
| `client.channels` (mutable list)                                | `client.channels` (unmodifiable view)         |
| `client.getChannels()`                                          | `client.channels`                             |
| `supabase.getChannels()`                                        | `supabase.channels`                           |
| `client.accessToken = token`                                    | `await client.setAccessToken(token)`          |
| `client.heartbeatInterval = interval`                           | `RealtimeClient(heartbeatInterval: interval)` |
| `client.customAccessToken = getter`                             | `RealtimeClient(customAccessToken: getter)`   |
| `client.reconnectAfter = calculation`                           | `RealtimeClient(reconnectAfter: calculation)` |
| `client.connection = channel`                                   | removed, the getter remains                   |
| `client.connectionState = state`                                | removed, the getter remains                   |
| `client.headers['key'] = value`                                 | `RealtimeClient(headers: headers)`            |
| `client.heartbeatTimer`, `client.reconnectTimer`                | removed                                       |
| `client.ref`, `client.pendingHeartbeatRef`, `client.sendBuffer` | internal and test-only                        |

Channels are added with `channel()` and removed with `removeChannel()` or `removeAllChannels()`.
Mutating the `channels`, `headers` or `parameters` views throws an `UnsupportedError`. Unlike the
removed field write, `setAccessToken()` also propagates the new token to every joined channel.
When the client is managed by a `SupabaseClient`, pass the heartbeat interval and the reconnect
backoff through `RealtimeClientOptions`, and the headers through `SupabaseClient.headers`.

#### `RealtimeClient.parameters` is a `Map<String, String>`

The constructor argument and the `parameters` field were `Map<String, dynamic>`, though every value
was stringified into the socket URL. Pass string values.

#### The mutable internals of `RealtimeChannel` are private

| Before                             | After                                                |
| ---------------------------------- | ---------------------------------------------------- |
| `channel.joinedOnce = value`       | removed, the getter remains (internal)               |
| `channel.joinPush = push`          | removed, the getter remains (internal and test-only) |
| `channel.presence`                 | removed                                              |
| `channel.parameters` (mutable map) | `channel.parameters` (unmodifiable view, internal)   |

If you read presence state through `channel.presence`, use `channel.presenceState()` and the
`onPresenceSync`, `onPresenceJoin` and `onPresenceLeave` streams instead. Pass channel configuration
through `RealtimeChannelConfig` when creating the channel.

#### Broadcasts no longer fall back to the REST API

`sendBroadcastMessage()` only sends over the WebSocket. Calling it on a channel that was never
subscribed throws. Use `httpSend()` for the REST path, which works without subscribing:

```dart
// Before: delivered over REST because the channel was never subscribed.
await supabase.channel('room').sendBroadcastMessage(event: 'move', payload: data);

// After
await supabase.channel('room').httpSend(event: 'move', payload: data);
```

Messages sent between `subscribe()` and the join are still buffered, so only channels that were
never subscribed throw. `httpSend()` requires Realtime v2.97.0 or newer.

#### Broadcast data arrives under `payload`

`sendBroadcastMessage()` sends its `payload` under the `payload` key of the message, as `httpSend()`,
database broadcasts and the JavaScript client already did. It used to put the keys next to `type`
and `event`, so a listener only found them at the top level for messages sent from Dart. Read the
data from `payload` on every `onBroadcast` message. If you wrapped the data in a `payload` key
yourself, for example to match the JavaScript client or to send binary data, remove the wrapper,
or the data arrives nested twice and a binary payload is sent as a JSON list of numbers:

```dart skip
// Before
channel.onBroadcast(event: 'cursor').listen((message) => print(message['x']));
await channel.sendBroadcastMessage(event: 'cursor', payload: {'x': 30});
await channel.sendBroadcastMessage(event: 'file', payload: {'payload': bytes});
await channel.sendBroadcastMessage(event: 'ping', payload: {'payload': {'x': 30}});

// After
channel
    .onBroadcast(event: 'cursor')
    .listen((message) => print(message['payload']['x']));
await channel.sendBroadcastMessage(event: 'cursor', payload: {'x': 30});
await channel.sendBroadcastMessage(event: 'file', payload: bytes);
await channel.sendBroadcastMessage(event: 'ping', payload: {'x': 30});
```

#### A channel name in use returns its channel

`channel()` returns the channel already registered for a name instead of creating a second one,
and the options passed with the repeated call are ignored. `subscribe()` on a channel that is
already subscribed does nothing. Creating a second channel with the same name used to unsubscribe
the first one, which reported `closed`, so remove a channel before reusing its name with other
options.

`RealtimeClient.disconnect()` keeps the channels and rejoins them on the next connection. Call
`removeAllChannels()` to unsubscribe them as well. A broadcast without `ack` resolves to `ok` once
it is written to the socket, and to `error` on a channel that is leaving or has closed.

#### Realtime listener callbacks are now streams

Every recurring-event listener in `supabase_realtime` is a Dart `Stream` instead of a callback.

On `RealtimeClient`, the four connection callbacks are replaced by two broadcast streams:
`onStatusChange` for the connection lifecycle and `onMessage` for every decoded frame. Connection
errors are emitted as stream errors on `onStatusChange`:

```dart
// Before
client.onOpen(() => print('open'));
client.onClose((event) => print('closed: $event'));
client.onError((error) => print('error: $error'));
client.onMessage((message) => print('message: $message'));

// After
client.onStatusChange.listen(
  (change) => switch (change.status) {
    RealtimeConnectionStatus.open => print('open'),
    RealtimeConnectionStatus.closed => print('closed: ${change.closeEvent}'),
  },
  onError: (error) => print('error: $error'),
);
client.onMessage.listen((message) => print('message: $message'));
```

On `RealtimeChannel`, `onPostgresChanges` and `onBroadcast` no longer take a `callback` parameter
and return a typed stream instead of the channel, so they can no longer be chained. Repeated calls
with the same arguments return the same stream. For `postgres_changes` the stream still has to be
created before `subscribe()`, but it can be listened to at any point:

```dart
// Before
supabase
    .channel('room')
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) => print(payload),
    )
    .onBroadcast(
      event: 'cursor-pos',
      callback: (payload) => print(payload),
    )
    .subscribe();

// After
final channel = supabase.channel('room');
channel
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
    )
    .listen(print);
channel.onBroadcast(event: 'cursor-pos').listen(print);
channel.subscribe();
```

The presence and system listeners are stream getters, and `onSystemEvents` emits a typed
`RealtimeSystemPayload` instead of a raw payload:

```dart
// Before
channel.onPresenceSync((payload) { /* ... */ });
channel.onPresenceJoin((payload) { /* ... */ });
channel.onPresenceLeave((payload) { /* ... */ });
channel.onSystemEvents((payload) {
  final system = RealtimeSystemPayload.fromJson(
    Map<String, dynamic>.from(payload as Map),
  );
});

// After
channel.onPresenceSync.listen((payload) { /* ... */ });
channel.onPresenceJoin.listen((payload) { /* ... */ });
channel.onPresenceLeave.listen((payload) { /* ... */ });
channel.onSystemEvents.listen((system) { /* ... */ });
```

`subscribe()` no longer takes a status callback. Status changes are emitted on the new
`RealtimeChannel.onStatusChange` stream as `RealtimeSubscribeStatusChange` values, which carry the
`RealtimeSubscribeStatus` and, for `channelError`, the error that caused it. The optional timeout is
now the first positional parameter:

```dart
// Before
channel.subscribe((status, [error]) {
  if (status == RealtimeSubscribeStatus.subscribed) {
    // ...
  } else if (status == RealtimeSubscribeStatus.channelError) {
    print('error: $error');
  }
}, const Duration(seconds: 10));

// After
channel.onStatusChange.listen((change) {
  if (change.status == RealtimeSubscribeStatus.subscribed) {
    // ...
  } else if (change.status == RealtimeSubscribeStatus.channelError) {
    print('error: ${change.error}');
  }
});
channel.subscribe(const Duration(seconds: 10));
```

All channel streams complete when the channel closes, so `await for` loops and `onDone` handlers end
on their own once the channel is gone.

#### `Binding` and `BindingCallback` are internal

`Binding` and `BindingCallback` are no longer exported, along with their only consumers
`RealtimeChannel.onEvents` and `RealtimeChannel.off`. Use the typed channel streams
(`onPostgresChanges`, `onBroadcast`, `onPresenceSync`, `onPresenceJoin`, `onPresenceLeave`,
`onSystemEvents`) instead.

#### `RealtimePresence` is internal

`RealtimePresence` and its helper types (`PresenceOptions`, `PresenceEvents`, `PresenceChooser`,
`PresenceOnJoinCallback`, `PresenceOnLeaveCallback`) are `@internal`, along with the
`RealtimeChannel.presence` field. Use `onPresenceJoin`, `onPresenceLeave` and `onPresenceSync` on
the channel instead of `presence.onJoin`, `onLeave` and `onSync`, and `channel.presenceState()`
instead of `presence.state`.

`presenceState()` returns a `List<SinglePresenceState>` rather than a map, with the key in
`SinglePresenceState.key` and the payloads in `SinglePresenceState.presences`. To rebuild the map:

```dart
final byKey = {
  for (final state in channel.presenceState()) state.key: state.presences,
};
```

The `Presence` payload class is unchanged and stays public.

#### `RealtimeEncode` and `RealtimeDecode` are asynchronous and typed

Both codec typedefs on `RealtimeClient` now work on a `RealtimeMessage` and return a `Future`:

| Before                                  | After                                      |
| --------------------------------------- | ------------------------------------------ |
| `Object Function(Map<String, dynamic>)` | `Future<Object> Function(RealtimeMessage)` |
| `Map<String, dynamic> Function(Object)` | `Future<RealtimeMessage> Function(Object)` |

```dart
final isolate = YAJsonIsolate();

final client = RealtimeClient(
  'wss://project.supabase.co/realtime/v1',
  encode: (message) => isolate.encode(message.toJson()),
  decode: (frame) async =>
      RealtimeMessage.fromJson(await isolate.decode(frame as String)),
);
```

`RealtimeMessage` carries the `joinRef`, `ref`, `topic`, `event` and `payload` of a message, and
converts to and from the wire array with `toJson` and `RealtimeMessage.fromJson`.
`RealtimeClient.onMessage` emits `RealtimeMessage` too, so read `message.event` instead of
`message['event']`. `RealtimeClientOptions` takes the same two callbacks, for a codec set through
`SupabaseClient` or `Supabase.initialize`. The `encode` and `decode` fields of the client are `null`
unless you pass a codec.

A codec replaces the built-in one completely, so the one above handles text frames only. Handle a
`Uint8List` frame as well if you send or receive binary broadcasts.

#### Realtime only speaks protocol `2.0.0`

The legacy `1.0.0` Realtime protocol, with its object-shaped JSON frames, is no longer supported.
`RealtimeClient` always connects with `vsn=2.0.0`, so the `version` constructor parameter, the
`RealtimeClient.version` getter and the `RealtimeProtocolVersion` enum are removed.
`RealtimeMessage.toJson` and `RealtimeMessage.fromJson` no longer take a protocol version.

#### `RealtimeClient.logger` and `RealtimeClient.log` are gone

The `logger` constructor parameter and the public `log` method are removed. Realtime diagnostics are
emitted on the `supabase.realtime` logger, so listen there instead.

```dart
hierarchicalLoggingEnabled = true;
Logger('supabase.realtime').onRecord.listen((record) {
  print('${record.level.name}: ${record.message} ${record.error ?? ''}');
});
```

Without `hierarchicalLoggingEnabled = true`, listen on `Logger.root` and filter on
`LogRecord.loggerName` instead.

#### `stream()` keeps running through reconnects

A failed PostgREST fetch no longer closes the stream. It is reported once and retried until it
succeeds, unless it is a client error that a retry cannot fix, such as a missing table, which still
closes it. A dropped connection or a join that timed out is no longer reported as a
`RealtimeSubscribeException`, since the channel rejoins and the rows are fetched again. Rebuilding
the stream in `onDone` or `onError` to recover is no longer needed.

The rows are fetched once the server streams the changes, rather than alongside the join, so the
first snapshot holds every change made in the meantime and arrives slightly later.

### Storage

#### Storage uploads return an `UploadResponse`

`upload`, `uploadBinary`, `update`, `updateBinary`, `uploadToSignedUrl` and
`uploadBinaryToSignedUrl` return an `UploadResponse` instead of a `String`. The uploads used to
return the key, the path prefixed with the bucket id, which is now `fullPath`. The signed URL
uploads used to return the path within the bucket, which is now `path`. Code that keeps the result
in a `var` or interpolates it into a string still compiles, but gets the whole response:

```dart
// Before
final key = await supabase.storage.from('avatars').upload('avatar.png', file);

// After
final response = await supabase.storage.from('avatars').upload('avatar.png', file);
final key = response.fullPath;
```

`UploadResponse` also carries the `id` of the stored object, and `versionId` for a resumable upload.

#### `exists()` only returns `false` for a missing object

`exists()` used to send a `HEAD` request and return `false` for any 400 or 404 response. It now
reads the object's metadata and returns `false` only when storage reports the object missing. A
missing bucket or an invalid token throws a `StorageApiException` instead:

```dart
try {
  final found = await supabase.storage.from('avatars').exists('avatar.png');
  print(found ? 'found' : 'missing');
} on StorageApiException catch (error) {
  print('could not check: ${error.errorCode}');
}
```

#### `createSignedUrls` reports per-path failures

`createSignedUrls` returns a list of `SignedUrlSuccess` and `SignedUrlFailure` instead of
`List<SignedUrl>`, and the separate `createSignedUrlsResult` is removed. If you were already calling
`createSignedUrlsResult`, drop the `Result` suffix.

```dart
final results = await supabase.storage
    .from('avatars')
    .createSignedUrls(['a.png', 'b.png'], 60);
for (final result in results) {
  switch (result) {
    case SignedUrlSuccess(:final signedUrl):
      print(signedUrl);
    case SignedUrlFailure(:final path, :final error):
      print('could not sign $path: $error');
  }
}
```

#### Storage uploads and downloads take an `abortSignal`

`StorageRetryController` is gone. Every upload method and both download methods on
`StorageFileApi` take a `Future<void>? abortSignal` instead of a `retryController`. Completing the
future aborts the in-flight request and stops any remaining retries, and the call throws a
`RequestAbortedException`:

```dart
final abortSignal = Completer<void>();
final upload = supabase.storage
    .from('avatars')
    .upload('avatar.png', file, abortSignal: abortSignal.future);
abortSignal.complete();

try {
  await upload;
} on RequestAbortedException {
  print('upload aborted');
}
```

On `downloadStream` the abort surfaces as a `RequestAbortedException` error on the stream.

#### Signed URL uploads take named options

The options of `uploadToSignedUrl` and `uploadBinaryToSignedUrl` were optional positional
parameters and are named now, like on every other upload method:

```dart
// Before
.uploadToSignedUrl(path, token, file, const FileOptions(upsert: true));

// After
.uploadToSignedUrl(path, token, file, fileOptions: const FileOptions(upsert: true));
```

#### Iceberg catalog options are named and take an `abortSignal`

The options of `listNamespaces`, `listTables` and `loadTableResult` were optional positional
parameters and are named now, so that every catalog operation can also take a
`Future<void>? abortSignal`:

```dart
// Before
await catalog.listNamespaces(const ListNamespacesOptions(pageSize: 100));

// After
await catalog.listNamespaces(options: const ListNamespacesOptions(pageSize: 100));
```

A nested type the client does not recognize decodes as the new `UnknownType` instead of failing the
whole table, so a `switch` over `IcebergType` needs a case for it.

A catalog whose `/v1/config` request fails now throws that error from the operation instead of
falling back to the `v1/<warehouse>` path, so a rejected token or a missing bucket surfaces as the
error the server sent.

#### Storage uploads send the raw file body

Uploads used to be `multipart/form-data` requests. The file is now the request body itself, with
the options as the `Content-Type`, `Cache-Control: max-age=<seconds>`, `x-upsert` and `x-metadata`
headers, the last holding the metadata as base64-encoded JSON. `upload`, `update` and
`uploadToSignedUrl` stream the `File` from disk instead of reading it into memory.

The Dart API is unchanged. Only middleware, proxies or test fixtures that matched on the multipart
body need to read the raw body and the `x-metadata` header instead.

`uploadStream`, `updateStream` and `uploadStreamToSignedUrl` are new and upload a
`Stream<List<int>>` as it arrives, for example a file picked on the web. A stream can only be read
once, so these are never retried:

```dart
import 'package:cross_file/cross_file.dart';

final file = XFile.fileSystem(path: path);
await supabase.storage.from('avatars').uploadStream(
  'avatar.png',
  file.openRead(),
  contentLength: await file.length(),
);
```

#### `BucketOptions.public` is optional and `fileSizeLimit` is in bytes

`updateBucket` only sends the options that are set, so changing the allowed MIME types or the
versioning status no longer resets the visibility of the bucket. `BucketOptions.public` is
optional for that reason, and a bucket created without it is private as before.

`BucketOptions.fileSizeLimit` is the number of bytes as an `int`, the same type that
`Bucket.fileSizeLimit` reports, instead of a string such as `'20MB'`:

```dart
// Before
const BucketOptions(public: false, fileSizeLimit: '20MB');

// After
const BucketOptions(fileSizeLimit: 20 * 1000 * 1000);
```

#### Storage methods without a result return `void`

The methods that only confirmed success with a message from the server complete with `void` and
throw a `StorageException` on failure as before: `createBucket`, `updateBucket`, `emptyBucket`,
`deleteBucket`, `deleteBucketLifecycle`, `purgeBucketCache`, `purgeProjectCache`,
`deleteAnalyticsBucket`, `move` and `purgeCache`. `createBucket` used to return the id it was
given, so keep using that id.

`copy` returns an `UploadResponse` like `upload` does, instead of the key prefixed with the
bucket id. That key is its `fullPath`, and `path` is the key within the bucket:

```dart
// Before
final key = await supabase.storage.from('avatars').copy('a.png', 'b.png');

// After
final copy = await supabase.storage.from('avatars').copy('a.png', 'b.png');
final key = copy.fullPath;
```

#### `SignedUrl` is removed

`SignedUrl` was only the base class of the `createSignedUploadUrl` response, which is now the
standalone `SignedUploadUrlResponse` with the same `path` and `signedUrl` fields and its `token`.
`SignedUrl.copyWith` is gone with it.

#### Storage wire helpers are internal

The `StorageFileApi` constructor is internal. Get one for a bucket with
`supabase.storage.from(bucketId)` instead. The methods that encode options for a request,
`ListBucketsOptions.toQueryParameters`, `toMap` on `SearchOptions`, `SortBy`, `FileSort` and
`PaginatedSearchOptions`, and `Vector.toJson`, are internal too.

### Errors

#### Service exceptions share one base

`AuthException`, `PostgrestException`, `StorageException`, `FunctionsException`,
`RealtimeException` and `IcebergException` now extend a shared `SupabaseException`. The ones
reporting a response from a service also mix in `SupabaseApiException`, and the ones thrown when
no response arrived mix in `SupabaseTransportException`:

```dart
abstract class SupabaseException implements Exception {
  final String message;
  final String? errorCode;
  final String? requestId;
}

mixin SupabaseApiException on SupabaseException {
  int get statusCode;
  Map<String, String> get headers;
  String? get body;
}

mixin SupabaseTransportException on SupabaseException {
  Object? get cause;
}
```

Both types are re-exported from every package, so one catch handles a failure from any service:

```dart
try {
  await supabase.from('countries').select();
} on SupabaseApiException catch (error) {
  print('${error.statusCode}: ${error.message}');
} on SupabaseException catch (error) {
  print(error.message);
}
```

The renames:

| Before                                         | After                                                                      |
| ---------------------------------------------- | -------------------------------------------------------------------------- |
| `AuthException.statusCode` (`String?`)         | `AuthApiException.statusCode` (`int`)                                      |
| `AuthException.code`                           | `AuthException.errorCode`                                                  |
| `StorageException.statusCode` (`String?`)      | `StorageApiException.statusCode` (`int`)                                   |
| `StorageException.error`                       | `errorCode`                                                                |
| `StorageException.fromJson(json, '404')`       | `StorageApiException.fromJson(json, 404)`                                  |
| `PostgrestException` for a service error       | `PostgrestApiException`; `PostgrestException` is now the base of all three |
| `PostgrestException.code`                      | `PostgrestApiException.errorCode`, with the HTTP status in `statusCode`    |
| `PostgrestException.fromJson(json, code: 409)` | `PostgrestApiException.fromJson(json, statusCode: 409)`                    |
| `PostgrestException.toJson()` key `code`       | keys `statusCode` and `errorCode`                                          |
| `FunctionsHttpException`                       | `FunctionsApiException`                                                    |
| `FunctionException`                            | `FunctionsException`                                                       |
| `FunctionException.status` (`int`)             | `FunctionsApiException.statusCode`                                         |
| `FunctionException.reasonPhrase`               | folded into `message`                                                      |
| `FunctionsFetchException.status == 0`          | no status at all, no response reached the client                           |
| `FunctionResponse`                             | `FunctionsResponse`                                                        |
| `FunctionResponse.status`                      | `FunctionsResponse.statusCode`                                             |

The per-service bases no longer have a status, so narrow a catch that reads one to the API type,
for example `on AuthApiException` with `error.statusCode == 429` instead of `on AuthException` with
`error.statusCode == '429'`.

Four changes go beyond a rename:

- `PostgrestApiException.errorCode` is only ever the PostgREST or PostgreSQL code and `statusCode`
  only ever the HTTP status, where `PostgrestException.code` held either. A duplicate key violation
  reads as `statusCode: 409, errorCode: '23505'`.
- `AuthSessionMissingException` and `AuthInvalidJwtException` report no status, only the
  `errorCode` values `session_missing` and `invalid_jwt`. `AuthSessionMissingException` takes its
  `message` as a named parameter.
- `AuthRetryableFetchException` covers only the case where the request never reached the service.
  A retryable 5xx is an `AuthRetryableApiException`. Catch `AuthRetryableException` to get both.
- `FunctionsException` gained a `message` and an `errorCode`, taken from the `message` and `code`
  of a JSON error body, then from the response's reason phrase or a per-subtype default. The
  response body is still in `details`.

`AuthUnknownException` no longer reports a status of its own. Read it from `originalError` when that
is an `http.Response`.

#### `FunctionsException` is sealed

`FunctionsException` is a `sealed class`, so a switch over it is exhaustive at compile time:

```dart
try {
  await supabase.functions.invoke('hello');
} on FunctionsException catch (error) {
  final message = switch (error) {
    FunctionsFetchException() => 'The request never reached the function',
    FunctionsRelayException() => 'The relay reported an error',
    FunctionsApiException() => 'The function returned ${error.statusCode}',
  };
}
```

`FunctionsRelayException` extends `FunctionsApiException`, so it has to come first. A bare
`FunctionsException` can no longer be constructed, extended or implemented; name one of the three
subtypes instead.

Every failure of `invoke()` other than an abort or a failing `accessToken` callback, which throws
an `AccessTokenException`, is one of the three. A body that cannot be encoded as JSON, or a
multipart `body` that is not a map of strings, throws a `FunctionsFetchException` before anything
is sent, where it used to throw a `JsonUnsupportedObjectError` or a `TypeError`. A
successful response whose body is not valid JSON or UTF-8 throws a `FunctionsFetchException` caused
by the `FormatException`, where it used to throw the `FormatException` itself.

#### Edge Function regions are a `FunctionsRegion`

The `region` of `invoke()`, `FunctionsClient` and `FunctionsClientOptions` takes a
`FunctionsRegion` instead of a `String`. The named constants rule out spelling mistakes, and a raw
string no longer compiles as a `region`; `FunctionsRegion.custom` still takes any string:

```dart skip
// Before
await supabase.functions.invoke('hello', region: 'eu-west-1');

// After
await supabase.functions.invoke('hello', region: FunctionsRegion.euWest1);
```

`FunctionsRegion.any` replaces `'any'`, and `FunctionsRegion.custom('me-central-1')` sends a
region that has no constant yet.

#### Edge Function responses decode every JSON type

`FunctionsResponse.data` is decoded as JSON for `application/json` and for every `+json` type,
such as `application/problem+json`, which used to come back as a `String`. An empty JSON body is
`null` instead of `""`. The response headers are now in `FunctionsResponse.headers`.

#### The Iceberg exceptions join the same hierarchy

`IcebergException` splits into two, the same way the other packages do:

|                           |                                                                       |
| ------------------------- | --------------------------------------------------------------------- |
| `IcebergNetworkException` | no response was received from the catalog, so there is no status code |
| `IcebergApiException`     | the catalog answered, so `statusCode` is a real, non-nullable status  |

`IcebergApiException` is the sealed base for the response-backed subtypes, which are unchanged:
`IcebergNotFoundException`, `IcebergConflictException`, `IcebergAuthenticationTimeoutException`,
`IcebergCommitStateUnknownException`, `IcebergServerException` and `IcebergUnknownException`.

| Before                             | After                                                               |
| ---------------------------------- | ------------------------------------------------------------------- |
| `IcebergException.type`            | `errorCode`, from `SupabaseException`                               |
| `IcebergException.statusCode`      | `IcebergApiException.statusCode`; gone from the network case        |
| `IcebergException.statusCode == 0` | catch `IcebergNetworkException`, or check `is SupabaseApiException` |
| `IcebergException.fromResponse`    | `IcebergApiException.fromResponse`                                  |

`message`, `code` and `details` keep their names. `code` is still the Iceberg numeric error code,
unrelated to `errorCode`, the string error type such as `NoSuchTableException`.

#### A request that gets no response throws a transport exception

A request that never received a response, because the connection failed or timed out, used to let
`ClientException` or `TimeoutException` through in postgrest and storage. Every package now wraps it
in an exception that mixes in `SupabaseTransportException`, with the original error in `cause`:

| Package              | Exception                     |
| -------------------- | ----------------------------- |
| `postgrest`          | `PostgrestTransportException` |
| `supabase_storage`   | `StorageTransportException`   |
| `supabase_auth`      | `AuthRetryableFetchException` |
| `supabase_functions` | `FunctionsFetchException`     |
| `supabase_realtime`  | `RealtimeTransportException`  |
| `iceberg`            | `IcebergNetworkException`     |

A request aborted through its `abortSignal` still throws `RequestAbortedException`.

```dart
// Before
try {
  await supabase.from('countries').select();
} on ClientException {
  // offline
} on TimeoutException {
  // the request timeout elapsed
}

// After
try {
  await supabase.from('countries').select();
} on SupabaseTransportException catch (error) {
  // offline, or the request timeout elapsed; error.cause holds which
}
```

The three packages that already wrapped the failure changed how they expose the error:

| Before                                     | After                                                         |
| ------------------------------------------ | ------------------------------------------------------------- |
| `FunctionsFetchException(details:)`        | `FunctionsFetchException(cause:)`; `details` still returns it |
| `IcebergNetworkException(details:)`        | `IcebergNetworkException(cause:)`; `details` still returns it |
| `AuthRetryableFetchException.message` only | `cause` added, with the error the message was built from      |

#### A failing `accessToken` callback throws `AccessTokenException`

postgrest, storage and functions used to report an exception from the `accessToken` callback as a
transport exception. They now throw an `AccessTokenException` with the callback's error in `cause`,
and neither send nor retry the request. Catch `AccessTokenException` where you caught the transport
exception for token failures. An exception that is already a `SupabaseException`, such as an
`AuthException` from a failed session refresh, is thrown as is.

#### Realtime throws exceptions instead of strings

`supabase_realtime` threw bare strings for misuse and a plain `Exception` for a failed
`httpSend()`. The failures now have types:

| Before                                                          | After                                                                    |
| --------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `subscribe()` called twice throws a `String`                    | `StateError`                                                             |
| `onPostgresChanges()` after `subscribe()` throws a `String`     | `StateError`                                                             |
| `track()` or `untrack()` before `subscribe()` throws a `String` | `StateError`                                                             |
| `httpSend()` times out with a `TimeoutException`                | `RealtimeTransportException` with the `TimeoutException` as `cause`      |
| `httpSend()` gets a non-202 status, as `Exception(message)`     | `RealtimeApiException` with `statusCode`, `requestId`, `headers`, `body` |
| `onStatusChange` reports `channelError` with an `Exception`     | `RealtimeException` with the server's reason as `message`                |

Replace a `toString()` check such as `contains('404')` with `on RealtimeApiException` and its
`statusCode`. The message of a declined join no longer carries the quotes of a JSON-encoded string.
`RealtimeSubscribeException`, which `stream()` delivers to its error handler, now extends
`RealtimeException`, with `status` and `details` unchanged.

### Requests, retries and tokens

#### Every client takes one `SupabaseRetryOptions`

PostgREST, storage and the auth token refresh all take the same `SupabaseRetryOptions`, which
carries `enabled`, `count`, `initialDelay`, `maxDelay` and `randomizationFactor`.

| Before                                                                                                                                              | After                                                                 |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `PostgrestClient(retryEnabled: …, retryCount: …)`                                                                                                   | `PostgrestClient(retryOptions: …)`                                    |
| `PostgrestClientOptions(retryEnabled: …, retryCount: …)`                                                                                            | `PostgrestClientOptions(retryOptions: …)`                             |
| `PostgrestBuilder`, `PostgrestQueryBuilder` and `PostgrestRpcBuilder` constructors, same parameters                                                 | `retryOptions: …`                                                     |
| `SupabaseStorageClient(retryAttempts: 5)`                                                                                                           | `SupabaseStorageClient(retryOptions: SupabaseRetryOptions(count: 5))` |
| `StorageClientOptions(retryAttempts: 5)`                                                                                                            | `StorageClientOptions(retryOptions: SupabaseRetryOptions(count: 5))`  |
| `upload(…, retryAttempts: 5)` and the same parameter on `uploadBinary`, `uploadToSignedUrl`, `uploadBinaryToSignedUrl`, `update` and `updateBinary` | `retryOptions: SupabaseRetryOptions(count: 5)`                        |

`count` is the number of retries after the first attempt, as `retryAttempts` was, so the number
carries over unchanged. The auth token refresh can be configured through
`AuthClientOptions.retryOptions`. The per-request `PostgrestBuilder.retry()` keeps `enabled` and
`count`; its `requestTimeout` parameter is now a method of its own, see
[the builder section](#the-postgrest-builder-has-one-type-parameter-and-no-wrapper-classes).

#### The retry backoff defaults are the same in every client

One curve is used everywhere: the first retry waits 400 ms, every retry after that waits twice as
long up to 30 seconds, and each delay, a capped one included, is randomized by up to 25%. A
`Retry-After` header asking for longer than `maxDelay` ends the retries instead of being shortened.

| Client             | Before                                    | After                                               |
| ------------------ | ----------------------------------------- | --------------------------------------------------- |
| `postgrest`        | 3 retries, 1s doubling to 30s, no jitter  | 3 retries on the shared curve                       |
| `supabase_storage` | opt-in, 400ms doubling to 30s, 25% jitter | unchanged, still opt-in with `count: 0`             |
| `supabase_auth`    | 400ms doubling to 10s, no jitter          | shared curve, bounded by the refresh tick as before |

PostgREST reads therefore back off sooner than they did, and with jitter. Pass your own
`SupabaseRetryOptions` to keep the old curve:

```dart
postgrestOptions: const PostgrestClientOptions(
  retryOptions: SupabaseRetryOptions(
    initialDelay: Duration(seconds: 1),
    randomizationFactor: 0,
  ),
),
```

#### The request timeout bounds idle time, not the whole request

`requestTimeout` used to be a deadline for a whole PostgREST attempt. It now bounds how long an
attempt may go without progress, restarting whenever a chunk of the response arrives. The option is
now also available on auth, storage and functions, and as a default for all of them on
`SupabaseClient`. To cap the total time a query may take, use `timeout()` on the builder, which
stops waiting for the result without cancelling the request:

```dart
await supabase.from('countries').select().timeout(const Duration(seconds: 10));
```

#### The retried status codes are no longer configurable

`503 Service Unavailable` and `520 Unknown Error` are the only responses that are retried, and the
set is fixed.

| Before                                            | After                                  |
| ------------------------------------------------- | -------------------------------------- |
| `PostgrestClient(retryableStatusCodes: …)`        | removed                                |
| `PostgrestClientOptions(retryableStatusCodes: …)` | removed                                |
| `PostgrestClient.defaultRetryableStatusCodes`     | `PostgrestClient.retryableStatusCodes` |

If you retried a status code outside that set, catch the `PostgrestApiException` and check its
`statusCode` yourself.

#### `setAccessToken()` is gone from the rest, storage and functions clients

`PostgrestClient.setAccessToken()`, `SupabaseStorageClient.setAccessToken()` and
`FunctionsClient.setAccessToken()` are removed. `RealtimeClient.setAccessToken()` stays.

`SupabaseClient` already sends the signed-in user's token on every request, so most code only drops
the call. Otherwise:

- On a client you construct yourself, pass an `accessToken` callback, which is resolved before
  every request, or an `Authorization` header for a token that never changes. Passing both asserts.

  ```dart
  // Before
  final functions = FunctionsClient(functionsUrl, {'apikey': anonKey});
  functions.setAccessToken(jwt);

  // After
  final functions = FunctionsClient(
    functionsUrl,
    {'apikey': anonKey},
    accessToken: () async => currentJwt,
  );
  ```

- For a single call, pass the header to that call, through `headers:` on `invoke()` or
  `setHeader('Authorization', 'Bearer $jwt')` on a query.
- To pin a token on a client from `SupabaseClient`, call
  `setHeader('Authorization', 'Bearer $jwt')` on `supabase.storage` or `supabase.functions`, and
  for the rest client assign it through `supabase.headers`.

#### Client header maps are unmodifiable

Every `headers` getter returns an unmodifiable view, and mutating one throws an `UnsupportedError`.

| Before                                            | After                                                      |
| ------------------------------------------------- | ---------------------------------------------------------- |
| `supabase.auth.headers['X-Foo'] = 'bar'`          | `supabase.headers = {...supabase.headers, 'X-Foo': 'bar'}` |
| `supabase.functions.headers['X-Foo'] = 'bar'`     | `supabase.headers = {...supabase.headers, 'X-Foo': 'bar'}` |
| `supabase.storage.headers['X-Foo'] = 'bar'`       | `supabase.storage.setHeader('X-Foo', 'bar')`               |
| `storage.from('bucket').headers['X-Foo'] = 'bar'` | `storage.from('bucket').setHeader('X-Foo', 'bar')`         |
| `authClient.headers['X-Foo'] = 'bar'`             | `authClient.setHeader('X-Foo', 'bar')`                     |
| `functionsClient.headers['X-Foo'] = 'bar'`        | `functionsClient.setHeader('X-Foo', 'bar')`                |

Assigning `SupabaseClient.headers` propagates the new headers to every sub-client at once.
`SupabaseStorageClient.vectors` builds a new client on each access, so it always carries the
current headers.

#### An `Authorization` header passed to `SupabaseClient` reaches the auth client

An `Authorization` or `apikey` header in the `headers:` of the `SupabaseClient` constructor used to
be replaced with the API key on the auth client, while one assigned through `supabase.headers` was
kept. Both are now kept, so auth requests send the header instead of the API key. To keep the old
behavior, set the header on the individual calls instead of on the client.

#### JSON encoding and decoding is behind the `AsyncJsonCodec` interface

`SupabaseClient`, `PostgrestClient` and `FunctionsClient` take an `AsyncJsonCodec` through
`jsonCodec:` instead of a `YAJsonIsolate` through `isolate:`. The same rename applies to
`PostgrestBuilder`, `PostgrestQueryBuilder` and `PostgrestRpcBuilder`, and `Supabase.initialize`
takes `jsonCodec:` too.

```dart
// Before
final client = SupabaseClient(url, key, isolate: YAJsonIsolate()..initialize());

// After
final jsonCodec = YAJsonIsolate();
final client = SupabaseClient(
  url,
  key,
  authOptions: AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage()),
  jsonCodec: jsonCodec,
);

// A codec passed in belongs to the caller. Dispose it after every client that
// uses it.
await client.dispose();
await jsonCodec.dispose();
```

`YAJsonIsolate.initialize()` is removed, because there is nothing to initialize, so delete the
call. On web, `YAJsonIsolate` is no longer `const`, and using it after `dispose()` throws a
`StateError` as it already did on other platforms.

Implement `AsyncJsonCodec` to encode and decode JSON your own way. `YAJsonIsolate` is exported by
`supabase` and `supabase_flutter`.

#### `TracePropagationOptions` requires a `traceContextProvider`

`TracePropagationOptions.enabled` is gone and `traceContextProvider` is required. Passing options
turns propagation on, so drop `enabled: true`. To keep propagation off, drop the
`tracePropagationOptions` argument, which defaults to `null`.

### Shared types

#### Timestamps are `DateTime` instead of `String` or `int`

Every timestamp the SDK returns is a `DateTime` in UTC instead of an ISO 8601 `String` or a Unix
timestamp `int`.

| Type            | Fields                                                                                                                                        | Before                | After       |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- | ----------- |
| `Session`       | `expiresAt`                                                                                                                                   | `int?` (Unix seconds) | `DateTime?` |
| `User`          | `createdAt`                                                                                                                                   | `String`              | `DateTime`  |
| `User`          | `confirmationSentAt`, `recoverySentAt`, `emailChangeSentAt`, `invitedAt`, `emailConfirmedAt`, `phoneConfirmedAt`, `lastSignInAt`, `updatedAt` | `String?`             | `DateTime?` |
| `UserIdentity`  | `createdAt`, `lastSignInAt`, `updatedAt`                                                                                                      | `String?`             | `DateTime?` |
| `OAuthClient`   | `createdAt`, `updatedAt`                                                                                                                      | `String`              | `DateTime`  |
| `Bucket`        | `createdAt`, `updatedAt`                                                                                                                      | `String`              | `DateTime`  |
| `FileObject`    | `createdAt`, `updatedAt`                                                                                                                      | `String?`             | `DateTime?` |
| `FileObjectV2`  | `createdAt`                                                                                                                                   | `String`              | `DateTime`  |
| `FileObjectV2`  | `updatedAt`, `lastModified`                                                                                                                   | `String?`             | `DateTime?` |
| `PaginatedFile` | `createdAt`, `updatedAt`                                                                                                                      | `String?`             | `DateTime?` |

```dart
// Before
final expiresAt = supabase.auth.currentSession?.expiresAt;
final expiry = expiresAt == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
final createdAt = DateTime.parse(user.createdAt);

// After
final expiry = supabase.auth.currentSession?.expiresAt;
final createdAt = user.createdAt;
```

`toJson()` output is unchanged, so sessions persisted by v2 are still readable by v3. Three
behavioural details are worth checking:

- The `DateTime` values are in UTC. `DateTime` equality takes the time zone flag into account, so
  compare against `DateTime.utc(...)` rather than `DateTime(...)`, or call `toLocal()` first.
- `User.createdAt` used to fall back to an empty string when the field was missing and now throws a
  `FormatException`.
- A timestamp naming a date that does not exist is rejected rather than rolled forward.
  `DateTime.parse` reads `2019-02-29` as 1 March 2019; parsing now throws a `FormatException`.

#### Plural enum names singularized

| Before                         | After                         | Package             |
| ------------------------------ | ----------------------------- | ------------------- |
| `SocketStates`                 | `SocketState`                 | `supabase_realtime` |
| `PostgresTypes`                | `PostgresType`                | `supabase_realtime` |
| `AuthenticatorAssuranceLevels` | `AuthenticatorAssuranceLevel` | `supabase_auth`     |
| `LoadTableSnapshots`           | `TableSnapshotScope`          | `iceberg`           |

Apart from `TableSnapshotScope.references`, no enum values changed, so the only work is renaming the
type where you name it explicitly.

#### One shared `SortDirection` for every sort direction

| Before            | After           |
| ----------------- | --------------- |
| `BucketSortOrder` | `SortDirection` |
| `FileSortOrder`   | `SortDirection` |
| `SortDirection`   | unchanged       |

The values are unchanged, so only the type name moves. `SortBy.order` is a `SortDirection` too,
rather than a `String`, so `SortBy(column: 'created_at', order: 'desc')` becomes
`SortBy(column: 'created_at', order: SortDirection.descending)`. It is non-nullable and defaults to
ascending, so leave it out instead of passing `null`.

#### `HttpMethod` is one shared enum

`supabase_functions` and `postgrest` each declared their own `HttpMethod`. There is now one, shaped
like postgrest's and re-exported from both, so imports are unchanged and postgrest callers are
unaffected. For `functions.invoke`, two things changed:

- `head` was added, so an exhaustive `switch` over `HttpMethod` no longer compiles until you handle
  it.
- The values were reordered, so `index` shifted for `post` (1 to 2), `put` (2 to 3) and `delete`
  (3 to 5). This is not a compile error, so replace any persisted `index` with `name`.

The enum also exposes `value`, the uppercase wire form, in place of `method.name.toUpperCase()`.

### Testing

#### `supabase_test` matches methods with `HttpMethod` and takes the `initializeTestSupabase` names

The `method` parameter of `MockSupabaseHttpClient.requestsTo` and of every `stub*` method is an
`HttpMethod` instead of a `String`. `testSupabaseClient` takes the same parameter names as
`initializeTestSupabase` from `package:supabase_flutter/testing.dart`.

| Before                                   | After                                                  |
| ---------------------------------------- | ------------------------------------------------------ |
| `method: 'POST'`                         | `method: HttpMethod.post`                              |
| `testSupabaseClient(apiKey: key)`        | `testSupabaseClient(publishableKey: key)`              |
| `testSupabaseClient(realtime: realtime)` | `testSupabaseClient(realtimeTransport: realtime.call)` |

Both helpers now default to an `sb_publishable_` key instead of an unsigned anon JWT. A signed-out
edge function call therefore no longer sends an `Authorization` header, as with a production
publishable key. Pass a JWT as `publishableKey` if a test relies on the old headers.
